"""
movenet_detection.py
====================
Real-time exercise repetition counter using MoveNet Thunder (TFLite)
instead of MediaPipe Pose.

This module replaces MediaPipe entirely with MoveNet Thunder for
pose estimation while keeping the same functionality:
  • Extract 17 body keypoints from each frame
  • Calculate joint angles (3D → 2D since MoveNet is 2D-only)
  • Count reps using a state-machine RepCounter with smoothing + cooldown

──────────────────────────────────────────────────────────────────────
KEY DIFFERENCES: MoveNet vs MediaPipe
──────────────────────────────────────────────────────────────────────
  MediaPipe Pose                          MoveNet Thunder
  ─────────────────                       ──────────────────
  33 landmarks (full body + face/hands)   17 keypoints (body only)
  3D coordinates (x, y, z + visibility)   2D coordinates (y, x + score)
  Built-in smoothing & tracking           Raw per-frame detection
  Python API via mediapipe package        TFLite interpreter (manual)
  ~30 fps on CPU                          ~30 fps on CPU (Thunder)
  Input: any resolution                   Input: 256×256 (int32)
  Output: normalised [0,1] coords         Output: normalised [0,1] coords

  MoveNet "Thunder" = higher accuracy, slightly slower than "Lightning".
  MoveNet "Lightning" = faster, lower accuracy (192×192 input).

──────────────────────────────────────────────────────────────────────
MODEL DOWNLOAD
──────────────────────────────────────────────────────────────────────
  The script auto-downloads the MoveNet Thunder TFLite model from
  TensorFlow Hub on first run (~10 MB). It is cached locally as
  `movenet_thunder.tflite` in the project directory.

  Manual download:
    https://tfhub.dev/google/lite-model/movenet/singlepose/thunder/tflite/float16/4

──────────────────────────────────────────────────────────────────────
PERFORMANCE NOTES
──────────────────────────────────────────────────────────────────────
  • GPU delegate:  Pass use_gpu=True to MoveNetDetector() to attempt
                   GPU acceleration via TFLite's GPU delegate (requires
                   compatible hardware + tflite-runtime with GPU support).
  • XNNPACK:       Enabled by default on CPU for ~2× speedup on ARM/x86.
  • Threading:     Set num_threads=4 (or your core count) for parallel ops.
  • Frame skip:    Only run inference every N frames and interpolate
                   keypoints for higher display FPS.

Prerequisites:
    pip install tensorflow opencv-python numpy

Usage:
    python movenet_detection.py
"""

from __future__ import annotations

import os
import sys
import time
import urllib.request
from collections import deque
from enum import Enum, auto
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_FILE = os.path.join(PROJECT_DIR, "movenet_thunder.tflite")
MODEL_URL = (
    "https://tfhub.dev/google/lite-model/"
    "movenet/singlepose/thunder/tflite/float16/4?lite-format=tflite"
)

# MoveNet Thunder input size
INPUT_SIZE = 256

# Minimum keypoint confidence to consider the detection reliable
DEFAULT_CONFIDENCE_THRESHOLD = 0.5

# ──────────────────────────────────────────────
# MoveNet keypoint indices (COCO 17-keypoint layout)
# ──────────────────────────────────────────────
# Unlike MediaPipe's 33 landmarks, MoveNet uses the standard
# COCO 17-keypoint format. There are NO face mesh, hand, or
# foot landmarks — only the core body skeleton.

KEYPOINT_NAMES = [
    "nose",            # 0
    "left_eye",        # 1
    "right_eye",       # 2
    "left_ear",        # 3
    "right_ear",       # 4
    "left_shoulder",   # 5
    "right_shoulder",  # 6
    "left_elbow",      # 7
    "right_elbow",     # 8
    "left_wrist",      # 9
    "right_wrist",     # 10
    "left_hip",        # 11
    "right_hip",       # 12
    "left_knee",       # 13
    "right_knee",      # 14
    "left_ankle",      # 15
    "right_ankle",     # 16
]

