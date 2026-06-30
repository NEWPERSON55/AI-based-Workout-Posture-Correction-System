"""
data_preprocessing.py
=====================
Extract pose landmarks from push-up videos using MoveNet Thunder (TFLite),
normalize coordinates, compute joint angles, and create fixed-length
sequences for LSTM training.

╔══════════════════════════════════════════════════════════════════╗
║  MIGRATED FROM MEDIAPIPE TO MOVENET THUNDER (TFLite)           ║
║                                                                ║
║  MoveNet outputs 17 keypoints (y, x, confidence).              ║
║  These are mapped into MediaPipe's 33-landmark format          ║
║  (x, y, z, visibility × 33 = 132 values) so the downstream    ║
║  LSTM model, PushUpValidator, and realtime_detection.py all    ║
║  use the same feature format without changes.                  ║
║                                                                ║
║  MoveNet is 2D-only (no z-depth), so z=0 for all landmarks.   ║
║  Unmapped MediaPipe slots (face, hands, feet) are zeroed.      ║
╚══════════════════════════════════════════════════════════════════╝

Usage:
    python data_preprocessing.py

Outputs:
    preprocessed_movenet.npz  — X (sequences) and y (labels)
"""

import os
import cv2
import numpy as np
import urllib.request

# ──────────────────────────────────────────────
# TFLite interpreter
# ──────────────────────────────────────────────
try:
    import tflite_runtime.interpreter as tflite
    TFLiteInterpreter = tflite.Interpreter
except ImportError:
    import tensorflow as tf
    TFLiteInterpreter = tf.lite.Interpreter


# ──────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────

DATASET_DIR = os.path.dirname(os.path.abspath(__file__))
CORRECT_DIR = os.path.join(DATASET_DIR, "Correct sequence")
WRONG_DIR = os.path.join(DATASET_DIR, "Wrong sequence")

SEQUENCE_LENGTH = 30
STRIDE = 15
OUTPUT_FILE = os.path.join(DATASET_DIR, "preprocessed_movenet.npz")

# MoveNet Thunder model
MOVENET_MODEL_FILE = os.path.join(DATASET_DIR, "movenet_thunder.tflite")
MOVENET_MODEL_URL = (
    "https://tfhub.dev/google/lite-model/"
    "movenet/singlepose/thunder/tflite/float16/4?lite-format=tflite"
)

# Output format — same as MediaPipe for compatibility
NUM_LANDMARKS = 33
FEATURES_PER_LANDMARK = 4  # x, y, z, visibility
LANDMARK_FEATURES = NUM_LANDMARKS * FEATURES_PER_LANDMARK  # 132
NUM_ANGLES = 6  # left/right elbow, shoulder, knee
TOTAL_FEATURES = LANDMARK_FEATURES + NUM_ANGLES  # 138


# ──────────────────────────────────────────────
# MoveNet → MediaPipe keypoint mapping
# ──────────────────────────────────────────────
# Maps each MoveNet index (0–16) to the corresponding MediaPipe
# landmark index (0–32). All 12 body joints needed for push-up
# analysis are covered:
#   shoulders (11,12), elbows (13,14), wrists (15,16),
#   hips (23,24), knees (25,26), ankles (27,28)

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


# ──────────────────────────────────────────────
# MoveNet model loader
# ──────────────────────────────────────────────

def download_model(url: str, dest: str) -> None:
    """Download the MoveNet Thunder model if not already cached."""
    if os.path.exists(dest):
        return
    print(f"[INFO] Downloading MoveNet Thunder model to {dest} ...")
    urllib.request.urlretrieve(url, dest)
    print(f"[INFO] Download complete ({os.path.getsize(dest) / 1e6:.1f} MB).")


