"""
embedding_cnn.py — Arsitektur CNN Embedding dari nol untuk SIAKAR.

Sesuai ML_SPEC.md §3.1:
- Input: [112, 112, 3] RGB [-1, 1]
- Backbone: Blok konvolusi 3x3 + BatchNorm + ReLU bertahap
- GlobalAveragePooling2D
- Dense(128) -> L2-normalize -> Vektor embedding 128 dimensi
- Kepala latihan: Dense(num_classes, activation='softmax') dibuang saat ekspor TFLite.
"""

from __future__ import annotations

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers


def build_embedding_backbone(
    input_size: int = 112,
    embedding_dim: int = 128,
) -> keras.Model:
    """Membangun backbone ekstraksi embedding.
    Keluaran model ini adalah vektor embedding 128-D ternormalisasi L2.
    """
    inputs = keras.Input(shape=(input_size, input_size, 3), name="face_input")

    # Stem: Conv 3x3 stride 2 (112x112 -> 56x56)
    x = layers.Conv2D(32, 3, strides=2, padding="same", use_bias=False)(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)

    # Blok 1: 56x56 -> 28x28 (64 filter)
    x = layers.Conv2D(64, 3, strides=2, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)
    x = layers.Conv2D(64, 3, strides=1, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)

    # Blok 2: 28x28 -> 14x14 (128 filter)
    x = layers.Conv2D(128, 3, strides=2, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)
    x = layers.Conv2D(128, 3, strides=1, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)

    # Blok 3: 14x14 -> 7x7 (256 filter)
    x = layers.Conv2D(256, 3, strides=2, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)
    x = layers.Conv2D(256, 3, strides=1, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)

    # Global Average Pooling: 7x7x256 -> 256
    x = layers.GlobalAveragePooling2D()(x)

    # Lapisan Dense Embedding + L2 Normalization
    x = layers.Dense(embedding_dim, use_bias=False, name="embedding_dense")(x)
    embeddings = tf.math.l2_normalize(x, axis=1, name="l2_embedding")

    return keras.Model(inputs=inputs, outputs=embeddings, name="siakar_backbone")


def build_training_model(
    num_classes: int,
    input_size: int = 112,
    embedding_dim: int = 128,
) -> keras.Model:
    """Model lengkap untuk pelatihan (backbone + kepala klasifikasi softmax)."""
    backbone = build_embedding_backbone(input_size, embedding_dim)
    inputs = backbone.input
    embeddings = backbone.output

    # Kepala klasifikasi: Dense num_classes + softmax
    outputs = layers.Dense(
        num_classes,
        activation="softmax",
        name="classification_head",
    )(embeddings)

    model = keras.Model(inputs=inputs, outputs=outputs, name="siakar_training_model")
    return model
