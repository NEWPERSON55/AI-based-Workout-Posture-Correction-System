"""
realtime_detection.py
=====================
Real-time push-up form detection and rep counting using webcam or video file.

╔══════════════════════════════════════════════════════════════════╗
║  MIGRATED FROM MEDIAPIPE TO MOVENET THUNDER (TFLite)             ║
║                                                                  ║
║  MoveNet outputs 17 keypoints (y, x, confidence).                ║
║  These are mapped into the MediaPipe 33-landmark format          ║
║  (x, y, z, visibility × 33 = 132 values) so the LSTM model       ║
║  and PushUpValidator continue working without retraining.        ║
║                                                                  ║
║  KEY DIFFERENCE: MoveNet is 2D-only (no z-depth), so z=0         ║
║  for all mapped landmarks. Landmarks not available in MoveNet    ║
║  (face mesh, hands, feet) are set to (0, 0, 0, 0).               ║
╚══════════════════════════════════════════════════════════════════╝

Features:
  • MoveNet Thunder TFLite for pose detection (replaces MediaPipe)
  • Same LSTM model (pushup_lstm_model.h5) for form classification
  • PushUpValidator state machine for posture validation
  • Dual-gate rep counting (transition + model + confidence)
  • Rolling 30-frame buffer, predicts every 10 frames
  • HUD overlay with rep count, state, posture details

Prerequisites:
    • pushup_lstm_model.h5 (run train_model.py first)
    • movenet_thunder.tflite (auto-downloaded on first run)
    • A connected webcam (for live mode)

Usage:
    python realtime_detection.py                          # interactive menu
    python realtime_detection.py video.mp4                # video mode (display only)
    python realtime_detection.py video.mp4 output.mp4     # video mode (save output)

Controls:
    q — quit
"""

import os
import sys
import cv2
import numpy as np
import urllib.request
from collections import deque

# TFLite interpreter — prefer lightweight runtime, fall back to full TF
try:
    import tflite_runtime.interpreter as tflite
    TFLiteInterpreter = tflite.Interpreter
except ImportError:
    import tensorflow as tf
    from tensorflow import keras
    TFLiteInterpreter = tf.lite.Interpreter

# For loading the LSTM model (Keras .h5 format)
try:
    from tensorflow import keras
except ImportError:
    pass  # Already imported above

from pushup_validator import PushUpValidator, ValidatorState

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
LSTM_MODEL_FILE = os.path.join(PROJECT_DIR, "pushup_lstm_model.h5")
MOVENET_MODEL_FILE = os.path.join(PROJECT_DIR, "movenet_thunder.tflite")
MOVENET_MODEL_URL = (
    "https://tfhub.dev/google/lite-model/"
    "movenet/singlepose/thunder/tflite/float16/4?lite-format=tflite"
)

SEQUENCE_LENGTH = 30          # must match training
PREDICT_EVERY_N_FRAMES = 10   # run inference every N frames (real-time opt.)

# MediaPipe-compatible constants (the LSTM model expects this format)
NUM_KEYPOINTS = 33
FEATURES_PER_KEYPOINT = 4     # x, y, z, visibility
LANDMARK_FEATURES = NUM_KEYPOINTS * FEATURES_PER_KEYPOINT  # 132
NUM_ANGLES = 6                # left/right elbow, shoulder, knee
TOTAL_FEATURES = LANDMARK_FEATURES + NUM_ANGLES  # 138


# ──────────────────────────────────────────────
# MoveNet → MediaPipe keypoint mapping
# ──────────────────────────────────────────────
# MoveNet has 17 keypoints in COCO format.
# MediaPipe has 33 landmarks.
# This mapping tells us: for each MoveNet index, which MediaPipe index
# it corresponds to. All 12 body joints used by PushUpValidator are covered.

