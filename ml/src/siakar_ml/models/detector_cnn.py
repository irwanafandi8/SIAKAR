"""
detector_cnn.py — Detektor wajah biner sederhana di dalam oval panduan.

Sesuai ML_SPEC.md §3.3:
- Klasifikasi biner: wajah vs bukan-wajah pada potongan area oval
- Input: [64, 64, 3] RGB [-1, 1]
- Output: Skor probabilitas wajah [0, 1] (Sigmoid)
"""

from __future__ import annotations

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers


def build_detector_model(input_size: int = 64) -> keras.Model:
    """Membangun CNN biner kecil untuk mendeteksi keberadaan wajah di area oval."""
    inputs = keras.Input(shape=(input_size, input_size, 3), name="detector_input")

    x = layers.Conv2D(16, 3, strides=2, padding="same", use_bias=False)(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)

    x = layers.Conv2D(32, 3, strides=2, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)

    x = layers.Conv2D(64, 3, strides=2, padding="same", use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.ReLU()(x)

    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dense(32, activation="relu")(x)
    outputs = layers.Dense(1, activation="sigmoid", name="face_probability")(x)

    model = keras.Model(inputs=inputs, outputs=outputs, name="siakar_face_detector")
    return model