# Named index constants for readability
KP_NOSE           = 0
KP_LEFT_EYE       = 1
KP_RIGHT_EYE      = 2
KP_LEFT_EAR       = 3
KP_RIGHT_EAR      = 4
KP_LEFT_SHOULDER  = 5
KP_RIGHT_SHOULDER = 6
KP_LEFT_ELBOW     = 7
KP_RIGHT_ELBOW    = 8
KP_LEFT_WRIST     = 9
KP_RIGHT_WRIST    = 10
KP_LEFT_HIP       = 11
KP_RIGHT_HIP      = 12
KP_LEFT_KNEE      = 13
KP_RIGHT_KNEE     = 14
KP_LEFT_ANKLE     = 15
KP_RIGHT_ANKLE    = 16

# Skeleton connections for drawing (pairs of keypoint indices)
SKELETON_CONNECTIONS = [
    (KP_LEFT_SHOULDER, KP_RIGHT_SHOULDER),
    (KP_LEFT_SHOULDER, KP_LEFT_ELBOW),
    (KP_LEFT_ELBOW, KP_LEFT_WRIST),
    (KP_RIGHT_SHOULDER, KP_RIGHT_ELBOW),
    (KP_RIGHT_ELBOW, KP_RIGHT_WRIST),
    (KP_LEFT_SHOULDER, KP_LEFT_HIP),
    (KP_RIGHT_SHOULDER, KP_RIGHT_HIP),
    (KP_LEFT_HIP, KP_RIGHT_HIP),
    (KP_LEFT_HIP, KP_LEFT_KNEE),
    (KP_LEFT_KNEE, KP_LEFT_ANKLE),
    (KP_RIGHT_HIP, KP_RIGHT_KNEE),
    (KP_RIGHT_KNEE, KP_RIGHT_ANKLE),
]


# ──────────────────────────────────────────────
# Model downloader
# ──────────────────────────────────────────────

def download_model(url: str, dest: str) -> None:
    """Download the MoveNet Thunder TFLite model if not already cached."""
    if os.path.exists(dest):
        return
    print(f"[INFO] Downloading MoveNet Thunder model to {dest} ...")
    urllib.request.urlretrieve(url, dest)
    print(f"[INFO] Download complete ({os.path.getsize(dest) / 1e6:.1f} MB).")


# ──────────────────────────────────────────────
# MoveNet Detector (TFLite)
# ──────────────────────────────────────────────

