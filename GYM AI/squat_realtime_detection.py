"""
squat_realtime_detection.py
===========================
Real-time squat form detection and rep counting using webcam or video file.

╔══════════════════════════════════════════════════════════════════╗
║  MOVENET THUNDER (TFLite) + SQUAT LSTM (Binary)                 ║
║                                                                  ║
║  MoveNet outputs 17 keypoints (y, x, confidence).                ║
║  These are converted into the 187-feature vector matching the    ║
║  training pickle format:                                         ║
║    • 51 values: 17 keypoints × (x, y, confidence) — raw          ║
║    •136 values: pairwise Euclidean distances — raw               ║
║                                                                  ║
║  SquatValidator handles gating, posture checks, and              ║
║  DOWN→UP rep counting via knee angles.                           ║
╚══════════════════════════════════════════════════════════════════╝

Features:
  • MoveNet Thunder TFLite for pose detection
  • Squat LSTM model (squat_lstm_model.h5) for binary form classification
  • SquatValidator state machine for posture validation & rep counting
  • Dual-gate rep counting (transition + model + confidence)
  • Rolling 30-frame buffer, predicts every 10 frames
  • HUD overlay with rep count, state, posture details, coaching

Prerequisites:
    • squat_lstm_model.h5 (run squat_train_model.py first)
    • movenet_thunder.tflite (auto-downloaded on first run)
    • A connected webcam (for live mode)

Usage:
    python squat_realtime_detection.py                          # interactive menu
    python squat_realtime_detection.py video.mp4                # video mode (display only)
    python squat_realtime_detection.py video.mp4 output.mp4     # video mode (save output)

Controls:
    q — quit
"""

import os
import sys
import cv2
import numpy as np
import urllib.request
from collections import deque
from itertools import combinations

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

from squat_validator import SquatValidator, ValidatorState, FrameResult

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
SQUAT_MODEL_FILE = os.path.join(PROJECT_DIR, "squat_lstm_model.h5")
MOVENET_MODEL_FILE = os.path.join(PROJECT_DIR, "movenet_thunder.tflite")
MOVENET_MODEL_URL = (
    "https://tfhub.dev/google/lite-model/"
    "movenet/singlepose/thunder/tflite/float16/4?lite-format=tflite"
)

SEQUENCE_LENGTH = 30          # must match training
PREDICT_EVERY_N_FRAMES = 10   # run LSTM inference every N frames
NUM_KEYPOINTS_MOVENET = 17    # MoveNet outputs 17 keypoints

# MediaPipe-compatible constants (used by SquatValidator internally)
NUM_KEYPOINTS_MP = 33
FEATURES_PER_KEYPOINT = 4     # x, y, z, visibility
LANDMARK_FEATURES = NUM_KEYPOINTS_MP * FEATURES_PER_KEYPOINT  # 132

# MoveNet → MediaPipe keypoint mapping (for SquatValidator posture checks)
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
# Pose detection — two outputs
# ──────────────────────────────────────────────

def detect_pose(frame: np.ndarray, detector: MoveNetDetector):
    """
    Run MoveNet on a single frame and return:
      1. MediaPipe-compat flat (132,) for SquatValidator
      2. Raw MoveNet keypoints (17, 3) for LSTM features & drawing

    Returns
    -------
    coords : np.ndarray (132,) — MediaPipe-format flat for validator
             Empty array if no confident keypoints detected.
    raw_keypoints : np.ndarray (17, 3) — [y, x, confidence] for drawing
    """
    raw_kp = detector.detect(frame)  # (17, 3) — [y, x, conf]

    # Check if enough keypoints are confident (core body joints)
    core_joints = [5, 6, 7, 8, 9, 10, 11, 12]  # shoulders, elbows, wrists, hips
    core_confidences = [raw_kp[i, 2] for i in core_joints]
    if np.mean(core_confidences) < 0.3:
        return np.empty(0, dtype=np.float32), raw_kp

    # Build MediaPipe-compatible (132,) flat array for SquatValidator
    coords = np.zeros(LANDMARK_FEATURES, dtype=np.float32)

    for mn_idx, mp_idx in MOVENET_TO_MEDIAPIPE.items():
        y_norm, x_norm, conf = raw_kp[mn_idx]
        offset = mp_idx * FEATURES_PER_KEYPOINT
        coords[offset]     = x_norm      # x (MoveNet gives y, x — we swap)
        coords[offset + 1] = y_norm      # y
        coords[offset + 2] = 0.0         # z (MoveNet is 2D, no depth)
        coords[offset + 3] = conf        # visibility / confidence

    return coords, raw_kp


