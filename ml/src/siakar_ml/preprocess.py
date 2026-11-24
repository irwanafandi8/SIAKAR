"""
preprocess.py — Satu-satunya implementasi praproses SIAKAR.

Spesifikasi parameter: ml/artifacts/preprocess.json
Kontrak: praproses HARUS identik antara Python (pelatihan/evaluasi/ekspor)
dan Dart (aplikasi). Python adalah referensi; bila ada perbedaan, Python menang.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from skimage.transform import resize as ski_resize


def load_preprocess_config(config_path: str) -> dict:
    """Muat konfigurasi praproses dari file JSON.

    Args:
        config_path: Path ke file JSON (mis. ``ml/artifacts/preprocess.json``).

    Returns:
        Dict konfigurasi dengan kunci:
        input_size, oval_center_x_ratio, oval_center_y_ratio,
        oval_width_ratio, oval_height_ratio, channel_order,
        normalization_mean, normalization_std, interpolation.
    """
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)
    return config


def crop_to_oval_region(image_rgb: np.ndarray, config: dict) -> np.ndarray:
    """Crop persegi dari bounding box oval panduan.

    Oval didefinisikan oleh rasio terhadap dimensi gambar.
    Bounding box persegi diambil sebagai irisan dari oval width × oval height,
    dipusatkan pada (cx, cy).

    Args:
        image_rgb: Gambar RGB, shape ``[H, W, 3]``, dtype uint8 atau float.
        config: Dict dari :func:`load_preprocess_config`.

    Returns:
        Gambar ter-crop, shape ``[crop_h, crop_w, 3]``.
    """
    h, w = image_rgb.shape[:2]

    cx = config["oval_center_x_ratio"] * w
    cy = config["oval_center_y_ratio"] * h
    half_w = config["oval_width_ratio"] * w / 2.0
    half_h = config["oval_height_ratio"] * h / 2.0

    x1 = int(max(0, cx - half_w))
    y1 = int(max(0, cy - half_h))
    x2 = int(min(w, cx + half_w))
    y2 = int(min(h, cy + half_h))

    return image_rgb[y1:y2, x1:x2]


def resize_image(image: np.ndarray, size: int) -> np.ndarray:
    """Ubah ukuran gambar ke ``[size, size, 3]`` dengan interpolasi bilinear.

    Args:
        image: Gambar, shape ``[H, W, 3]``.
        size: Ukuran sisi keluaran (piksel).

    Returns:
        Gambar berukuran ``[size, size, 3]``, dtype uint8 (0–255).
    """
    # ski_resize mengembalikan float64 dalam [0, 1] bila input uint8
    resized = ski_resize(
        image,
        (size, size, 3),
        order=1,          # bilinear
        mode="reflect",
        anti_aliasing=True,
        preserve_range=False,
    )
    # Kembalikan ke uint8 [0, 255]
    resized_uint8 = (resized * 255.0).clip(0, 255).astype(np.uint8)
    return resized_uint8


def normalize_image(image: np.ndarray) -> np.ndarray:
    """Normalisasi piksel: ``(x - 127.5) / 127.5`` → float32 dalam [-1, 1].

    Args:
        image: Gambar, shape ``[H, W, 3]``, nilai 0–255 (uint8 atau float).

    Returns:
        Gambar ternormalisasi, shape ``[H, W, 3]``, dtype float32.
    """
    img = image.astype(np.float32)
    return (img - 127.5) / 127.5


def preprocess(image_rgb: np.ndarray, config: dict) -> np.ndarray:
    """Pipeline praproses lengkap: crop → resize → normalize.

    Args:
        image_rgb: Gambar RGB, shape ``[H, W, 3]``, uint8 (0–255).
        config: Dict dari :func:`load_preprocess_config`.

    Returns:
        Gambar ternormalisasi, shape ``[input_size, input_size, 3]``, float32.
    """
    cropped = crop_to_oval_region(image_rgb, config)
    resized = resize_image(cropped, config["input_size"])
    normalized = normalize_image(resized)
    return normalized


def preprocess_for_model(image_rgb: np.ndarray, config: dict) -> np.ndarray:
    """Pipeline praproses + tambahkan dimensi batch (NHWC).

    Args:
        image_rgb: Gambar RGB, shape ``[H, W, 3]``, uint8 (0–255).
        config: Dict dari :func:`load_preprocess_config`.

    Returns:
        Tensor, shape ``[1, input_size, input_size, 3]``, float32.
    """
    processed = preprocess(image_rgb, config)
    return np.expand_dims(processed, axis=0)