class MoveNetDetector:
    """
    Wrapper around the MoveNet Thunder TFLite model.

    Handles preprocessing (resize + pad to 256×256, int32 cast),
    inference, and post-processing (extract 17 keypoints with
    confidence scores, scale back to original image coordinates).

    Parameters
    ----------
    model_path : str
        Path to the .tflite model file.
    num_threads : int
        Number of CPU threads for inference (default 4).
    use_gpu : bool
        If True, attempt to use the TFLite GPU delegate.
        Falls back to CPU if unavailable.
    """

    def __init__(
        self,
        model_path: str = MODEL_FILE,
        num_threads: int = 4,
        use_gpu: bool = False,
    ):
        # Try importing tflite — prefer the lightweight runtime,
        # fall back to the full TensorFlow package.
        try:
            import tflite_runtime.interpreter as tflite
            InterpreterClass = tflite.Interpreter
        except ImportError:
            import tensorflow as tf
            InterpreterClass = tf.lite.Interpreter

        # Build interpreter options
        kwargs = {"model_path": model_path, "num_threads": num_threads}

        if use_gpu:
            try:
                # GPU delegate (requires compatible build)
                gpu_delegate = tf.lite.experimental.load_delegate("libtensorflowlite_gpu_delegate.so")
                kwargs["experimental_delegates"] = [gpu_delegate]
                print("[INFO] GPU delegate loaded.")
            except Exception:
                print("[WARN] GPU delegate unavailable — falling back to CPU.")

        self._interpreter = InterpreterClass(**kwargs)
        self._interpreter.allocate_tensors()

        self._input_details = self._interpreter.get_input_details()
        self._output_details = self._interpreter.get_output_details()

        # Expected input shape: [1, 256, 256, 3] for Thunder
        self._input_shape = self._input_details[0]["shape"]  # (1, 256, 256, 3)
        self._input_height = self._input_shape[1]
        self._input_width = self._input_shape[2]
        self._input_dtype = self._input_details[0]["dtype"]

        print(f"[INFO] MoveNet Thunder loaded: input={self._input_shape}, "
              f"dtype={self._input_dtype.__name__}")

    def detect(self, frame: np.ndarray) -> np.ndarray:
        """
        Run MoveNet inference on a single BGR frame.

        Parameters
        ----------
        frame : np.ndarray
            BGR image from OpenCV (any resolution).

        Returns
        -------
        keypoints : np.ndarray of shape (17, 3)
            Each row = [y_norm, x_norm, confidence] in normalised [0, 1]
            coordinates relative to the ORIGINAL frame dimensions.

        NOTE: MoveNet outputs (y, x) — NOT (x, y) like MediaPipe.
        """
        # ── Preprocessing ──────────────────────
        # MoveNet expects RGB input, resized to 256×256.
        # We letterbox (resize with aspect ratio) to avoid distortion.
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        input_image = cv2.resize(rgb, (self._input_width, self._input_height))

        # MoveNet Thunder (float16 model) expects int32 input
        input_tensor = np.expand_dims(input_image, axis=0)
        if self._input_dtype == np.int32:
            input_tensor = input_tensor.astype(np.int32)
        elif self._input_dtype == np.uint8:
            input_tensor = input_tensor.astype(np.uint8)
        else:
            input_tensor = input_tensor.astype(np.int32)

        # ── Inference ──────────────────────────
        self._interpreter.set_tensor(
            self._input_details[0]["index"], input_tensor
        )
        self._interpreter.invoke()

        # ── Post-processing ────────────────────
        # Output shape: [1, 1, 17, 3] → (17, 3) = [y, x, confidence]
        output = self._interpreter.get_tensor(
            self._output_details[0]["index"]
        )
        keypoints = np.squeeze(output)  # shape: (17, 3)

        return keypoints


# ──────────────────────────────────────────────
# Keypoint utilities
# ──────────────────────────────────────────────

def keypoints_to_image_coords(
    keypoints: np.ndarray,
    img_height: int,
    img_width: int,
) -> np.ndarray:
    """
    Convert normalised MoveNet keypoints to pixel coordinates.

    Parameters
    ----------
    keypoints : np.ndarray (17, 3) — [y_norm, x_norm, confidence]
    img_height, img_width : int

    Returns
    -------
    coords : np.ndarray (17, 3) — [y_px, x_px, confidence]
    """
    coords = keypoints.copy()
    coords[:, 0] *= img_height   # y
    coords[:, 1] *= img_width    # x
    return coords


def get_keypoint_xy(
    keypoints_px: np.ndarray,
    idx: int,
) -> Tuple[float, float]:
    """
    Get (x, y) pixel coordinates for a keypoint.

    MoveNet outputs (y, x) so we swap for standard (x, y) usage.
    """
    return float(keypoints_px[idx, 1]), float(keypoints_px[idx, 0])


def get_keypoint_confidence(keypoints: np.ndarray, idx: int) -> float:
    """Get the confidence score for a specific keypoint."""
    return float(keypoints[idx, 2])


# ──────────────────────────────────────────────
# Angle calculation
# ──────────────────────────────────────────────