MOVENET_TO_MEDIAPIPE = {
    0:  0,   # nose          → nose
    1:  2,   # left_eye      → left_eye (inner)
    2:  5,   # right_eye     → right_eye (inner)
    3:  7,   # left_ear      → left_ear
    4:  8,   # right_ear     → right_ear
    5:  11,  # left_shoulder  → left_shoulder
    6:  12,  # right_shoulder → right_shoulder
    7:  13,  # left_elbow     → left_elbow
    8:  14,  # right_elbow    → right_elbow
    9:  15,  # left_wrist     → left_wrist
    10: 16,  # right_wrist    → right_wrist
    11: 23,  # left_hip       → left_hip
    12: 24,  # right_hip      → right_hip
    13: 25,  # left_knee      → left_knee
    14: 26,  # right_knee     → right_knee
    15: 27,  # left_ankle     → left_ankle
    16: 28,  # right_ankle    → right_ankle
}

# MoveNet skeleton connections for drawing (pairs of MoveNet indices)
MOVENET_SKELETON = [
    (5, 6),    # left_shoulder ↔ right_shoulder
    (5, 7),    # left_shoulder → left_elbow
    (7, 9),    # left_elbow → left_wrist
    (6, 8),    # right_shoulder → right_elbow
    (8, 10),   # right_elbow → right_wrist
    (5, 11),   # left_shoulder → left_hip
    (6, 12),   # right_shoulder → right_hip
    (11, 12),  # left_hip ↔ right_hip
    (11, 13),  # left_hip → left_knee
    (13, 15),  # left_knee → left_ankle
    (12, 14),  # right_hip → right_knee
    (14, 16),  # right_knee → right_ankle
]


# ──────────────────────────────────────────────
# MoveNet model downloader
# ──────────────────────────────────────────────

def download_movenet(url: str, dest: str) -> None:
    """Download the MoveNet Thunder TFLite model if not already cached."""
    if os.path.exists(dest):
        return
    print(f"[INFO] Downloading MoveNet Thunder model to {dest} ...")
    urllib.request.urlretrieve(url, dest)
    print(f"[INFO] Download complete ({os.path.getsize(dest) / 1e6:.1f} MB).")


# ──────────────────────────────────────────────
# MoveNet TFLite Detector
# ──────────────────────────────────────────────

class MoveNetDetector:
    """
    Wrapper around the MoveNet Thunder TFLite model.

    Handles:
      • Preprocessing: resize to 256×256, cast to model's expected dtype
      • Inference: run the TFLite interpreter
      • Post-processing: extract 17 keypoints as (y, x, confidence)
    """

    def __init__(self, model_path: str, num_threads: int = 4):
        self._interpreter = TFLiteInterpreter(
            model_path=model_path, num_threads=num_threads
        )
        self._interpreter.allocate_tensors()

        self._input_details = self._interpreter.get_input_details()
        self._output_details = self._interpreter.get_output_details()

        self._input_shape = self._input_details[0]["shape"]
        self._input_h = self._input_shape[1]
        self._input_w = self._input_shape[2]
        self._input_dtype = self._input_details[0]["dtype"]

        print(f"[INFO] MoveNet Thunder loaded: input={self._input_shape}, "
              f"dtype={self._input_dtype.__name__}")

    def detect(self, frame: np.ndarray) -> np.ndarray:
        """
        Run MoveNet inference on a BGR frame.

        Returns
        -------
        keypoints : np.ndarray (17, 3) — [y_norm, x_norm, confidence]
                    in normalised [0, 1] coordinates.
        """
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        resized = cv2.resize(rgb, (self._input_w, self._input_h))

        input_tensor = np.expand_dims(resized, axis=0).astype(self._input_dtype)

        self._interpreter.set_tensor(
            self._input_details[0]["index"], input_tensor
        )
        self._interpreter.invoke()

        output = self._interpreter.get_tensor(
            self._output_details[0]["index"]
        )
        return np.squeeze(output)  # (17, 3)


# ──────────────────────────────────────────────
# Pose detection (MoveNet → MediaPipe format)
# ──────────────────────────────────────────────

