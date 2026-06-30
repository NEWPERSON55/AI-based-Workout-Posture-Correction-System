"""
train_model.py
==============
Build, train, and evaluate an LSTM model for binary push-up form
classification (Correct vs Wrong).

Uses MoveNet Thunder features (preprocessed by data_preprocessing.py).

Prerequisites:
    Run data_preprocessing.py first to generate preprocessed_movenet.npz.

Usage:
    python train_model.py

Outputs:
    • pushup_lstm_model.h5   — saved Keras model
    • training_history.png   — accuracy & loss curves
"""

import os
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, callbacks

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(PROJECT_DIR, "preprocessed_movenet.npz")
MODEL_FILE = os.path.join(PROJECT_DIR, "pushup_lstm_model.h5")
HISTORY_PLOT = os.path.join(PROJECT_DIR, "training_history.png")

EPOCHS = 50
BATCH_SIZE = 16
VALIDATION_SPLIT = 0.2  # 80 / 20 stratified split
RANDOM_SEED = 42
LEARNING_RATE = 0.001


# ──────────────────────────────────────────────
# 1. Load preprocessed data
# ──────────────────────────────────────────────

def load_data():
    """Load X and y arrays from the .npz file produced by preprocessing."""
    if not os.path.exists(DATA_FILE):
        raise FileNotFoundError(
            f"Preprocessed data not found at {DATA_FILE}.\n"
            "Run  python data_preprocessing.py  first."
        )
    data = np.load(DATA_FILE)
    X, y = data["X"], data["y"]
    print(f"Loaded data  →  X.shape={X.shape}  y.shape={y.shape}")
    print(f"  Class 0 (Correct): {int(np.sum(y == 0))}")
    print(f"  Class 1 (Wrong)  : {int(np.sum(y == 1))}")
    return X, y


# ──────────────────────────────────────────────
# 2. Build LSTM model
# ──────────────────────────────────────────────

def build_model(timesteps: int, features: int) -> keras.Model:
    """
    Construct a two-layer Bidirectional LSTM network for binary classification.

    Architecture
    ------------
    Input (timesteps, features)
      → Bidirectional LSTM(128, return_sequences=True)   [outputs 256]
      → Dropout(0.3)
      → Bidirectional LSTM(64)                           [outputs 128]
      → Dropout(0.3)
      → Dense(32, relu)
      → Dropout(0.2)
      → Dense(1, sigmoid)
    """
    model = keras.Sequential([
        layers.Input(shape=(timesteps, features)),

        # First Bidirectional LSTM — returns full sequence for the next LSTM
        layers.Bidirectional(layers.LSTM(128, return_sequences=True)),
        layers.Dropout(0.3),

        # Second Bidirectional LSTM — returns only the final hidden state
        layers.Bidirectional(layers.LSTM(64, return_sequences=False)),
        layers.Dropout(0.3),

        # Fully-connected classifier head
        layers.Dense(32, activation="relu"),
        layers.Dropout(0.2),

        # Binary output
        layers.Dense(1, activation="sigmoid"),
    ])

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="binary_crossentropy",
        metrics=["accuracy"],
    )

    return model


# ──────────────────────────────────────────────
# 3. Plot training history
# ──────────────────────────────────────────────

def plot_history(history):
    """Save accuracy and loss curves to disk."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    # Accuracy
    ax1.plot(history.history["accuracy"], label="Train Accuracy")
    ax1.plot(history.history["val_accuracy"], label="Val Accuracy")
    ax1.set_title("Model Accuracy")
    ax1.set_xlabel("Epoch")
    ax1.set_ylabel("Accuracy")
    ax1.legend()
    ax1.grid(True)

    # Loss
    ax2.plot(history.history["loss"], label="Train Loss")
    ax2.plot(history.history["val_loss"], label="Val Loss")
    ax2.set_title("Model Loss")
    ax2.set_xlabel("Epoch")
    ax2.set_ylabel("Loss")
    ax2.legend()
    ax2.grid(True)

    plt.tight_layout()
    plt.savefig(HISTORY_PLOT, dpi=150)
    print(f"\nTraining curves saved to: {HISTORY_PLOT}")
    plt.show()


# ──────────────────────────────────────────────
# 4. Main training pipeline
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Push-up Form Detection — Model Training (MoveNet)")
    print("=" * 60)

    # ── Load data ──────────────────────────────
    X, y = load_data()
    timesteps, features = X.shape[1], X.shape[2]

    # ── Stratified train / validation split ────
    X_train, X_val, y_train, y_val = train_test_split(
        X, y,
        test_size=VALIDATION_SPLIT,
        random_state=RANDOM_SEED,
        stratify=y,
    )
    print(f"\nTrain set: {X_train.shape[0]} samples")
    print(f"Val   set: {X_val.shape[0]} samples")

    # ── Build model ────────────────────────────
    model = build_model(timesteps, features)
    model.summary()

    # ── Callbacks ──────────────────────────────
    early_stop = callbacks.EarlyStopping(
        monitor="val_loss",
        patience=10,
        restore_best_weights=True,
        verbose=1,
    )

    reduce_lr = callbacks.ReduceLROnPlateau(
        monitor="val_loss",
        factor=0.5,
        patience=5,
        min_lr=1e-6,
        verbose=1,
    )

    # ── Train ──────────────────────────────────
    print("\nStarting training …\n")
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=[early_stop, reduce_lr],
        verbose=1,
    )

    # ── Evaluate ───────────────────────────────
    val_loss, val_acc = model.evaluate(X_val, y_val, verbose=0)
    print(f"\nValidation Loss     : {val_loss:.4f}")
    print(f"Validation Accuracy : {val_acc:.4f}")

    # Classification report
    y_pred = (model.predict(X_val) > 0.5).astype(int).flatten()
    print("\nClassification Report:")
    print(classification_report(
        y_val, y_pred,
        target_names=["Correct", "Wrong"],
    ))
    print("Confusion Matrix:")
    print(confusion_matrix(y_val, y_pred))

    # ── Save model ─────────────────────────────
    model.save(MODEL_FILE)
    print(f"\nModel saved to: {MODEL_FILE}")

    # ── Plot ───────────────────────────────────
    plot_history(history)

    print("\n" + "=" * 60)
    print("  Training Complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()
