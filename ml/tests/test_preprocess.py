"""
test_preprocess.py — Unit test kontrak praproses citra SIAKAR (DECISIONS.md D-32 & ML_SPEC.md §4).

Memverifikasi:
1. Kesamaan berkas kontrak ml/artifacts/preprocess.json dan mobile/assets/models/preprocess.json.
2. Shape, dtype (float32), rentang [-1.0, 1.0], citra hitam/putih, reproduksibilitas, dan batch NHWC.
3. Rumus matematis eksak bilinear murni (half_pixel + clamp_to_edge, anti_aliasing=False) terhadap
   perhitungan manual pada matriks 2x2 -> 4x4.
4. Aturan konversi uint8 floor_half_up (floor(clamp(v, 0, 255) + 0.5)) pada nilai pecahan .5
   agar bebas selisih banker's rounding vs Dart.
5. Paritas numerik antara implementasi NumPy (preprocess.py) dan pipeline TensorFlow (dataset_loader.py).
"""

from __future__ import annotations

import pathlib
import sys

import numpy as np
from PIL import Image
import pytest

_ML_ROOT = pathlib.Path(__file__).parent.parent
_REPO_ROOT = _ML_ROOT.parent
_SRC_DIR = _ML_ROOT / "src"
if str(_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_SRC_DIR))

from siakar_ml.data.dataset_loader import create_classification_dataset
from siakar_ml.preprocess import (
    bilinear_resize_raw,
    crop_to_oval_region,
    float_to_uint8_floor_half_up,
    load_preprocess_config,
    normalize_image,
    preprocess,
    preprocess_for_model,
    resize_image,
)

PREPROCESS_JSON = _ML_ROOT / "artifacts" / "preprocess.json"
MOBILE_PREPROCESS_JSON = _REPO_ROOT / "mobile" / "assets" / "models" / "preprocess.json"


@pytest.fixture(scope="module")
def config() -> dict:
    assert PREPROCESS_JSON.exists(), f"File tidak ditemukan: {PREPROCESS_JSON}"
    return load_preprocess_config(str(PREPROCESS_JSON))


@pytest.fixture(scope="module")
def sample_image_rgb() -> np.ndarray:
    rng = np.random.default_rng(seed=0)
    return rng.integers(0, 256, size=(160, 128, 3), dtype=np.uint8)


def test_preprocess_json_contract_fields_and_mobile_sync(config: dict) -> None:
    """preprocess.json di ml/ dan mobile/ wajib identik dan memuat seluruh kunci kontrak D-32."""
    assert config["interpolation"] == "bilinear"
    assert config["coordinate_transformation_mode"] == "half_pixel"
    assert config["border_mode"] == "clamp_to_edge"
    assert config["anti_aliasing"] is False
    assert config["uint8_rounding"] == "floor_half_up"
    assert config["crop_box_rounding"] == "floor"
    assert config["channel_order"] == "RGB"
    assert config["output_dtype"] == "float32"

    assert MOBILE_PREPROCESS_JSON.exists(), f"Salinan mobile tidak ditemukan: {MOBILE_PREPROCESS_JSON}"
    ml_text = PREPROCESS_JSON.read_text(encoding="utf-8")
    mob_text = MOBILE_PREPROCESS_JSON.read_text(encoding="utf-8")
    assert ml_text == mob_text, "preprocess.json di ml/ dan mobile/ berbeda!"


def test_output_shape(config: dict, sample_image_rgb: np.ndarray) -> None:
    size = config["input_size"]
    out = preprocess(sample_image_rgb, config)
    assert out.shape == (size, size, 3)


def test_output_dtype_and_range(config: dict, sample_image_rgb: np.ndarray) -> None:
    out = preprocess(sample_image_rgb, config)
    assert out.dtype == np.float32
    assert out.min() >= -1.0 - 1e-6
    assert out.max() <= 1.0 + 1e-6


def test_black_and_white_images(config: dict) -> None:
    black = np.zeros((160, 128, 3), dtype=np.uint8)
    white = np.full((160, 128, 3), 255, dtype=np.uint8)
    assert np.allclose(preprocess(black, config), -1.0, atol=1e-6)
    assert np.allclose(preprocess(white, config), 1.0, atol=1e-6)


def test_reproducibility_and_batch_shape(config: dict, sample_image_rgb: np.ndarray) -> None:
    size = config["input_size"]
    out1 = preprocess(sample_image_rgb, config)
    out2 = preprocess(sample_image_rgb, config)
    assert np.array_equal(out1, out2)

    batched = preprocess_for_model(sample_image_rgb, config)
    assert batched.shape == (1, size, size, 3)
    assert batched.dtype == np.float32