def detect_pose(frame: np.ndarray, detector: MoveNetDetector):
    """
    Run MoveNet on a single frame and return keypoints in
    MediaPipe-compatible flat format.

    Returns
    -------
    coords : np.ndarray (132,) — [x0, y0, z0, v0, …, x32, y32, z32, v32]
             Maps MoveNet 17 keypoints into MediaPipe's 33-landmark slots.
             Unmapped landmarks are zeroed out.
             Returns empty array if no confident keypoints detected.
    raw_keypoints : np.ndarray (17, 3) — [y, x, confidence] for drawing
    """
    raw_kp = detector.detect(frame)  # (17, 3) — [y, x, conf]

    # Check if enough keypoints are confident (at least the core body joints)
    core_joints = [5, 6, 7, 8, 9, 10, 11, 12]  # shoulders, elbows, wrists, hips
    core_confidences = [raw_kp[i, 2] for i in core_joints]
    if np.mean(core_confidences) < 0.3:
        return np.empty(0, dtype=np.float32), raw_kp

    # Build MediaPipe-compatible (132,) flat array
    # Format: 33 landmarks × [x, y, z, visibility] = 132 values
    coords = np.zeros(LANDMARK_FEATURES, dtype=np.float32)

    for mn_idx, mp_idx in MOVENET_TO_MEDIAPIPE.items():
        y_norm, x_norm, conf = raw_kp[mn_idx]
        offset = mp_idx * FEATURES_PER_KEYPOINT
        coords[offset]     = x_norm      # x (MoveNet gives y,x — we swap)
        coords[offset + 1] = y_norm      # y
        coords[offset + 2] = 0.0         # z (MoveNet is 2D, no depth)
        coords[offset + 3] = conf        # visibility / confidence

    return coords, raw_kp


# ──────────────────────────────────────────────
# Helper: normalize landmarks (same as preprocessing)
# ──────────────────────────────────────────────

def normalize_frame(row: np.ndarray) -> np.ndarray:
    """
    Normalize a single frame's keypoints relative to the hip centre
    and torso length.  Uses x, y, z (visibility is left unchanged).

    This MUST match the normalization in data_preprocessing.py.
    """
    row = row.copy()

    # Hip centre (landmark 23, 24 — stride 4)
    lh, rh = 23 * 4, 24 * 4
    hip_centre = np.array([
        (row[lh] + row[rh]) / 2,
        (row[lh + 1] + row[rh + 1]) / 2,
        (row[lh + 2] + row[rh + 2]) / 2,
    ])

    # Shoulder centre (landmark 11, 12 — stride 4)
    ls, rs = 11 * 4, 12 * 4
    shoulder_centre = np.array([
        (row[ls] + row[rs]) / 2,
        (row[ls + 1] + row[rs + 1]) / 2,
        (row[ls + 2] + row[rs + 2]) / 2,
    ])

    torso_length = np.linalg.norm(shoulder_centre - hip_centre)
    if torso_length < 1e-6:
        torso_length = 1.0

    for j in range(NUM_KEYPOINTS):
        idx = j * 4
        row[idx]     = (row[idx]     - hip_centre[0]) / torso_length
        row[idx + 1] = (row[idx + 1] - hip_centre[1]) / torso_length
        row[idx + 2] = (row[idx + 2] - hip_centre[2]) / torso_length
        # visibility (row[idx + 3]) is left unchanged

    return row


# ──────────────────────────────────────────────
# Helper: compute joint angles (must match data_preprocessing.py)
# ──────────────────────────────────────────────

def _get_xyz(row, landmark_idx):
    """Extract (x, y, z) for a landmark from a stride-4 flat array."""
    i = landmark_idx * 4
    return np.array([row[i], row[i+1], row[i+2]])


def _angle_3d(a, b, c):
    """Angle in degrees at point b formed by segments a→b and c→b."""
    ba = a - b
    bc = c - b
    cos_a = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc) + 1e-8)
    return np.degrees(np.arccos(np.clip(cos_a, -1.0, 1.0)))