class MoveNetDetector:
    """Lightweight wrapper around the MoveNet Thunder TFLite model."""

    def __init__(self, model_path: str, num_threads: int = 4):
        self._interpreter = TFLiteInterpreter(
            model_path=model_path, num_threads=num_threads
        )
        self._interpreter.allocate_tensors()

        self._input_details = self._interpreter.get_input_details()
        self._output_details = self._interpreter.get_output_details()

        self._input_h = self._input_details[0]["shape"][1]
        self._input_w = self._input_details[0]["shape"][2]
        self._input_dtype = self._input_details[0]["dtype"]

    def detect(self, frame: np.ndarray) -> np.ndarray:
        """
        Run inference on a BGR frame.
        Returns (17, 3) array: [y_norm, x_norm, confidence].
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

def movenet_to_mediapipe_format(raw_kp: np.ndarray) -> np.ndarray:
    """
    Convert MoveNet (17, 3) keypoints to MediaPipe-compatible (132,) flat array.

    MoveNet format: [y_norm, x_norm, confidence] per keypoint
    MediaPipe format: [x, y, z, visibility] × 33 landmarks (stride-4)

    Unmapped MediaPipe landmarks are set to (0, 0, 0, 0).
    z is always 0 since MoveNet is 2D-only.
    """
    coords = np.zeros(LANDMARK_FEATURES, dtype=np.float32)

    for mn_idx, mp_idx in MOVENET_TO_MEDIAPIPE.items():
        y_norm, x_norm, conf = raw_kp[mn_idx]
        offset = mp_idx * FEATURES_PER_LANDMARK
        coords[offset]     = x_norm   # x (swapped from MoveNet's y,x order)
        coords[offset + 1] = y_norm   # y
        coords[offset + 2] = 0.0      # z (MoveNet is 2D)
        coords[offset + 3] = conf     # visibility / confidence

    return coords


# ──────────────────────────────────────────────
# Extract Landmarks from Video
# ──────────────────────────────────────────────

def extract_landmarks_from_video(video_path: str, detector: MoveNetDetector):
    """
    Process a video file and extract per-frame landmarks
    in MediaPipe-compatible format.

    Returns
    -------
    frames : np.ndarray (N, 132) — one row per frame with valid detection.
    """
    cap = cv2.VideoCapture(video_path)
    frames = []

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        raw_kp = detector.detect(frame)  # (17, 3)

        # Check that core body joints are confident enough
        core_joints = [5, 6, 7, 8, 9, 10, 11, 12]  # shoulders, elbows, wrists, hips
        core_conf = np.mean([raw_kp[i, 2] for i in core_joints])
        if core_conf < 0.3:
            continue  # skip low-confidence frames

        coords = movenet_to_mediapipe_format(raw_kp)
        frames.append(coords)

    cap.release()

    if len(frames) == 0:
        return np.empty((0, LANDMARK_FEATURES))

    return np.array(frames, dtype=np.float32)


# ──────────────────────────────────────────────
# Normalize (same logic as before — works on MediaPipe format)
# ──────────────────────────────────────────────

def normalize_landmarks(frames):
    """
    Normalize landmarks relative to hip centre and torso length.
    Operates on the MediaPipe-compatible (N, 132) format.
    """
    normalized = frames.copy()

    for i in range(len(normalized)):
        row = normalized[i]

        # Hip centre: landmarks 23, 24 (stride 4)
        lh, rh = 23 * 4, 24 * 4
        hip_center = np.array([
            (row[lh] + row[rh]) / 2,
            (row[lh + 1] + row[rh + 1]) / 2,
            (row[lh + 2] + row[rh + 2]) / 2
        ])

        # Shoulder centre: landmarks 11, 12 (stride 4)
        ls, rs = 11 * 4, 12 * 4
        shoulder_center = np.array([
            (row[ls] + row[rs]) / 2,
            (row[ls + 1] + row[rs + 1]) / 2,
            (row[ls + 2] + row[rs + 2]) / 2
        ])

        torso = np.linalg.norm(shoulder_center - hip_center)
        if torso < 1e-6:
            torso = 1.0

        for j in range(NUM_LANDMARKS):
            idx = j * 4
            row[idx]     = (row[idx]     - hip_center[0]) / torso
            row[idx + 1] = (row[idx + 1] - hip_center[1]) / torso
            row[idx + 2] = (row[idx + 2] - hip_center[2]) / torso
            # visibility is left unchanged

        normalized[i] = row

    return normalized


# ──────────────────────────────────────────────
# Joint Angle Computation (unchanged)
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
    Compute 6 joint angles from a single frame's landmarks.

    Angles (all in degrees, then scaled to [0, 1]):
        0  left  elbow   — shoulder(11) · elbow(13) · wrist(15)
        1  right elbow   — shoulder(12) · elbow(14) · wrist(16)
        2  left  shoulder — elbow(13) · shoulder(11) · hip(23)
        3  right shoulder — elbow(14) · shoulder(12) · hip(24)
        4  left  knee     — hip(23) · knee(25) · ankle(27)
        5  right knee     — hip(24) · knee(26) · ankle(28)
    """
    angles = np.array([
        _angle_3d(_get_xyz(row, 11), _get_xyz(row, 13), _get_xyz(row, 15)),  # L elbow
        _angle_3d(_get_xyz(row, 12), _get_xyz(row, 14), _get_xyz(row, 16)),  # R elbow
        _angle_3d(_get_xyz(row, 13), _get_xyz(row, 11), _get_xyz(row, 23)),  # L shoulder
        _angle_3d(_get_xyz(row, 14), _get_xyz(row, 12), _get_xyz(row, 24)),  # R shoulder
        _angle_3d(_get_xyz(row, 23), _get_xyz(row, 25), _get_xyz(row, 27)),  # L knee
        _angle_3d(_get_xyz(row, 24), _get_xyz(row, 26), _get_xyz(row, 28)),  # R knee
    ], dtype=np.float32) / 180.0  # scale to [0, 1]

    return angles


