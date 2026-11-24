"""
test_preprocess.py — Unit test untuk ml/src/siakar_ml/preprocess.py

Jalankan:
    cd ml && python -m pytest tests/test_preprocess.py -v
"""

from __future__ import annotations

import json
import os
import pathlib

import numpy as np
import pytest

# Pastikan paket siakar_ml dapat diimpor tanpa instalasi
_ML_ROOT = pathlib.Path(__file__).parent.parent
_SRC_DIR = _ML_ROOT / "src"
import sys
if str(_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_SRC_DIR))

from siakar_ml.preprocess import (
    load_preprocess_config,
    preprocess,
    preprocess_for_model,
)

# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

PREPROCESS_JSON = _ML_ROOT / "artifacts" / "preprocess.json"


@pytest.fixture(scope="module")
def config() -> dict:
    """Muat konfigurasi dari artifacts/preprocess.json."""
    assert PREPROCESS_JSON.exists(), (
        f"File tidak ditemukan: {PREPROCESS_JSON}. Pastikan T-104 step 1 sudah dilakukan."
    )
    return load_preprocess_config(str(PREPROCESS_JSON))


@pytest.fixture(scope="module")
def sample_image_rgb(config) -> np.ndarray:
    """Gambar uji acak (128×160×3 uint8) sebagai gambar 'wajah' dalam oval."""
    rng = np.random.default_rng(seed=0)
    return rng.integers(0, 256, size=(160, 128, 3), dtype=np.uint8)


# ---------------------------------------------------------------------------
# Tes
# ---------------------------------------------------------------------------

def test_output_shape(config, sample_image_rgb):
    """Output shape harus [input_size, input_size, 3]."""
    size = config["input_size"]
    out = preprocess(sample_image_rgb, config)
    assert out.shape == (size, size, 3), (
        f"Diharapkan ({size}, {size}, 3), dapat {out.shape}"
    )


def test_output_dtype(config, sample_image_rgb):
    """Output harus float32."""
    out = preprocess(sample_image_rgb, config)
    assert out.dtype == np.float32, f"Diharapkan float32, dapat {out.dtype}"


def test_output_range(config, sample_image_rgb):
    """Semua nilai harus dalam [-1.0, 1.0]."""
    out = preprocess(sample_image_rgb, config)
    assert out.min() >= -1.0 - 1e-6, f"Nilai minimum {out.min()} < -1.0"
    assert out.max() <= 1.0 + 1e-6, f"Nilai maksimum {out.max()} > 1.0"


def test_black_image(config):
    """Gambar hitam (zeros) → nilai mendekati -1.0."""
    black = np.zeros((160, 128, 3), dtype=np.uint8)
    out = preprocess(black, config)
    # (0 - 127.5) / 127.5 = -1.0
    assert np.allclose(out, -1.0, atol=1e-5), (
        f"Nilai rata-rata gambar hitam: {out.mean():.4f}, diharapkan mendekati -1.0"
    )


def test_white_image(config):
    """Gambar putih (255) → nilai mendekati 1.0."""
    white = np.full((160, 128, 3), 255, dtype=np.uint8)
    out = preprocess(white, config)
    # (255 - 127.5) / 127.5 ≈ 1.0
    assert np.allclose(out, 1.0, atol=1e-5), (
        f"Nilai rata-rata gambar putih: {out.mean():.4f}, diharapkan mendekati 1.0"
    )


def test_reproducibility(config, sample_image_rgb):
    """Input yang sama harus menghasilkan output yang identik."""
    out1 = preprocess(sample_image_rgb, config)
    out2 = preprocess(sample_image_rgb, config)
    assert np.array_equal(out1, out2), "Output tidak deterministik untuk input yang sama"


def test_batch_shape(config, sample_image_rgb):
    """preprocess_for_model harus menghasilkan shape [1, H, W, 3]."""
    size = config["input_size"]
    out = preprocess_for_model(sample_image_rgb, config)
    assert out.shape == (1, size, size, 3), (
        f"Diharapkan (1, {size}, {size}, 3), dapat {out.shape}"
    )