def compute_joint_angles(row):
    """
    Compute 6 joint angles from a single frame's normalized landmarks.
    Returns a (6,) array scaled to [0, 1].

    Uses MediaPipe landmark indices (the MoveNet keypoints have already
    been mapped into these slots by detect_pose()).
    """
    angles = np.array([
        _angle_3d(_get_xyz(row, 11), _get_xyz(row, 13), _get_xyz(row, 15)),  # L elbow
        _angle_3d(_get_xyz(row, 12), _get_xyz(row, 14), _get_xyz(row, 16)),  # R elbow
        _angle_3d(_get_xyz(row, 13), _get_xyz(row, 11), _get_xyz(row, 23)),  # L shoulder
        _angle_3d(_get_xyz(row, 14), _get_xyz(row, 12), _get_xyz(row, 24)),  # R shoulder
        _angle_3d(_get_xyz(row, 23), _get_xyz(row, 25), _get_xyz(row, 27)),  # L knee
        _angle_3d(_get_xyz(row, 24), _get_xyz(row, 26), _get_xyz(row, 28)),  # R knee
    ], dtype=np.float32) / 180.0
    return angles


# ──────────────────────────────────────────────
# Drawing helpers (replaces MediaPipe drawing utils)
# ──────────────────────────────────────────────

def draw_skeleton(frame, raw_keypoints, confidence_threshold=0.3):
    """
    Draw MoveNet keypoints and skeleton connections on the frame.

    Parameters
    ----------
    frame : np.ndarray — BGR image
    raw_keypoints : np.ndarray (17, 3) — [y_norm, x_norm, confidence]
    confidence_threshold : float — minimum confidence to draw
    """
    h, w = frame.shape[:2]

    # Draw connections first (under the keypoint circles)
    for (idx_a, idx_b) in MOVENET_SKELETON:
        conf_a = raw_keypoints[idx_a, 2]
        conf_b = raw_keypoints[idx_b, 2]
        if conf_a > confidence_threshold and conf_b > confidence_threshold:
            ya, xa = int(raw_keypoints[idx_a, 0] * h), int(raw_keypoints[idx_a, 1] * w)
            yb, xb = int(raw_keypoints[idx_b, 0] * h), int(raw_keypoints[idx_b, 1] * w)
            cv2.line(frame, (xa, ya), (xb, yb), (0, 220, 0), 2)

    # Draw keypoints
    for i in range(17):
        conf = raw_keypoints[i, 2]
        if conf > confidence_threshold:
            y = int(raw_keypoints[i, 0] * h)
            x = int(raw_keypoints[i, 1] * w)
            color = (0, 255, 0) if conf > 0.7 else (0, 220, 255)
            cv2.circle(frame, (x, y), 5, color, -1)
            cv2.circle(frame, (x, y), 5, (255, 255, 255), 1)


