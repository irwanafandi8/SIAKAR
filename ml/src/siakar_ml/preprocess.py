"""
preprocess.py — Satu-satunya implementasi referensi praproses citra SIAKAR.

Spesifikasi parameter : ml/artifacts/preprocess.json (identik dengan mobile/assets/models/preprocess.json)
Keputusan rujukan     : docs/project-kit/DECISIONS.md (D-32) & docs/project-kit/ML_SPEC.md (§4)

Aturan matematis eksak (agar paritas numerik Python ↔ Dart terjamin 100%):
1. Crop kotak oval memakai pembulatan indeks ``floor`` dengan lebar/tinggi minimal 1 piksel.
2. Resize ke ``[size, size, 3]`` memakai interpolasi bilinear 2D murni:
   - Pemetaan koordinat ``half_pixel``: ``src = (dst + 0.5) * (in_len / out_len) - 0.5``
   - Batas tepi ``clamp_to_edge``: ``clamp(src, 0.0, in_len - 1.0)``
   - TANPA filter Gaussian anti-aliasing (``anti_aliasing = false``) dan TANPA reflect padding.
3. Konversi hasil interpolasi ke ``uint8`` memakai pembulatan ``floor_half_up``:
   ``uint8(floor(clamp(v, 0.0, 255.0) + 0.5))`` (menghindari ambiguitas pemotongan maupun round-half-to-even).
4. Normalisasi ke ``float32`` urutan RGB:
   ``(float32(u8) - normalization_mean) / normalization_std`` dengan ``mean=127.5, std=127.5`` -> ``[-1.0, 1.0]``.
"""

from __future__ import annotations

import json
import math
from typing import Any, Dict

import numpy as np


def load_preprocess_config(config_path: str) -> Dict[str, Any]:
    """Muat konfigurasi praproses dari berkas JSON kontrak tunggal."""
    with open(config_path, "r", encoding="utf-8") as f:
        return json.load(f)


def crop_to_oval_region(image_rgb: np.ndarray, config: Dict[str, Any]) -> np.ndarray:
    """Potong kotak pembatas (bounding box) area oval panduan secara deterministik.

    Menggunakan pembulatan ``floor`` pada batas indeks dan menjamin minimal 1x1 piksel.
    """
    if image_rgb.ndim != 3 or image_rgb.shape[2] != 3:
        raise ValueError(f"image_rgb harus memiliki shape [H, W, 3], diterima {image_rgb.shape}.")

    h, w = int(image_rgb.shape[0]), int(image_rgb.shape[1])
    if h < 1 or w < 1:
        raise ValueError("Dimensi gambar masukan tidak boleh kosong.")

    cx = float(config["oval_center_x_ratio"]) * w
    cy = float(config["oval_center_y_ratio"]) * h
    half_w = float(config["oval_width_ratio"]) * w / 2.0
    half_h = float(config["oval_height_ratio"]) * h / 2.0

    x1 = max(0, min(w - 1, int(math.floor(cx - half_w))))
    y1 = max(0, min(h - 1, int(math.floor(cy - half_h))))
    x2 = max(x1 + 1, min(w, int(math.floor(cx + half_w))))
    y2 = max(y1 + 1, min(h, int(math.floor(cy + half_h))))

    return image_rgb[y1:y2, x1:x2]