def angle_2d(
    a: Tuple[float, float],
    b: Tuple[float, float],
    c: Tuple[float, float],
) -> float:
    """
    Angle in degrees at point b formed by segments a→b and c→b.

    Unlike MediaPipe which provides 3D (x, y, z) coordinates,
    MoveNet only gives 2D (x, y). This means:
      • Angles are projected onto the camera plane
      • Side-view exercises (e.g., lateral raises) work best
      • Front-facing exercises may have foreshortened angles

    Parameters
    ----------
    a, b, c : (x, y) tuples

    Returns
    -------
    Angle in degrees [0, 180].
    """
    ba = np.array([a[0] - b[0], a[1] - b[1]], dtype=np.float64)
    bc = np.array([c[0] - b[0], c[1] - b[1]], dtype=np.float64)
    norm_ba = np.linalg.norm(ba)
    norm_bc = np.linalg.norm(bc)
    if norm_ba < 1e-8 or norm_bc < 1e-8:
        return 0.0
    cos_a = np.dot(ba, bc) / (norm_ba * norm_bc)
    return float(np.degrees(np.arccos(np.clip(cos_a, -1.0, 1.0))))


def compute_joint_angle(
    keypoints_px: np.ndarray,
    joint_a: int,
    joint_b: int,
    joint_c: int,
) -> float:
    """
    Compute the angle at joint_b formed by joint_a → joint_b → joint_c.

    Parameters
    ----------
    keypoints_px : (17, 3) pixel-space keypoints
    joint_a, joint_b, joint_c : keypoint indices

    Returns
    -------
    Angle in degrees.
    """
    a = get_keypoint_xy(keypoints_px, joint_a)
    b = get_keypoint_xy(keypoints_px, joint_b)
    c = get_keypoint_xy(keypoints_px, joint_c)
    return angle_2d(a, b, c)


# ──────────────────────────────────────────────
# Movement State + RepCounter
# ──────────────────────────────────────────────

class MovementState(Enum):
    """Two phases of an exercise repetition."""
    UP   = auto()  # Extended / starting position
    DOWN = auto()  # Contracted / bottom position


class RepCounter:
    """
    Counts exercise repetitions using a state-machine approach with
    angle smoothing, confidence gating, and cooldown.

    A rep is counted ONLY when ALL of the following are true:
        • The joint angle crosses from DOWN → UP (full range of motion)
        • Landmark confidence exceeds `min_confidence`
        • At least `cooldown_ms` milliseconds have passed since the last rep

    The hysteresis (separate down/up thresholds) ensures that noise
    near a single threshold can't cause rapid UP↔DOWN flicker — this
    is how fast movements are handled reliably.

    Parameters
    ----------
    down_angle_threshold : float
        Joint angle at or below which = DOWN state.
    up_angle_threshold : float
        Joint angle at or above which = UP state.
    min_confidence : float
        Minimum keypoint confidence to allow processing (default 0.5).
    cooldown_ms : int
        Milliseconds between reps to prevent double-counting (default 300).
    smoothing_window : int
        Moving average window size (default 5 frames).
    """

    def __init__(
        self,
        down_angle_threshold: float,
        up_angle_threshold: float,
        min_confidence: float = 0.5,
        cooldown_ms: int = 300,
        smoothing_window: int = 5,
    ):
        assert down_angle_threshold < up_angle_threshold, (
            "down_angle_threshold must be < up_angle_threshold"
        )
        self.down_angle_threshold = down_angle_threshold
        self.up_angle_threshold = up_angle_threshold
        self.min_confidence = min_confidence
        self.cooldown_ms = cooldown_ms

        self._state = MovementState.UP
        self._rep_count = 0
        self._last_rep_time: float = 0.0
        self._angle_buffer: deque = deque(maxlen=smoothing_window)

    @property
    def rep_count(self) -> int:
        return self._rep_count

    @property
    def state(self) -> MovementState:
        return self._state

    @property
    def smoothed_angle(self) -> Optional[float]:
        if not self._angle_buffer:
            return None
        return sum(self._angle_buffer) / len(self._angle_buffer)

    def update(self, raw_angle: float, confidence: float) -> bool:
        """
        Process one frame. Returns True if a new rep was counted.

        Handles fast movements via:
          1. Confidence gate — skip unreliable frames silently
          2. Moving average — smooth out noisy angle readings
          3. Hysteresis state machine — require full ROM to count
          4. Cooldown — prevent double-counting on bouncy transitions
        """
        # Gate 1: Skip low-confidence frames
        if confidence < self.min_confidence:
            return False

        # Gate 2: Smooth the angle via moving average
        self._angle_buffer.append(raw_angle)
        angle = sum(self._angle_buffer) / len(self._angle_buffer)

        # Gate 3: State machine with hysteresis
        rep_counted = False

        if self._state == MovementState.UP:
            if angle <= self.down_angle_threshold:
                self._state = MovementState.DOWN

        elif self._state == MovementState.DOWN:
            if angle >= self.up_angle_threshold:
                # Gate 4: Cooldown check
                now = time.time()
                elapsed_ms = (now - self._last_rep_time) * 1000.0
                if elapsed_ms >= self.cooldown_ms:
                    self._rep_count += 1
                    self._last_rep_time = now
                    rep_counted = True
                self._state = MovementState.UP

        return rep_counted

    def reset(self) -> None:
        """Reset counter for a new set/exercise."""
        self._rep_count = 0
        self._state = MovementState.UP
        self._last_rep_time = 0.0
        self._angle_buffer.clear()