def augment_with_angles(frames):
    """
    Append 6 joint angles to each frame's feature vector.
    Input:  (N, 132)  →  Output: (N, 138)
    """
    augmented = []
    for row in frames:
        angles = compute_joint_angles(row)
        augmented.append(np.concatenate([row, angles]))
    return np.array(augmented, dtype=np.float32)


# ──────────────────────────────────────────────
# Create Sequences (unchanged)
# ──────────────────────────────────────────────

def create_sequences(frames):
    """Create fixed-length sliding-window sequences for LSTM input."""
    sequences = []
    n = len(frames)

    if n < SEQUENCE_LENGTH:
        padded = np.zeros((SEQUENCE_LENGTH, TOTAL_FEATURES))
        padded[:n] = frames
        padded[n:] = frames[-1]
        sequences.append(padded)
    else:
        for start in range(0, n - SEQUENCE_LENGTH + 1, STRIDE):
            sequences.append(frames[start:start + SEQUENCE_LENGTH])

    return np.array(sequences, dtype=np.float32)


# ──────────────────────────────────────────────
# Process Folder
# ──────────────────────────────────────────────

def process_folder(folder_path, label, detector):
    """Process all .mp4 videos in a folder and return (X, y)."""
    all_sequences = []
    videos = [f for f in os.listdir(folder_path) if f.endswith(".mp4")]
    total = len(videos)

    for i, vid in enumerate(videos, 1):
        print(f"  [{i}/{total}] Processing {vid}")
        raw = extract_landmarks_from_video(
            os.path.join(folder_path, vid), detector
        )
        if len(raw) == 0:
            print(f"    ⚠ No valid frames detected, skipping.")
            continue

        norm = normalize_landmarks(raw)
        aug = augment_with_angles(norm)
        seqs = create_sequences(aug)
        all_sequences.append(seqs)
        print(f"    ✓ {len(raw)} frames → {len(seqs)} sequences")

    if len(all_sequences) == 0:
        return np.empty((0, SEQUENCE_LENGTH, TOTAL_FEATURES)), np.array([])

    X = np.concatenate(all_sequences)
    y = np.full(X.shape[0], label)

    return X, y


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Push-up Data Preprocessing (MoveNet Thunder)")
    print("=" * 60)

    # ── Download / load MoveNet model ──────────
    download_model(MOVENET_MODEL_URL, MOVENET_MODEL_FILE)
    detector = MoveNetDetector(MOVENET_MODEL_FILE, num_threads=4)
    print(f"[INFO] MoveNet Thunder loaded.\n")

    # ── Process videos ─────────────────────────
    print("Processing CORRECT videos:")
    Xc, yc = process_folder(CORRECT_DIR, 0, detector)

    print("\nProcessing WRONG videos:")
    Xw, yw = process_folder(WRONG_DIR, 1, detector)

    # ── Save ───────────────────────────────────
    X = np.concatenate([Xc, Xw])
    y = np.concatenate([yc, yw])

    np.savez(OUTPUT_FILE, X=X, y=y)

    print(f"\n{'=' * 60}")
    print(f"  Done ✅")
    print(f"  Output: {OUTPUT_FILE}")
    print(f"  Shape:  X={X.shape}  y={y.shape}")
    print(f"  Class 0 (Correct): {int(np.sum(y == 0))}")
    print(f"  Class 1 (Wrong)  : {int(np.sum(y == 1))}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