# ──────────────────────────────────────────────
# Squat LSTM feature extraction (matches training pickle)
# ──────────────────────────────────────────────

def extract_squat_lstm_features(raw_kp: np.ndarray) -> np.ndarray:
    """
    Convert MoveNet (17, 3) keypoints into the 187-feature vector
    expected by the squat LSTM model.

    Matches the training pickle format:
      - normalized_key_points: 17 × (x, y, z) = 51 features
        → hip-centered, torso-length normalized, z=0 (MoveNet is 2D)
      - normalized_distance_matrix: C(17,2) = 136 pairwise distances
        → computed on the normalized keypoints

    The training pickle stores keypoints already centred on the hip
    midpoint and scaled by torso length (shoulder-centre to hip-centre).
    We replicate that normalization here.
    """
    # ── Step 1: Convert MoveNet (y, x, conf) → (x, y, 0) ──────────
    # Use z=0 because MoveNet is 2D-only; the training data has real
    # z-depth but setting z=0 is far better than using confidence scores
    # (which range 0.5–1.0 vs z which ranges -0.76 to +0.07).
    keypoints = np.zeros((NUM_KEYPOINTS_MOVENET, 3), dtype=np.float32)
    for i in range(NUM_KEYPOINTS_MOVENET):
        y_norm, x_norm, conf = raw_kp[i]
        keypoints[i] = [x_norm, y_norm, 0.0]  # (x, y, z=0)

    # ── Step 2: Hip-centre subtraction ─────────────────────────────
    # MoveNet indices: 11 = left_hip, 12 = right_hip
    hip_centre = (keypoints[11] + keypoints[12]) / 2.0
    keypoints = keypoints - hip_centre  # centre on hip midpoint

    # ── Step 3: Torso-length normalization ─────────────────────────
    # MoveNet indices: 5 = left_shoulder, 6 = right_shoulder
    shoulder_centre = (keypoints[5] + keypoints[6]) / 2.0
    # hip_centre is now [0,0,0] after subtraction
    torso_length = np.linalg.norm(shoulder_centre)
    if torso_length < 1e-6:
        torso_length = 1.0
    keypoints = keypoints / torso_length

    # ── Step 4: Flatten → 51 features ──────────────────────────────
    normalized_kp_flat = keypoints.flatten()  # (51,)

    # ── Step 5: Pairwise distances on normalized keypoints → 136 ───
    distances = []
    for i, j in combinations(range(NUM_KEYPOINTS_MOVENET), 2):
        dist = np.linalg.norm(keypoints[i] - keypoints[j])
        distances.append(dist)
    distances = np.array(distances, dtype=np.float32)

    return np.concatenate([normalized_kp_flat, distances])  # (187,)


