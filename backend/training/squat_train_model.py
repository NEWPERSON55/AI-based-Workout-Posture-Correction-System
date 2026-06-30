"""
squat_train_model.py
====================
Build, train, and evaluate an LSTM model for binary squat form
classification using the train_key_points.pickle dataset.

Classes (2 — binary):
    0 - Correct  (original class_label_index 6 = "good")
    1 - Wrong    (all other classes: bad_back_round, bad_back_warp,
                  bad_head, bad_innner_thigh, bad_shallow, bad_toe)

Features used:
    normalized_key_points  (51)  — 17 keypoints × 3 coords, normalized
    normalized_distance_matrix (136) — pairwise distances, normalized
    Total: 187 features per frame

Prerequisites:
    pip install tensorflow numpy scikit-learn matplotlib pandas

Usage:
    python squat_train_model.py

Outputs:
    squat_lstm_model.h5        — Trained Keras model
    squat_lstm_best_model.h5   — Best checkpoint (lowest val_loss)
    squat_training_history.png — Accuracy / loss curves
"""

import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import classification_report, confusion_matrix
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, regularizers

# ──────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
PICKLE_FILE = os.path.join(PROJECT_DIR, "train_key_points.pickle")
MODEL_FILE = os.path.join(PROJECT_DIR, "squat_lstm_model.h5")
BEST_MODEL_FILE = os.path.join(PROJECT_DIR, "squat_lstm_best_model.h5")
HISTORY_PLOT = os.path.join(PROJECT_DIR, "squat_training_history.png")

SEQUENCE_LENGTH = 30      # frames per sequence
STRIDE = 15               # sliding window stride
EPOCHS = 80
BATCH_SIZE = 64
VALIDATION_SPLIT = 0.2
RANDOM_SEED = 42
LEARNING_RATE = 0.0005
NUM_CLASSES = 2

CLASS_NAMES = [
    "Correct",   # 0 — original "good" (class_label_index 6)
    "Wrong",     # 1 — all "bad_*" classes merged
]

# Original 7-class label index for "good"
GOOD_CLASS_INDEX = 6


# ──────────────────────────────────────────────
# 1. Load & prepare data from pickle
# ──────────────────────────────────────────────

def load_and_prepare_data():
    """
    Load train_key_points.pickle and create LSTM-ready sequences.

    For each video file, frames are sorted by frame_number, features
    are extracted (normalized_key_points + normalized_distance_matrix),
    and sliding-window sequences are created.

    Original 7 classes are remapped to binary:
        class_label_index == 6 ("good")  →  0 (Correct)
        all other class_label_index       →  1 (Wrong)

    Returns
    -------
    X : np.ndarray (N, SEQUENCE_LENGTH, 187)
    y : np.ndarray (N,) — binary labels (0=Correct, 1=Wrong)
    """
    print(f"[INFO] Loading pickle data from {PICKLE_FILE} ...")
    if not os.path.exists(PICKLE_FILE):
        raise FileNotFoundError(
            f"Dataset not found at {PICKLE_FILE}.\n"
            f"Place train_key_points.pickle in the project directory."
        )

    df = pd.read_pickle(PICKLE_FILE)
    print(f"[INFO] Loaded DataFrame: {df.shape[0]} rows, {df.shape[1]} columns")
    print(f"[INFO] Original class distribution (7 classes):")
    for label in sorted(df['class_label'].unique()):
        count = (df['class_label'] == label).sum()
        print(f"       {label}: {count}")

    all_sequences = []
    all_labels = []

    # Group by video file
    grouped = df.groupby('file')
    total_files = len(grouped)
    print(f"\n[INFO] Processing {total_files} video files into sequences ...")

    for i, (file_name, group) in enumerate(grouped):
        # Sort by frame number
        group = group.sort_values('frame_number')

        # Extract features: normalized_key_points (51) + normalized_distance_matrix (136) = 187
        features = []
        for _, row in group.iterrows():
            nkp = np.array(row['normalized_key_points']).flatten()
            ndm = np.array(row['normalized_distance_matrix']).flatten()
            feat = np.concatenate([nkp, ndm])
            features.append(feat)

        features = np.array(features, dtype=np.float32)

        # Get the original 7-class label and remap to binary
        original_label = group['class_label_index'].iloc[0]
        # good (6) → 0 (Correct),  all bad_* → 1 (Wrong)
        binary_label = 0 if original_label == GOOD_CLASS_INDEX else 1

        # Create sliding window sequences
        n_frames = len(features)
        if n_frames < SEQUENCE_LENGTH:
            # Pad with last frame if too short
            padded = np.zeros((SEQUENCE_LENGTH, features.shape[1]), dtype=np.float32)
            padded[:n_frames] = features
            padded[n_frames:] = features[-1]
            all_sequences.append(padded)
            all_labels.append(binary_label)
        else:
            for start in range(0, n_frames - SEQUENCE_LENGTH + 1, STRIDE):
                seq = features[start:start + SEQUENCE_LENGTH]
                all_sequences.append(seq)
                all_labels.append(binary_label)

        if (i + 1) % 200 == 0 or (i + 1) == total_files:
            print(f"       Processed {i + 1}/{total_files} files ...")

    X = np.array(all_sequences, dtype=np.float32)
    y = np.array(all_labels, dtype=np.int32)

    print(f"\n[INFO] Sequences created: X={X.shape}  y={y.shape}")
    print(f"       Correct (0): {int(np.sum(y == 0))}")
    print(f"       Wrong   (1): {int(np.sum(y == 1))}")

    return X, y


