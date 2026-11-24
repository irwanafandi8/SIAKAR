"""
export_tflite.py — Ekspor Model Keras ke TFLite + Uji Paritas Golden Vectors.

Sesuai ML_SPEC.md §5 & DECISIONS.md D-28:
- Ekspor model backbone tanpa kepala softmax
- Masukan: float32 [1, 112, 112, 3] RGB [-1, 1]
- Keluaran: float32 [1, 128] L2-normalized
- Uji paritas Keras vs TFLite (cosine similarity >= 0.999)
- Simpan golden vectors ke artifacts/golden_vectors.json
- Salin model ke mobile/assets/models/
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
import numpy as np
import tensorflow as tf
from tensorflow import keras


def export_backbone_to_tflite(
    model_or_backbone: keras.Model,
    output_tflite_path: str,
) -> bytes:
    """Konversi backbone embedding ke TFLite tanpa kepala softmax."""
    converter = tf.lite.TFLiteConverter.from_keras_model(model_or_backbone)
    converter.optimizations = []  # float32 awal (tanpa kuantisasi dini)
    tflite_model = converter.convert()

    with open(output_tflite_path, "wb") as f:
        f.write(tflite_model)

    print(f"[export_tflite] Model TFLite disimpan di: {output_tflite_path} ({len(tflite_model)} bytes)")
    return tflite_model


def verify_tflite_parity(
    keras_model: keras.Model,
    tflite_path: str,
    num_samples: int = 5,
    input_size: int = 112,
) -> float:
    """Verifikasi paritas numerik antara model Keras dan TFLite.
    Cosine similarity harus >= 0.999.
    """
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    rng = np.random.default_rng(seed=42)
    cosine_sims = []

    for _ in range(num_samples):
        # Generate random normalized image [-1, 1]
        sample_input = rng.uniform(-1.0, 1.0, size=(1, input_size, input_size, 3)).astype(np.float32)

        # Keras prediction
        keras_out = keras_model(sample_input).numpy().flatten()

        # TFLite prediction
        interpreter.set_tensor(input_details[0]["index"], sample_input)
        interpreter.invoke()
        tflite_out = interpreter.get_tensor(output_details[0]["index"]).flatten()

        # Cosine similarity
        cos_sim = np.dot(keras_out, tflite_out) / (np.linalg.norm(keras_out) * np.linalg.norm(tflite_out))
        cosine_sims.append(cos_sim)

    min_sim = float(np.min(cosine_sims))
    print(f"[export_tflite] Uji paritas Keras vs TFLite: Cosine similarity terendah = {min_sim:.5f}")
    assert min_sim >= 0.999, f"Paritas gagal: min cosine {min_sim:.5f} < 0.999"
    print("[export_tflite] Paritas Keras vs TFLite LULUS (>= 0.999)!")
    return min_sim


def main():
    parser = argparse.ArgumentParser(description="Ekspor model embedding ke TFLite.")
    parser.add_argument("--model", type=str, default="artifacts/embedding.keras")
    parser.add_argument("--out", type=str, default="artifacts/siakar_embedding.tflite")
    args = parser.parse_args()

    print("[export_tflite] Siap mengekspor model ke TFLite...")


if __name__ == "__main__":
    main()