def test_pure_bilinear_half_pixel_clamp_to_edge_hand_calculation() -> None:
    """Verifikasi matematis eksak pada matriks 2x2 -> 4x4 (tanpa Gaussian blur, clamp_to_edge)."""
    # Matriks 2x2 satu nilai berulang di 3 kanal:
    # [[ 0, 100],
    #  [200, 100]]
    grid_2x2 = np.array(
        [
            [[0, 0, 0], [100, 100, 100]],
            [[200, 200, 200], [100, 100, 100]],
        ],
        dtype=np.uint8,
    )
    raw_4x4 = bilinear_resize_raw(grid_2x2, out_height=4, out_width=4)[:, :, 0]

    # Untuk in=2, out=4:
    # dst=0 -> src = 0.5*(2/4)-0.5 = -0.25 -> clamp = 0.0
    # dst=1 -> src = 1.5*(2/4)-0.5 =  0.25
    # dst=2 -> src = 2.5*(2/4)-0.5 =  0.75
    # dst=3 -> src = 3.5*(2/4)-0.5 =  1.25 -> clamp = 1.0
    expected = np.array(
        [
            [0.0, 25.0, 75.0, 100.0],
            [50.0, 62.5, 87.5, 100.0],
            [150.0, 137.5, 112.5, 100.0],
            [200.0, 175.0, 125.0, 100.0],
        ],
        dtype=np.float64,
    )
    assert np.allclose(raw_4x4, expected, atol=1e-12)

    # Uji aturan pembulatan floor_half_up pada nilai .5 (62.5->63, 87.5->88, 137.5->138, 112.5->113):
    # Perhatikan: np.rint (round-half-to-even) akan membulatkan 62.5->62 dan 112.5->112!
    u8_4x4 = resize_image(grid_2x2, size=4)[:, :, 0]
    expected_u8 = np.array(
        [
            [0, 25, 75, 100],
            [50, 63, 88, 100],
            [150, 138, 113, 100],
            [200, 175, 125, 100],
        ],
        dtype=np.uint8,
    )
    assert np.array_equal(u8_4x4, expected_u8)


def test_uint8_floor_half_up_explicit_edge_values() -> None:
    vals = np.array([-3.2, 0.0, 0.4999, 0.5, 1.5, 2.5, 127.5, 254.5, 300.0], dtype=np.float64)
    got = float_to_uint8_floor_half_up(vals)
    expected = np.array([0, 0, 0, 1, 2, 3, 128, 255, 255], dtype=np.uint8)
    assert np.array_equal(got, expected)

    # Normalisasi eksplisit dari uint8: 0 -> -1.0, 128 -> (128-127.5)/127.5, 255 -> +1.0
    norm = normalize_image(np.array([[[0, 128, 255]]], dtype=np.uint8))
    assert norm.dtype == np.float32
    assert norm[0, 0, 0] == pytest.approx(-1.0, abs=1e-7)
    assert norm[0, 0, 1] == pytest.approx((128.0 - 127.5) / 127.5, abs=1e-7)
    assert norm[0, 0, 2] == pytest.approx(1.0, abs=1e-7)


def test_crop_box_floor_rounding_is_deterministic() -> None:
    img = np.arange(100 * 80 * 3, dtype=np.uint8).reshape((100, 80, 3))
    cfg = {
        "oval_center_x_ratio": 0.5,
        "oval_center_y_ratio": 0.5,
        "oval_width_ratio": 0.70,
        "oval_height_ratio": 0.85,
    }
    # w=80: cx=40, half_w=28 -> x1=12, x2=68 -> lebar 56
    # h=100: cy=50, half_h=42.5 -> y1=floor(7.5)=7, y2=floor(92.5)=92 -> tinggi 85
    cropped = crop_to_oval_region(img, cfg)
    assert cropped.shape == (85, 56, 3)


def test_numpy_preprocess_matches_tf_dataset_loader(config: dict, tmp_path: pathlib.Path) -> None:
    """Pastikan pipeline tf.data di dataset_loader.py paritas tinggi terhadap preprocess.py."""
    rng = np.random.default_rng(1234)
    img_rgb = rng.integers(0, 256, size=(160, 128, 3), dtype=np.uint8)
    img_path = tmp_path / "parity_check.png"
    Image.fromarray(img_rgb).save(img_path, format="PNG")

    ref_np = preprocess(img_rgb, config)

    ds = create_classification_dataset(
        samples=[{"path": "parity_check.png", "label": 0}],
        preprocess_cfg=config,
        batch_size=1,
        training=False,
        base_dir=tmp_path,
    )
    tf_batch, _ = next(iter(ds))
    tf_out = tf_batch[0].numpy()

    assert tf_out.shape == ref_np.shape
    assert tf_out.dtype == np.float32
    # Selisih maksimum <= 1/127.5 (~0.0079) hanya bila ada perbedaan presisi float32 vs float64 tepat di .5,
    # dan rata-rata selisih absolut mendekati 0.
    assert float(np.mean(np.abs(tf_out - ref_np))) < 1e-4