def bilinear_resize_raw(image: np.ndarray, out_height: int, out_width: int) -> np.ndarray:
    """Interpolasi bilinear 2D murni (half_pixel + clamp_to_edge, tanpa anti-aliasing).

    Args:
        image: Citra masukan ``[in_h, in_w, C]`` (uint8 atau float dalam skala 0..255).
        out_height: Tinggi keluaran (piksel).
        out_width: Lebar keluaran (piksel).

    Returns:
        Array ``float64`` berukuran ``[out_height, out_width, C]`` sebelum pembulatan uint8.
    """
    if out_height < 1 or out_width < 1:
        raise ValueError("Ukuran keluaran resize harus >= 1.")

    in_h, in_w = int(image.shape[0]), int(image.shape[1])
    src_img = image.astype(np.float64, copy=False)

    # Koordinat sumber dengan konvensi half-pixel center + clamp_to_edge
    dst_y = np.arange(out_height, dtype=np.float64)
    dst_x = np.arange(out_width, dtype=np.float64)

    src_y = (dst_y + 0.5) * (float(in_h) / float(out_height)) - 0.5
    src_x = (dst_x + 0.5) * (float(in_w) / float(out_width)) - 0.5

    sy = np.clip(src_y, 0.0, float(in_h - 1))
    sx = np.clip(src_x, 0.0, float(in_w - 1))

    y0 = np.floor(sy).astype(np.int64)
    x0 = np.floor(sx).astype(np.int64)
    y1 = np.minimum(y0 + 1, in_h - 1)
    x1 = np.minimum(x0 + 1, in_w - 1)

    wy = (sy - y0)[:, None, None]        # [out_h, 1, 1]
    wx = (sx - x0)[None, :, None]        # [1, out_w, 1]

    top_left = src_img[y0[:, None], x0[None, :]]
    top_right = src_img[y0[:, None], x1[None, :]]
    bot_left = src_img[y1[:, None], x0[None, :]]
    bot_right = src_img[y1[:, None], x1[None, :]]

    interpolated = (
        (1.0 - wy) * (1.0 - wx) * top_left
        + (1.0 - wy) * wx * top_right
        + wy * (1.0 - wx) * bot_left
        + wy * wx * bot_right
    )
    return interpolated


def float_to_uint8_floor_half_up(values: np.ndarray) -> np.ndarray:
    """Konversi nilai piksel float ke ``uint8`` [0, 255] memakai aturan ``floor(clamp(v, 0, 255) + 0.5)``.

    Aturan ini menghindari perbedaan pembulatan nilai ``.5`` antara ``np.rint`` Python
    (round-half-to-even) dan ``double.round()`` / ``floor(v + 0.5)`` di Dart.
    """
    clamped = np.clip(values, 0.0, 255.0)
    return np.floor(clamped + 0.5).astype(np.uint8)


def resize_image(image: np.ndarray, size: int) -> np.ndarray:
    """Ubah ukuran citra ke ``[size, size, 3]`` uint8 memakai bilinear murni + ``floor_half_up``."""
    raw = bilinear_resize_raw(image, out_height=int(size), out_width=int(size))
    return float_to_uint8_floor_half_up(raw)


def normalize_image(
    image: np.ndarray,
    mean: float = 127.5,
    std: float = 127.5,
) -> np.ndarray:
    """Normalisasi piksel ``uint8`` [0..255] ke ``float32``: ``(float32(x) - mean) / std``."""
    img_f32 = image.astype(np.float32)
    mean_f32 = np.float32(mean)
    std_f32 = np.float32(std)
    return ((img_f32 - mean_f32) / std_f32).astype(np.float32)


def preprocess(image_rgb: np.ndarray, config: Dict[str, Any]) -> np.ndarray:
    """Pipeline praproses lengkap: crop oval → resize bilinear murni (uint8) → normalisasi float32."""
    cropped = crop_to_oval_region(image_rgb, config)
    resized_u8 = resize_image(cropped, int(config["input_size"]))
    mean = float(config.get("normalization_mean", 127.5))
    std = float(config.get("normalization_std", 127.5))
    return normalize_image(resized_u8, mean=mean, std=std)


def preprocess_for_model(image_rgb: np.ndarray, config: Dict[str, Any]) -> np.ndarray:
    """Pipeline praproses lengkap dengan dimensi batch NHWC ``[1, input_size, input_size, 3]`` float32."""
    processed = preprocess(image_rgb, config)
    return np.expand_dims(processed, axis=0)
