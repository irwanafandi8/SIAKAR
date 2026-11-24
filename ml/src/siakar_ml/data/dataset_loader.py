"""
dataset_loader.py — Pipeline tf.data pembacaan citra dari disk dengan prefetch (tanpa memuat semua ke RAM).

Sesuai DECISIONS.md D-32 & ML_SPEC.md §4:
- Menerapkan kontrak praproses yang 100% identik secara matematis dengan preprocess.py:
  1. Crop kotak oval memakai pembulatan indeks ``floor``
  2. Resize bilinear murni ``half_pixel`` + ``clamp_to_edge`` dengan ``antialias=False``
  3. Pembulatan ke rentang integer [0, 255] memakai ``floor(clamp(v, 0, 255) + 0.5)``
  4. Normalisasi ``float32``: ``(u8 - normalization_mean) / normalization_std`` -> ``[-1, 1]``
- Augmentasi ringan hanya aktif saat ``training=True``.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

import tensorflow as tf


def build_tf_preprocess_fn(
    preprocess_cfg: Dict[str, Any],
    input_size_override: Optional[int] = None,
):
    """Buat fungsi TensorFlow murni yang identik secara numerik dengan siakar_ml.preprocess."""
    target_size = int(input_size_override or preprocess_cfg["input_size"])
    cx_ratio = float(preprocess_cfg["oval_center_x_ratio"])
    cy_ratio = float(preprocess_cfg["oval_center_y_ratio"])
    w_ratio = float(preprocess_cfg["oval_width_ratio"])
    h_ratio = float(preprocess_cfg["oval_height_ratio"])
    mean = float(preprocess_cfg.get("normalization_mean", 127.5))
    std = float(preprocess_cfg.get("normalization_std", 127.5))

    def _preprocess_path_and_label(file_path: tf.Tensor, label: tf.Tensor) -> Tuple[tf.Tensor, tf.Tensor]:
        raw_bytes = tf.io.read_file(file_path)
        image_u8 = tf.image.decode_image(raw_bytes, channels=3, expand_animations=False)
        image_u8.set_shape([None, None, 3])

        shape = tf.shape(image_u8)
        h_i = shape[0]
        w_i = shape[1]
        h_f = tf.cast(h_i, tf.float32)
        w_f = tf.cast(w_i, tf.float32)

        cx = cx_ratio * w_f
        cy = cy_ratio * h_f
        half_w = w_ratio * w_f / 2.0
        half_h = h_ratio * h_f / 2.0

        x1 = tf.maximum(0, tf.minimum(w_i - 1, tf.cast(tf.math.floor(cx - half_w), tf.int32)))
        y1 = tf.maximum(0, tf.minimum(h_i - 1, tf.cast(tf.math.floor(cy - half_h), tf.int32)))
        x2 = tf.maximum(x1 + 1, tf.minimum(w_i, tf.cast(tf.math.floor(cx + half_w), tf.int32)))
        y2 = tf.maximum(y1 + 1, tf.minimum(h_i, tf.cast(tf.math.floor(cy + half_h), tf.int32)))

        cropped = tf.slice(image_u8, [y1, x1, 0], [y2 - y1, x2 - x1, 3])

        # tf.image.resize(..., BILINEAR, antialias=False) memakai half_pixel + clamp_to_edge
        resized_f32 = tf.image.resize(
            tf.cast(cropped, tf.float32),
            size=[target_size, target_size],
            method=tf.image.ResizeMethod.BILINEAR,
            antialias=False,
        )
        rounded_u8_f32 = tf.math.floor(tf.clip_by_value(resized_f32, 0.0, 255.0) + 0.5)
        normalized = (rounded_u8_f32 - tf.constant(mean, dtype=tf.float32)) / tf.constant(std, dtype=tf.float32)
        normalized.set_shape([target_size, target_size, 3])
        return normalized, tf.cast(label, tf.int32)

    return _preprocess_path_and_label


def build_tf_augment_fn(seed: int = 42):
    """Fungsi augmentasi ringan untuk data latih saja (ML_SPEC.md §2.3)."""

    def _augment(image: tf.Tensor, label: tf.Tensor) -> Tuple[tf.Tensor, tf.Tensor]:
        unit = (image + 1.0) * 0.5
        unit = tf.image.random_flip_left_right(unit, seed=seed)
        unit = tf.image.random_brightness(unit, max_delta=0.15, seed=seed + 1)
        unit = tf.image.random_contrast(unit, lower=0.80, upper=1.20, seed=seed + 2)
        unit = tf.clip_by_value(unit, 0.0, 1.0)
        out = unit * 2.0 - 1.0
        return out, label

    return _augment


def create_classification_dataset(
    samples: Sequence[Dict[str, Any]],
    preprocess_cfg: Dict[str, Any],
    batch_size: int = 32,
    training: bool = False,
    seed: int = 42,
    base_dir: str | Path = ".",
    input_size_override: Optional[int] = None,
) -> tf.data.Dataset:
    """Buat ``tf.data.Dataset`` streaming dari daftar sampel ``[{"path": ..., "label": ...}]``."""
    if not samples:
        raise ValueError("Daftar sampel tf.data kosong.")

    root = Path(base_dir)
    paths: List[str] = []
    labels: List[int] = []
    for item in samples:
        p = Path(item["path"])
        resolved = p if p.is_absolute() else (root / p)
        paths.append(str(resolved))
        labels.append(int(item["label"]))

    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if training:
        ds = ds.shuffle(buffer_size=min(len(paths), 4096), seed=seed, reshuffle_each_iteration=True)

    preprocess_fn = build_tf_preprocess_fn(preprocess_cfg, input_size_override=input_size_override)
    ds = ds.map(preprocess_fn, num_parallel_calls=tf.data.AUTOTUNE)

    if training:
        augment_fn = build_tf_augment_fn(seed=seed)
        ds = ds.map(augment_fn, num_parallel_calls=tf.data.AUTOTUNE)

    ds = ds.batch(batch_size, drop_remainder=False)
    ds = ds.prefetch(tf.data.AUTOTUNE)
    return ds