def draw_hud(frame, prediction_text, confidence, label_color,
             validator_result, real_rep_count=0):
    """
    Draw the heads-up display overlay with posture validation info.

    Parameters
    ----------
    frame : np.ndarray
    prediction_text : str  — "Correct" or "Wrong" or ""
    confidence : float
    label_color : tuple
    validator_result : FrameResult from PushUpValidator
    real_rep_count : int  — externally managed dual-gate rep count
    """
    vr = validator_result
    h, w = frame.shape[:2]

    # ── Semi-transparent background panel ──────
    overlay = frame.copy()
    # Expand panel if there is feedback
    feedback_count = len(vr.feedback) if vr else 0
    panel_height = 260 + (feedback_count * 25)
    
    cv2.rectangle(overlay, (0, 0), (420, panel_height), (20, 20, 20), -1)
    frame = cv2.addWeighted(overlay, 0.65, frame, 0.35, 0)

    if not vr:
        return frame

    y_pos = 35  # vertical cursor

    # ── Model prediction ───────────────────────
    if prediction_text:
        symbol = "+" if prediction_text == "Correct" else "X"
        display = f"{prediction_text} {symbol}  ({confidence:.0%})"
        cv2.putText(frame, display, (15, y_pos),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.9, label_color, 2)
    y_pos += 40

    # ── Rep count (dual-gate) ──────────────────
    cv2.putText(frame, f"Reps: {real_rep_count}", (15, y_pos),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
    y_pos += 40

    # ── Validator state ────────────────────────
    state_colors = {
        ValidatorState.NOT_READY: (100, 100, 255),   # red-ish
        ValidatorState.GATING:    (0, 200, 255),      # yellow-ish
        ValidatorState.UP:        (0, 220, 0),         # green
        ValidatorState.DOWN:      (255, 180, 0),       # blue-ish
    }
    state_color = state_colors.get(vr.state, (180, 180, 180))
    state_name = vr.state.name
    cv2.putText(frame, f"State: {state_name}", (15, y_pos),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, state_color, 2)
    y_pos += 35

    # ── Posture validity ───────────────────────
    posture_icon = "YES" if vr.is_valid_posture else "NO"
    posture_color = (0, 220, 0) if vr.is_valid_posture else (0, 0, 220)
    cv2.putText(frame, f"Posture Valid: {posture_icon}", (15, y_pos),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, posture_color, 2)
    y_pos += 30

    # ── Posture criteria details ───────────────
    if vr.posture_details:
        criteria_labels = {
            "body_horizontal": "Horizontal",
            "back_straight":   "Back",
            "knees_extended":  "Knees",
            "elbows_ready":    "Elbows",
        }
        parts = []
        for key, label in criteria_labels.items():
            ok = vr.posture_details.get(key, False)
            parts.append(f"{label}:{'OK' if ok else '--'}")
        detail_str = "  ".join(parts)
        cv2.putText(frame, detail_str, (15, y_pos),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (180, 180, 180), 1)
    y_pos += 30

    # ── Gating progress bar ────────────────────
    if vr.state in (ValidatorState.NOT_READY, ValidatorState.GATING):
        bar_x, bar_w, bar_h = 15, 250, 16
        ratio = vr.gate_progress / max(vr.gate_required, 1)
        # Background
        cv2.rectangle(frame, (bar_x, y_pos - 12),
                      (bar_x + bar_w, y_pos - 12 + bar_h),
                      (60, 60, 60), -1)
        # Filled portion
        fill_w = int(bar_w * ratio)
        bar_color = (0, 220, 0) if ratio >= 1.0 else (0, 200, 255)
        cv2.rectangle(frame, (bar_x, y_pos - 12),
                      (bar_x + fill_w, y_pos - 12 + bar_h),
                      bar_color, -1)
        cv2.putText(frame,
                    f"Gate: {vr.gate_progress}/{vr.gate_required}",
                    (bar_x + bar_w + 10, y_pos),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, (200, 200, 200), 1)
    y_pos += 30

    # ── Coaching Feedback ──────────────────────
    if vr.feedback:
        cv2.putText(frame, "COACHING:", (15, y_pos),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 165, 255), 2)  # Orange
        y_pos += 25
        for tip in vr.feedback:
            cv2.putText(frame, f"• {tip}", (15, y_pos),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 1)  # Yellow
            y_pos += 25

    return frame


# ──────────────────────────────────────────────
# Process a video file
# ──────────────────────────────────────────────

