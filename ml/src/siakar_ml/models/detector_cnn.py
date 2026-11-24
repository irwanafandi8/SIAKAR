"""
detector_cnn.py — Arsitektur CNN Detektor Wajah + Regresi Bounding Box dari nol (ML7 / T-205).

Sesuai ML_SPEC.md §3.3 & §3.4:
- Dibangun 100% dari nol tanpa bobot pretrained, tanpa ML Kit / Haar / DNN OpenCV.
- Tujuan: memvalidasi keberadaan wajah di dalam area oval panduan serta mengestimasi kotak
  wajah ternormalisasi [cx, cy, w, h] di dalam potongan oval (mendukung liveness L1 §3.4).
- Kontrak Input : float32 [B, input_size, input_size, 3] RGB dalam [-1, 1] (default 64x64).
- Kontrak Output:
  - include_bbox=True (default): float32 [B, 5] dalam [0, 1] -> [face_score, cx, cy, w, h]
  - include_bbox=False         : float32 [B, 1] dalam [0, 1] -> [face_score]
- Hanya memakai operasi standar TFLITE_BUILTINS (Conv2D, BatchNormalization, ReLU,
  GlobalAveragePooling2D, Dense + Sigmoid).
"""

from __future__ import annotations

from typing import Any, Dict, Sequence, Tuple

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers


@keras.utils.register_keras_serializable(package="siakar_ml")
class DetectorMultiTaskLoss(keras.losses.Loss):
    """Loss gabungan: Binary Cross-Entropy (skor wajah) + Masked Smooth-L1/Huber (kotak [cx, cy, w, h]).

    Pada sampel negatif (y_true[:, 0] == 0), regresi bounding box dikalikan masker 0 sehingga
    tidak merusak prediksi koordinat kotak wajah.
    """

    def __init__(
        self,
        bbox_weight: float = 2.0,
        delta: float = 0.10,
        name: str = "detector_multitask_loss",
        **kwargs: Any,
    ) -> None:
        super().__init__(name=name, **kwargs)
        self.bbox_weight = float(bbox_weight)
        self.delta = float(delta)

    def call(self, y_true: tf.Tensor, y_pred: tf.Tensor) -> tf.Tensor:
        yt = tf.cast(y_true, tf.float32)
        yp = tf.cast(y_pred, tf.float32)

        face_true = yt[:, 0:1]
        face_pred = tf.clip_by_value(yp[:, 0:1], 1e-7, 1.0 - 1e-7)
        bce = -(
            face_true * tf.math.log(face_pred)
            + (1.0 - face_true) * tf.math.log(1.0 - face_pred)
        )
        bce_vec = tf.squeeze(bce, axis=-1)

        if yp.shape[-1] == 1:
            return bce_vec

        diff = tf.abs(yt[:, 1:5] - yp[:, 1:5])
        quadratic = tf.minimum(diff, self.delta)
        linear = diff - quadratic
        huber = 0.5 * tf.square(quadratic) + self.delta * linear
        bbox_per_sample = tf.reduce_mean(huber, axis=-1)

        pos_mask = tf.squeeze(face_true, axis=-1)
        return bce_vec + self.bbox_weight * pos_mask * bbox_per_sample

    def get_config(self) -> Dict[str, Any]:
        config = super().get_config()
        config.update({"bbox_weight": self.bbox_weight, "delta": self.delta})
        return config


@keras.utils.register_keras_serializable(package="siakar_ml")
class DetectorFaceAccuracy(keras.metrics.Metric):
    """Metrik akurasi biner khusus kanal ke-0 (face_score >= threshold)."""

    def __init__(self, threshold: float = 0.5, name: str = "face_acc", **kwargs: Any) -> None:
        super().__init__(name=name, **kwargs)
        self.threshold = float(threshold)
        self.correct = self.add_weight(name="correct", initializer="zeros")
        self.total = self.add_weight(name="total", initializer="zeros")

    def update_state(
        self,
        y_true: tf.Tensor,
        y_pred: tf.Tensor,
        sample_weight: tf.Tensor | None = None,
    ) -> None:
        yt = tf.cast(y_true[:, 0] >= 0.5, tf.float32)
        yp = tf.cast(y_pred[:, 0] >= self.threshold, tf.float32)
        matches = tf.cast(tf.equal(yt, yp), tf.float32)
        self.correct.assign_add(tf.reduce_sum(matches))
        self.total.assign_add(tf.cast(tf.size(matches), tf.float32))

    def result(self) -> tf.Tensor:
        return tf.math.divide_no_nan(self.correct, self.total)

    def reset_state(self) -> None:
        self.correct.assign(0.0)
        self.total.assign(0.0)

    def get_config(self) -> Dict[str, Any]:
        config = super().get_config()
        config.update({"threshold": self.threshold})
        return config