# ──────────────────────────────────────────────
# 2. Data Augmentation (light noise)
# ──────────────────────────────────────────────

def augment_sequences(X, y, noise_std=0.005):
    """
    Light Gaussian noise augmentation — 2× total data.
    """
    noisy = X + np.random.normal(0, noise_std, X.shape).astype(np.float32)
    return np.concatenate([X, noisy]), np.concatenate([y, y])


# ──────────────────────────────────────────────
# 3. Build LSTM model (binary)
# ──────────────────────────────────────────────

def build_model(timesteps: int, features: int):
    """
    3-layer BiLSTM for binary squat form classification.

    Architecture
    ------------
    Input (timesteps, features)
      → BatchNormalization
      → Bidirectional LSTM(128, return_sequences=True)
      → BatchNormalization + Dropout(0.3)
      → Bidirectional LSTM(64, return_sequences=True)
      → BatchNormalization + Dropout(0.3)
      → Bidirectional LSTM(32)
      → BatchNormalization + Dropout(0.3)
      → Dense(64, relu, L2=0.001) + Dropout(0.3)
      → Dense(1, sigmoid)   — output ≤0.5 = Correct, >0.5 = Wrong
    """
    model = keras.Sequential([
        layers.Input(shape=(timesteps, features)),

        layers.BatchNormalization(),

        # LSTM layer 1
        layers.Bidirectional(
            layers.LSTM(128, return_sequences=True)
        ),
        layers.BatchNormalization(),
        layers.Dropout(0.3),

        # LSTM layer 2
        layers.Bidirectional(
            layers.LSTM(64, return_sequences=True)
        ),
        layers.BatchNormalization(),
        layers.Dropout(0.3),

        # LSTM layer 3
        layers.Bidirectional(
            layers.LSTM(32)
        ),
        layers.BatchNormalization(),
        layers.Dropout(0.3),

        # Dense classifier
        layers.Dense(64, activation="relu",
                     kernel_regularizer=regularizers.l2(0.001)),
        layers.Dropout(0.3),

        # Binary output: sigmoid (0=Correct, 1=Wrong)
        layers.Dense(1, activation="sigmoid"),
    ])

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="binary_crossentropy",
        metrics=["accuracy"],
    )

    return model


# ──────────────────────────────────────────────
# 4. Plot training history
# ──────────────────────────────────────────────

