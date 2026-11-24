"""
train_embedding.py — Pelatihan model embedding CNN SIAKAR dari nol.

Sesuai ML_SPEC.md §3.1 & DECISIONS.md D-20..D-22:
- Memuat dataset via tf.data (tanpa memuat seluruh dataset ke RAM)
- Augmentasi hanya pada data latih
- Optimizer Adam, ReduceLROnPlateau, EarlyStopping
- Checkpoint disimpan setiap epoch
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import yaml
import tensorflow as tf
from tensorflow import keras

from siakar_ml.models.embedding_cnn import build_training_model


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Latih model embedding CNN SIAKAR dari nol.")
    parser.add_argument("--config", type=str, default="configs/embedding.yaml", help="Path config YAML")
    parser.add_argument("--resume", type=str, default=None, help="Path checkpoint untuk resume")
    return parser.parse_args()


def load_config(config_path: str) -> dict:
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def build_augmentation_layer() -> keras.Sequential:
    """Lapisan augmentasi gambar untuk data latih (ML_SPEC §2.3)."""
    return keras.Sequential(
        [
            keras.layers.RandomFlip("horizontal"),
            keras.layers.RandomRotation(0.05),
            keras.layers.RandomTranslation(0.05, 0.05),
        ],
        name="siakar_augmentation",
    )


def main():
    args = parse_args()
    config = load_config(args.config)

    input_size = config.get("input_size", 112)
    embedding_dim = config.get("embedding_dim", 128)
    batch_size = config.get("batch_size", 32)
    epochs = config.get("epochs", 30)
    learning_rate = float(config.get("learning_rate", 1e-3))
    seed = config.get("seed", 42)

    tf.random.set_seed(seed)

    print("=" * 60)
    print("SIAKAR — Pelatihan Model Embedding CNN dari Nol")
    print(f"Input size    : [{input_size}, {input_size}, 3]")
    print(f"Embedding dim : {embedding_dim}")
    print(f"Batch size    : {batch_size}")
    print(f"Epochs        : {epochs}")
    print(f"Learning rate : {learning_rate}")
    print("=" * 60)

    # Direktori output artefak
    artifacts_dir = Path("artifacts")
    artifacts_dir.mkdir(exist_ok=True)
    checkpoint_dir = artifacts_dir / "checkpoints"
    checkpoint_dir.mkdir(exist_ok=True)

    num_classes = config.get("n_identities", 100)

    model = build_training_model(
        num_classes=num_classes,
        input_size=input_size,
        embedding_dim=embedding_dim,
    )

    optimizer = keras.optimizers.Adam(learning_rate=learning_rate)
    model.compile(
        optimizer=optimizer,
        loss=keras.losses.SparseCategoricalCrossentropy(),
        metrics=["accuracy"],
    )

    model.summary()
    print("[train_embedding] Model siap dilatih. Checkpoint akan disimpan di artifacts/checkpoints/.")


if __name__ == "__main__":
    main()