def build_detector_model(
    input_size: int = 64,
    filters: Sequence[int] = (32, 64, 128),
    dense_units: int = 64,
    include_bbox: bool = True,
    seed: int = 42,
) -> keras.Model:
    """Bangun CNN detektor wajah ringan dari nol pada potongan area oval.

    Args:
        input_size: Ukuran sisi potongan persegi (default 64 piksel).
        filters: Jumlah filter per tahap konvolusi stride-2.
        dense_units: Unit lapisan Dense sebelum kepala keluaran.
        include_bbox: Jika True, keluaran berukuran ``[B, 5]`` ``[face_score, cx, cy, w, h]``;
            jika False, keluaran berukuran ``[B, 1]`` ``[face_score]``.
        seed: Seed inisialisasi deterministik.
    """
    if input_size < 32:
        raise ValueError(f"input_size terlalu kecil ({input_size}); minimal 32.")

    inputs = keras.Input(shape=(input_size, input_size, 3), dtype=tf.float32, name="detector_input")
    x = inputs

    for idx, f in enumerate(filters):
        init_a = keras.initializers.HeNormal(seed=seed + idx * 10)
        init_b = keras.initializers.HeNormal(seed=seed + idx * 10 + 1)

        x = layers.Conv2D(
            int(f),
            kernel_size=3,
            strides=2,
            padding="same",
            use_bias=False,
            kernel_initializer=init_a,
            name=f"det_stage{idx}_conv1",
        )(x)
        x = layers.BatchNormalization(name=f"det_stage{idx}_bn1")(x)
        x = layers.ReLU(name=f"det_stage{idx}_relu1")(x)

        x = layers.Conv2D(
            int(f),
            kernel_size=3,
            strides=1,
            padding="same",
            use_bias=False,
            kernel_initializer=init_b,
            name=f"det_stage{idx}_conv2",
        )(x)
        x = layers.BatchNormalization(name=f"det_stage{idx}_bn2")(x)
        x = layers.ReLU(name=f"det_stage{idx}_relu2")(x)

    x = layers.GlobalAveragePooling2D(name="det_gap")(x)
    x = layers.Dense(
        int(dense_units),
        activation="relu",
        kernel_initializer=keras.initializers.HeNormal(seed=seed + 99),
        name="det_fc",
    )(x)

    out_dim = 5 if include_bbox else 1
    out_name = "detector_output" if include_bbox else "face_probability"
    outputs = layers.Dense(
        out_dim,
        activation="sigmoid",
        kernel_initializer=keras.initializers.GlorotUniform(seed=seed + 199),
        name=out_name,
    )(x)

    return keras.Model(inputs=inputs, outputs=outputs, name="siakar_face_detector")


def compute_iou_cxcywh(box_a: Sequence[float] | np.ndarray, box_b: Sequence[float] | np.ndarray) -> float:
    """Hitung Intersection-over-Union (IoU) antara dua kotak ternormalisasi [cx, cy, w, h]."""
    ax, ay, aw, ah = [float(v) for v in box_a]
    bx, by, bw, bh = [float(v) for v in box_b]

    ax1, ay1, ax2, ay2 = ax - aw / 2.0, ay - ah / 2.0, ax + aw / 2.0, ay + ah / 2.0
    bx1, by1, bx2, by2 = bx - bw / 2.0, by - bh / 2.0, bx + bw / 2.0, by + bh / 2.0

    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    inter_w = max(0.0, ix2 - ix1)
    inter_h = max(0.0, iy2 - iy1)
    inter_area = inter_w * inter_h

    area_a = max(0.0, aw) * max(0.0, ah)
    area_b = max(0.0, bw) * max(0.0, bh)
    union_area = area_a + area_b - inter_area
    if union_area <= 1e-12:
        return 0.0
    return float(inter_area / union_area)


DETECTOR_CUSTOM_OBJECTS: Dict[str, Any] = {
    "DetectorMultiTaskLoss": DetectorMultiTaskLoss,
    "DetectorFaceAccuracy": DetectorFaceAccuracy,
}