def process_video(video_path, output_path=None):
    """
    Run push-up form detection on a video file using MoveNet Thunder.

    Parameters
    ----------
    video_path : str
        Path to the input video file (.mp4, .avi, etc.).
    output_path : str or None
        If provided, save the annotated video to this path.
        If None, only display on screen (press 'q' to quit).
    """
    if not os.path.exists(video_path):
        print(f"[ERROR] Video not found: {video_path}")
        return

    # ── Load LSTM model ────────────────────────
    if not os.path.exists(LSTM_MODEL_FILE):
        print(f"[ERROR] LSTM model not found: {LSTM_MODEL_FILE}")
        print("Run  python train_model.py  first.")
        return

    model = keras.models.load_model(LSTM_MODEL_FILE)
    print(f"Loaded LSTM model from: {LSTM_MODEL_FILE}")

    # ── Load MoveNet detector ──────────────────
    download_movenet(MOVENET_MODEL_URL, MOVENET_MODEL_FILE)
    detector = MoveNetDetector(MOVENET_MODEL_FILE, num_threads=4)

    # ── Open video ─────────────────────────────
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"[ERROR] Cannot open video: {video_path}")
        return

    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    w_vid = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h_vid = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    print(f"Video: {video_path}")
    print(f"  Resolution: {w_vid}x{h_vid}  FPS: {fps:.1f}  Frames: {total_frames}")

    # ── Optional: set up video writer ──────────
    writer = None
    if output_path:
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        writer = cv2.VideoWriter(output_path, fourcc, fps, (w_vid, h_vid))
        print(f"  Output will be saved to: {output_path}")

    # ── Rolling buffer for LSTM input ──────────
    frame_buffer = deque(maxlen=SEQUENCE_LENGTH)
    frame_count = 0

    # ── Push-up validator ──────────────────────
    validator = PushUpValidator()

    # ── Prediction state ───────────────────────
    prediction_text = ""
    confidence = 0.0
    label_color = (200, 200, 200)
    validator_result = None

    # ── Dual-gate rep counter ──────────────────
    real_rep_count = 0

    print(f"\n[INFO] Processing video... Press 'q' to stop early.\n")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        h, w = frame.shape[:2]

        # ── MoveNet pose detection ─────────────
        keypoints_flat, raw_kp = detect_pose(frame, detector)
        person_detected = keypoints_flat.shape[0] == LANDMARK_FEATURES

        if person_detected:
            draw_skeleton(frame, raw_kp)

            # ── Validate posture & manage state ──
            validator_result = validator.process_frame(
                keypoints_flat, model_confidence=confidence
            )

            # Normalize, compute angles, and buffer
            normalized = normalize_frame(keypoints_flat)
            angles = compute_joint_angles(normalized)
            augmented = np.concatenate([normalized, angles])
            frame_buffer.append(augmented)

            # ── LSTM prediction (only when gate is open) ──
            frame_count += 1
            gate_is_open = validator_result.state in (
                ValidatorState.UP, ValidatorState.DOWN
            )
            if (gate_is_open
                    and len(frame_buffer) == SEQUENCE_LENGTH
                    and frame_count % PREDICT_EVERY_N_FRAMES == 0):
                seq = np.array(list(frame_buffer), dtype=np.float32)
                seq = np.expand_dims(seq, axis=0)
                pred = model.predict(seq, verbose=0)[0][0]
                confidence = pred if pred > 0.5 else 1 - pred

                if pred <= 0.5:
                    prediction_text = "Correct"
                    label_color = (0, 220, 0)
                else:
                    prediction_text = "Wrong"
                    label_color = (0, 0, 220)
        else:
            # No person detected — create a default result
            from pushup_validator import FrameResult
            validator_result = FrameResult()

        # ── Dual-gate rep counting ───────────
        if validator_result.rep_completed:
            if prediction_text == "Correct" and confidence > 0.5:
                real_rep_count += 1

        # ── Draw HUD ──────────────────────────
        frame = draw_hud(frame, prediction_text, confidence, label_color,
                         validator_result, real_rep_count)

        # ── Progress indicator ─────────────────
        current_frame = int(cap.get(cv2.CAP_PROP_POS_FRAMES))
        progress = f"Frame {current_frame}/{total_frames}"
        cv2.putText(frame, progress, (15, h - 15),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (150, 150, 150), 1)

        # Write to output video if requested
        if writer:
            writer.write(frame)

        # Display
        cv2.imshow("Push-up Form Detection - Video", frame)

        # Use waitKey matched to video FPS for natural playback speed
        delay = max(1, int(1000 / fps))
        if cv2.waitKey(delay) & 0xFF == ord("q"):
            break

    # ── Cleanup ────────────────────────────────
    cap.release()
    if writer:
        writer.release()
        print(f"\nAnnotated video saved to: {output_path}")
    cv2.destroyAllWindows()

    print(f"\nVideo processing complete. Total reps: {real_rep_count}")


# ──────────────────────────────────────────────
# Main real-time loop (webcam)
# ──────────────────────────────────────────────