def plot_history(history):
    """Save accuracy and loss curves to disk."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    ax1.plot(history.history["accuracy"], label="Train")
    ax1.plot(history.history["val_accuracy"], label="Val")
    ax1.set_title("Squat Model — Accuracy")
    ax1.set_xlabel("Epoch")
    ax1.set_ylabel("Accuracy")
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    ax2.plot(history.history["loss"], label="Train")
    ax2.plot(history.history["val_loss"], label="Val")
    ax2.set_title("Squat Model — Loss")
    ax2.set_xlabel("Epoch")
    ax2.set_ylabel("Loss")
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(HISTORY_PLOT, dpi=150)
    plt.close()
    print(f"[INFO] Training history plot saved to {HISTORY_PLOT}")


# ──────────────────────────────────────────────
# 5. Main training pipeline
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Squat LSTM Model Training (Pickle Dataset)")
    print("=" * 60)

    # ── Load & prepare data ───────────────────
    X, y = load_and_prepare_data()

    # ── Balance dataset (downsample Wrong to match Correct) ──
    np.random.seed(RANDOM_SEED)
    idx_correct = np.where(y == 0)[0]
    idx_wrong   = np.where(y == 1)[0]
    n_correct = len(idx_correct)
    n_wrong   = len(idx_wrong)
    print(f"\n[INFO] Before balancing: Correct={n_correct}, Wrong={n_wrong}")

    if n_wrong > n_correct:
        idx_wrong_downsampled = np.random.choice(
            idx_wrong, size=n_correct, replace=False
        )
        balanced_idx = np.sort(np.concatenate([idx_correct, idx_wrong_downsampled]))
        X = X[balanced_idx]
        y = y[balanced_idx]
        print(f"[INFO] After balancing:  Correct={int(np.sum(y == 0))}, Wrong={int(np.sum(y == 1))}")
    else:
        print("[INFO] Dataset already balanced, no downsampling needed.")

    # ── Train / Val split (stratified) ─────────
    X_train, X_val, y_train, y_val = train_test_split(
        X, y,
        test_size=VALIDATION_SPLIT,
        random_state=RANDOM_SEED,
        stratify=y,
    )
    print(f"\n[INFO] Split: train={X_train.shape[0]}  val={X_val.shape[0]}")

    # ── Augment training data (2× noise) ──────
    np.random.seed(RANDOM_SEED)
    X_train_aug, y_train_aug = augment_sequences(X_train, y_train)
    print(f"[INFO] After augmentation: train={X_train_aug.shape[0]}  (2× original)")

    # ── Shuffle ────────────────────────────────
    shuffle_idx = np.random.permutation(len(X_train_aug))
    X_train_aug = X_train_aug[shuffle_idx]
    y_train_aug = y_train_aug[shuffle_idx]

    # ── Class weights ──────────────────────────
    classes = np.unique(y_train_aug)
    weights = compute_class_weight("balanced", classes=classes, y=y_train_aug)
    class_weights = dict(zip(classes.astype(int), weights))
    print(f"[INFO] Class weights: {class_weights}")

    # ── Build model ────────────────────────────
    timesteps, features = X_train_aug.shape[1], X_train_aug.shape[2]
    model = build_model(timesteps, features)
    model.summary()

    # ── Callbacks ──────────────────────────────
    callbacks = [
        # Save best model checkpoint every epoch (by val_loss)
        keras.callbacks.ModelCheckpoint(
            filepath=BEST_MODEL_FILE,
            monitor="val_loss",
            save_best_only=True,
            save_weights_only=False,
            mode="min",
            verbose=1,
        ),
        # Early stopping — halt training when val_loss stops improving
        keras.callbacks.EarlyStopping(
            monitor="val_loss",
            patience=10,
            restore_best_weights=True,
            verbose=1,
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=5,
            min_lr=1e-6,
            verbose=1,
        ),
    ]

    # ── Train ──────────────────────────────────
    print(f"\n{'─' * 60}")
    print(f"  Training for up to {EPOCHS} epochs (early stopping enabled)")
    print(f"{'─' * 60}\n")

    history = model.fit(
        X_train_aug, y_train_aug,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        class_weight=class_weights,
        callbacks=callbacks,
        verbose=1,
    )

    # ── Evaluate ───────────────────────────────
    val_loss, val_acc = model.evaluate(X_val, y_val, verbose=0)
    print(f"\n[RESULT] Val Loss: {val_loss:.4f}  |  Val Accuracy: {val_acc:.4f}")

    # Classification report (binary)
    y_pred_prob = model.predict(X_val).flatten()
    y_pred = (y_pred_prob > 0.5).astype(int)
    print("\nClassification Report:")
    print(classification_report(
        y_val, y_pred,
        target_names=CLASS_NAMES,
    ))
    print("Confusion Matrix:")
    print(confusion_matrix(y_val, y_pred))

    # ── Save ───────────────────────────────────
    model.save(MODEL_FILE)
    print(f"[INFO] Final model saved to {MODEL_FILE}")
    print(f"[INFO] Best model (lowest val_loss) saved to {BEST_MODEL_FILE}")

    plot_history(history)

    print(f"\n{'=' * 60}")
    print(f"  Training complete ✅")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