# ──────────────────────────────────────────────
# Drawing helpers
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
    Draw the heads-up display overlay with squat validation info.

    Parameters
    ----------
    frame : np.ndarray
    prediction_text : str  — "Correct" or "Wrong" or ""
    confidence : float
    label_color : tuple
    validator_result : FrameResult from SquatValidator
    real_rep_count : int  — externally managed dual-gate rep count
    """
    vr = validator_result
    h, w = frame.shape[:2]

    # ── Semi-transparent background panel ──────
    overlay = frame.copy()
    feedback_count = len(vr.feedback) if vr else 0
    panel_height = 280 + (feedback_count * 25)

    cv2.rectangle(overlay, (0, 0), (440, panel_height), (20, 20, 20), -1)
    frame = cv2.addWeighted(overlay, 0.65, frame, 0.35, 0)

    if not vr:
        return frame

    y_pos = 35  # vertical cursor

    # ── Title ───────────────────────────────────
    cv2.putText(frame, "SQUAT DETECTION", (15, y_pos),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 200, 255), 2)
    y_pos += 35

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

    # ── Posture criteria details (squat-specific) ──
    if vr.posture_details:
        criteria_labels = {
            "body_upright": "Upright",
            "hip_ok":       "Hips",
            "knees_ready":  "Knees",
        }
        parts = []
        for key, label in criteria_labels.items():
            ok = vr.posture_details.get(key, False)
            parts.append(f"{label}:{'OK' if ok else '--'}")
        detail_str = "  ".join(parts)
        cv2.putText(frame, detail_str, (15, y_pos),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (180, 180, 180), 1)
    y_pos += 30

    # ── Knee angle display ─────────────────────
    if vr.angles:
        l_knee = vr.angles.get("l_knee", 0.0)
        r_knee = vr.angles.get("r_knee", 0.0)
        avg_knee = (l_knee + r_knee) / 2.0
        angle_color = (0, 220, 0) if avg_knee > 140 else (0, 200, 255) if avg_knee > 110 else (0, 100, 255)
        cv2.putText(frame, f"Knee Angle: {avg_knee:.0f} deg", (15, y_pos),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, angle_color, 2)
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
            cv2.putText(frame, f"  {tip}", (15, y_pos),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 1)  # Yellow
            y_pos += 25

    return frame


# ──────────────────────────────────────────────
# Process a video file
# ──────────────────────────────────────────────

def process_video(video_path, output_path=None):
    """
    Run squat form detection on a video file using MoveNet Thunder.

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
    if not os.path.exists(SQUAT_MODEL_FILE):
        print(f"[ERROR] Squat LSTM model not found: {SQUAT_MODEL_FILE}")
        print("Run  python squat_train_model.py  first.")
        return

    model = keras.models.load_model(SQUAT_MODEL_FILE)
    print(f"Loaded squat LSTM model from: {SQUAT_MODEL_FILE}")

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

    # ── Squat validator (relaxed thresholds for robust counting) ──
    validator = SquatValidator(
        knee_down_angle=120.0,        # easier to trigger DOWN (was 110)
        knee_up_angle=155.0,          # easier to trigger UP (was 140)
        knee_ready_min=130.0,         # less strict standing check (was 140)
        posture_loss_tolerance=60,    # more forgiving during motion (was 25)
        gate_frames=3,                # faster gate (was 5)
        hip_angle_range=(30.0, 180.0),  # wider hip range (was 40-180)
    )

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

            # ── Validate posture & manage state (uses MediaPipe-compat format) ──
            validator_result = validator.process_frame(
                keypoints_flat, model_confidence=confidence
            )

            # ── Extract 187-feature LSTM input (matches training pickle) ──
            lstm_features = extract_squat_lstm_features(raw_kp)
            frame_buffer.append(lstm_features)

            # ── LSTM prediction (only when gate is open) ──
            frame_count += 1
            gate_is_open = validator_result.state in (
                ValidatorState.UP, ValidatorState.DOWN
            )
            if (gate_is_open
                    and len(frame_buffer) == SEQUENCE_LENGTH
                    and frame_count % PREDICT_EVERY_N_FRAMES == 0):
                seq = np.array(list(frame_buffer), dtype=np.float32)
                seq = np.expand_dims(seq, axis=0)  # (1, 30, 187)
                pred = model.predict(seq, verbose=0)[0][0]
                confidence = float(pred if pred > 0.5 else 1 - pred)

                if pred <= 0.5:
                    prediction_text = "Correct"
                    label_color = (0, 220, 0)
                else:
                    prediction_text = "Wrong"
                    label_color = (0, 0, 220)

            # ── Debug: print state info every 5 frames ──
            if frame_count % 5 == 0:
                avg_knee = 0.0
                if validator_result.angles:
                    lk = validator_result.angles.get("l_knee", 0)
                    rk = validator_result.angles.get("r_knee", 0)
                    avg_knee = (lk + rk) / 2.0
                print(f"  F{frame_count:4d}  "
                      f"State={validator_result.state.name:10s}  "
                      f"Knee={avg_knee:5.1f}°  "
                      f"Posture={'OK' if validator_result.is_valid_posture else 'NO':3s}  "
                      f"Gate={validator_result.gate_progress}/{validator_result.gate_required}  "
                      f"Reps={validator_result.rep_count}  "
                      f"RepDone={'YES' if validator_result.rep_completed else '---'}")
        else:
            # No person detected — create a default result
            validator_result = FrameResult()

        # ── Dual-gate rep counting (counts only if Correct form) ──
        if validator_result.rep_completed:
            if prediction_text == "Correct":
                real_rep_count += 1
                print(f"  >>> REP #{real_rep_count} COUNTED! (Form: Correct) <<<")
            else:
                print(f"  >>> REP NOT COUNTED (Form: {prediction_text}) <<<")

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
        cv2.imshow("Squat Form Detection - Video", frame)

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
    if not os.path.exists(SQUAT_MODEL_FILE):
        print(f"[ERROR] Squat LSTM model not found: {SQUAT_MODEL_FILE}")
        print("Run  python squat_train_model.py  first.")
        return

    model = keras.models.load_model(SQUAT_MODEL_FILE)
    print(f"Loaded squat LSTM model from: {SQUAT_MODEL_FILE}")

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

    # ── Squat validator (relaxed thresholds for robust counting) ──
    validator = SquatValidator(
        knee_down_angle=120.0,
        knee_up_angle=155.0,
        knee_ready_min=130.0,
        posture_loss_tolerance=60,
        gate_frames=3,
        hip_angle_range=(30.0, 180.0),
    )

    # ── Prediction state ───────────────────────
    prediction_text = ""
    confidence = 0.0
    label_color = (200, 200, 200)
    validator_result = None

    # ── Dual-gate rep counter ──────────────────
    real_rep_count = 0

    print("\n[INFO] MoveNet Thunder — Squat Detection")
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

            # ── Validate posture & manage state (uses MediaPipe-compat format) ──
            validator_result = validator.process_frame(
                keypoints_flat, model_confidence=confidence
            )

            # ── Extract 187-feature LSTM input (matches training pickle) ──
            lstm_features = extract_squat_lstm_features(raw_kp)
            frame_buffer.append(lstm_features)

            # ── LSTM prediction (only when gate is open) ──
            frame_count += 1
            gate_is_open = validator_result.state in (
                ValidatorState.UP, ValidatorState.DOWN
            )
            if (gate_is_open
                    and len(frame_buffer) == SEQUENCE_LENGTH
                    and frame_count % PREDICT_EVERY_N_FRAMES == 0):
                seq = np.array(list(frame_buffer), dtype=np.float32)
                seq = np.expand_dims(seq, axis=0)  # (1, 30, 187)
                pred = model.predict(seq, verbose=0)[0][0]
                confidence = float(pred if pred > 0.5 else 1 - pred)

                if pred <= 0.5:
                    prediction_text = "Correct"
                    label_color = (0, 220, 0)
                else:
                    prediction_text = "Wrong"
                    label_color = (0, 0, 220)
        else:
            # No person detected — create a default result
            validator_result = FrameResult()

        # ── Dual-gate rep counting (counts only if Correct form) ──
        if validator_result.rep_completed:
            if prediction_text == "Correct":
                real_rep_count += 1
                print(f"  >>> REP #{real_rep_count} COUNTED! (Form: Correct) <<<")
            else:
                print(f"  >>> REP NOT COUNTED (Form: {prediction_text}) <<<")

        # ── Draw HUD ──────────────────────────
        frame = draw_hud(frame, prediction_text, confidence, label_color,
                         validator_result, real_rep_count)

        cv2.imshow("Squat Form Detection", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    # ── Cleanup ────────────────────────────────
    cap.release()
    cv2.destroyAllWindows()

    print(f"\nSession ended. Total reps: {real_rep_count}")


if __name__ == "__main__":
    print("=" * 50)
    print("  Squat Form Detection (MoveNet Thunder)")
    print("=" * 50)

    # ── CLI args: quick launch ─────────────────
    if len(sys.argv) >= 2:
        video_file = sys.argv[1]
        out_file = sys.argv[2] if len(sys.argv) >= 3 else None
        process_video(video_file, output_path=out_file)
        sys.exit(0)

    # ── Interactive menu ───────────────────────
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
                title="Select a squat video",
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