def main():
    # ── Load LSTM model ────────────────────────
    if not os.path.exists(LSTM_MODEL_FILE):
        print(f"[ERROR] LSTM model not found: {LSTM_MODEL_FILE}")
        print("Run  python train_model.py  first.")
        return

    model = keras.models.load_model(LSTM_MODEL_FILE)
    print(f"Loaded LSTM model from: {LSTM_MODEL_FILE}")

    # ── Load MoveNet detector ──────────────────
    download_movenet(MOVENET_MODEL_URL, MOVENET_MODEL_FILE)
    detector = MoveNetDetector(MOVENET_MODEL_FILE, num_threads=4)

    # ── Open webcam ────────────────────────────
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] Cannot access webcam (index 0).")
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    # ── Rolling buffer for LSTM input ──────────
    frame_buffer = deque(maxlen=SEQUENCE_LENGTH)
    frame_count = 0

    # ── Push-up validator ──────────────────────
    validator = PushUpValidator()

    # ── Prediction state ───────────────────────
    prediction_text = ""
    confidence = 0.0
    label_color = (200, 200, 200)
    validator_result = None

    # ── Dual-gate rep counter ──────────────────
    real_rep_count = 0

    print("\n[INFO] MoveNet Thunder — Push-up Detection")
    print("[INFO] Press 'q' to quit.\n")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.flip(frame, 1)  # mirror for natural interaction
        h, w = frame.shape[:2]

        # ── MoveNet pose detection ─────────────
        keypoints_flat, raw_kp = detect_pose(frame, detector)
        person_detected = keypoints_flat.shape[0] == LANDMARK_FEATURES

        if person_detected:
            draw_skeleton(frame, raw_kp)

            # ── Validate posture & manage state ──
            validator_result = validator.process_frame(
                keypoints_flat, model_confidence=confidence
            )

            # Normalize, compute angles, and buffer
            normalized = normalize_frame(keypoints_flat)
            angles = compute_joint_angles(normalized)
            augmented = np.concatenate([normalized, angles])
            frame_buffer.append(augmented)

            # ── LSTM prediction (only when gate is open) ──
            frame_count += 1
            gate_is_open = validator_result.state in (
                ValidatorState.UP, ValidatorState.DOWN
            )
            if (gate_is_open
                    and len(frame_buffer) == SEQUENCE_LENGTH
                    and frame_count % PREDICT_EVERY_N_FRAMES == 0):
                seq = np.array(list(frame_buffer), dtype=np.float32)
                seq = np.expand_dims(seq, axis=0)
                pred = model.predict(seq, verbose=0)[0][0]
                confidence = pred if pred > 0.5 else 1 - pred

                if pred <= 0.5:
                    prediction_text = "Correct"
                    label_color = (0, 220, 0)
                else:
                    prediction_text = "Wrong"
                    label_color = (0, 0, 220)
        else:
            # No person detected — create a default result
            from pushup_validator import FrameResult
            validator_result = FrameResult()

        # ── Dual-gate rep counting ───────────
        if validator_result.rep_completed:
            if prediction_text == "Correct" and confidence > 0.5:
                real_rep_count += 1

        # ── Draw HUD ──────────────────────────
        frame = draw_hud(frame, prediction_text, confidence, label_color,
                         validator_result, real_rep_count)

        cv2.imshow("Push-up Form Detection", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    # ── Cleanup ────────────────────────────────
    cap.release()
    cv2.destroyAllWindows()

    print(f"\nSession ended. Total reps: {real_rep_count}")


if __name__ == "__main__":
    print("=" * 50)
    print("  Push-up Form Detection (MoveNet Thunder)")
    print("=" * 50)
    print("  1 — Analyze a video file")
    print("  2 — Live webcam detection")
    print("=" * 50)

    choice = input("\nChoose mode (1 or 2): ").strip()

    if choice == "1":
        while True:
            # Open file picker dialog
            from tkinter import Tk, filedialog
            Tk().withdraw()  # hide root window
            video_file = filedialog.askopenfilename(
                title="Select a push-up video",
                filetypes=[
                    ("Video files", "*.mp4 *.avi *.mov *.mkv *.wmv"),
                    ("All files", "*.*"),
                ],
            )
            if not video_file:
                print("[INFO] No file selected. Exiting.")
            else:
                # Ask if user wants to save output
                save = input("Save annotated output? (y/n): ").strip().lower()
                out_file = None
                if save == "y":
                    out_file = filedialog.asksaveasfilename(
                        title="Save annotated video as",
                        defaultextension=".mp4",
                        filetypes=[("MP4 video", "*.mp4"), ("All files", "*.*")],
                    )
                process_video(video_file, output_path=out_file)

    elif choice == "2":
        main()

    else:
        print("[ERROR] Invalid choice. Please enter 1 or 2.")