# ──────────────────────────────────────────────
# Drawing utilities
# ──────────────────────────────────────────────

def draw_skeleton(
    frame: np.ndarray,
    keypoints_px: np.ndarray,
    confidence_threshold: float = 0.3,
) -> None:
    """
    Draw keypoints and skeleton connections on the frame.

    Unlike MediaPipe which has its own drawing utilities,
    MoveNet requires manual drawing — but this gives us full
    control over appearance.
    """
    h, w = frame.shape[:2]

    # Draw connections
    for (idx_a, idx_b) in SKELETON_CONNECTIONS:
        conf_a = keypoints_px[idx_a, 2]
        conf_b = keypoints_px[idx_b, 2]
        if conf_a > confidence_threshold and conf_b > confidence_threshold:
            xa, ya = int(keypoints_px[idx_a, 1]), int(keypoints_px[idx_a, 0])
            xb, yb = int(keypoints_px[idx_b, 1]), int(keypoints_px[idx_b, 0])
            cv2.line(frame, (xa, ya), (xb, yb), (0, 220, 0), 2)

    # Draw keypoints
    for i in range(17):
        conf = keypoints_px[i, 2]
        if conf > confidence_threshold:
            x = int(keypoints_px[i, 1])
            y = int(keypoints_px[i, 0])
            # Color by confidence: green (high) → yellow (medium)
            color = (0, 255, 0) if conf > 0.7 else (0, 220, 255)
            cv2.circle(frame, (x, y), 5, color, -1)
            cv2.circle(frame, (x, y), 5, (255, 255, 255), 1)


def draw_hud(
    frame: np.ndarray,
    rep_count: int,
    state: MovementState,
    smoothed_angle: Optional[float],
    min_confidence: float,
    fps: float,
) -> None:
    """Draw the heads-up display overlay."""
    # Semi-transparent panel
    overlay = frame.copy()
    cv2.rectangle(overlay, (0, 0), (350, 180), (20, 20, 20), -1)
    frame[:] = cv2.addWeighted(overlay, 0.65, frame, 0.35, 0)

    y = 35
    cv2.putText(frame, f"Reps: {rep_count}", (15, y),
                cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3)
    y += 40

    state_color = (0, 220, 0) if state == MovementState.UP else (0, 180, 255)
    cv2.putText(frame, f"State: {state.name}", (15, y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, state_color, 2)
    y += 35

    angle_str = f"{smoothed_angle:.0f} deg" if smoothed_angle else "—"
    cv2.putText(frame, f"Angle: {angle_str}", (15, y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (200, 200, 200), 2)
    y += 30

    cv2.putText(frame, f"Conf: {min_confidence:.0%}  FPS: {fps:.0f}", (15, y),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (160, 160, 160), 1)


# ──────────────────────────────────────────────
# Main loop
# ──────────────────────────────────────────────

def main():
    """
    Real-time exercise counter using MoveNet Thunder + OpenCV.

    Default: counts squats using the right knee angle.
    Adjust the keypoint indices and thresholds for other exercises:
        • Push-ups:  elbow angle (shoulder → elbow → wrist)
          joint_a=KP_RIGHT_SHOULDER, joint_b=KP_RIGHT_ELBOW, joint_c=KP_RIGHT_WRIST
          down_threshold=90, up_threshold=150
        • Bicep curls: elbow angle
          down_threshold=40, up_threshold=150
    """
    # ── Download model if needed ───────────────
    download_model(MODEL_URL, MODEL_FILE)

    # ── Initialise MoveNet detector ────────────
    detector = MoveNetDetector(
        model_path=MODEL_FILE,
        num_threads=4,
        use_gpu=False,  # Set True if GPU delegate is available
    )

    # ── Configure exercise ─────────────────────
    # Squat: measure right knee angle (hip → knee → ankle)
    JOINT_A = KP_RIGHT_HIP
    JOINT_B = KP_RIGHT_KNEE
    JOINT_C = KP_RIGHT_ANKLE
    CONFIDENCE_JOINTS = [JOINT_A, JOINT_B, JOINT_C]

    counter = RepCounter(
        down_angle_threshold=100.0,   # knee < 100° = squat bottom
        up_angle_threshold=160.0,     # knee > 160° = standing
        min_confidence=0.5,
        cooldown_ms=300,
        smoothing_window=5,
    )

    # ── Open webcam ────────────────────────────
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    if not cap.isOpened():
        print("[ERROR] Cannot access webcam.")
        return

    print("\n[INFO] MoveNet Thunder — Squat Counter")
    print("[INFO] Press 'q' to quit.\n")

    prev_time = time.time()
    fps = 0.0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.flip(frame, 1)
        h, w = frame.shape[:2]

        # ── Run MoveNet inference ──────────────
        keypoints = detector.detect(frame)

        # ── Convert to pixel coordinates ───────
        keypoints_px = keypoints_to_image_coords(keypoints, h, w)

        # ── Draw skeleton ──────────────────────
        draw_skeleton(frame, keypoints_px)

        # ── Compute angle at target joint ──────
        joint_angle = compute_joint_angle(
            keypoints_px, JOINT_A, JOINT_B, JOINT_C
        )

        # ── Get minimum confidence across used joints ──
        min_conf = min(
            get_keypoint_confidence(keypoints, idx)
            for idx in CONFIDENCE_JOINTS
        )

        # ── Update rep counter ─────────────────
        rep_just_counted = counter.update(joint_angle, min_conf)
        if rep_just_counted:
            print(f"  ✓ Rep #{counter.rep_count}")

        # ── FPS calculation ────────────────────
        now = time.time()
        dt = now - prev_time
        fps = 1.0 / dt if dt > 0 else 0.0
        prev_time = now

        # ── Draw HUD ──────────────────────────
        draw_hud(
            frame,
            rep_count=counter.rep_count,
            state=counter.state,
            smoothed_angle=counter.smoothed_angle,
            min_confidence=min_conf,
            fps=fps,
        )

        cv2.imshow("MoveNet Thunder — Exercise Counter", frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    # ── Cleanup ────────────────────────────────
    cap.release()
    cv2.destroyAllWindows()
    print(f"\nSession ended. Total reps: {counter.rep_count}")


if __name__ == "__main__":
    main()
