"""
test_detector_pipeline.py — Unit test & dry-run (1 step dummy) untuk detektor wajah SIAKAR (ML7 / T-108, T-205):
- Shape input/output tensor [B, 64, 64, 3] -> [B, 5] ([face_score, cx, cy, w, h] dalam [0, 1])
- Masking bbox pada DetectorMultiTaskLoss & perhitungan IoU
- Generator negatif non-wajah sintetis (prepare_negatives.py)
- End-to-end dry-run 1 step: train -> evaluate -> detector.tflite -> inferensi TFLite & detector_golden.json
"""

from __future__ import annotations

import csv
import json
import pathlib
import sys

import numpy as np
from PIL import Image
import pytest
import tensorflow as tf

_ML_ROOT = pathlib.Path(__file__).parent.parent
_SRC_DIR = _ML_ROOT / "src"
if str(_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_SRC_DIR))

from siakar_ml.data.prepare_negatives import generate_synthetic_negatives
from siakar_ml.models.detector_cnn import (
    DetectorMultiTaskLoss,
    build_detector_model,
    compute_iou_cxcywh,
)
from siakar_ml.train_detector import run_detector_pipeline

PREPROCESS_JSON = _ML_ROOT / "artifacts" / "preprocess.json"


def test_detector_model_shapes_iou_and_masked_loss() -> None:
    model_bbox = build_detector_model(input_size=64, include_bbox=True, seed=42)
    assert model_bbox.input_shape == (None, 64, 64, 3)
    assert model_bbox.output_shape == (None, 5)

    x = tf.random.uniform((3, 64, 64, 3), minval=-1.0, maxval=1.0, seed=5)
    out = model_bbox(x, training=False).numpy()
    assert out.shape == (3, 5)
    assert out.dtype == np.float32
    assert float(np.min(out)) >= 0.0 and float(np.max(out)) <= 1.0

    model_score_only = build_detector_model(input_size=64, include_bbox=False, seed=42)
    assert model_score_only.output_shape == (None, 1)

    # Uji IoU kotak ternormalisasi
    assert compute_iou_cxcywh([0.5, 0.5, 0.4, 0.4], [0.5, 0.5, 0.4, 0.4]) == pytest.approx(1.0)
    assert compute_iou_cxcywh([0.2, 0.2, 0.2, 0.2], [0.8, 0.8, 0.2, 0.2]) == pytest.approx(0.0)

    # Uji masking bbox pada sampel negatif (is_face == 0): perubahan prediksi bbox tidak mengubah loss negatif
    loss_fn = DetectorMultiTaskLoss(bbox_weight=2.0, reduction=tf.keras.losses.Reduction.NONE)
    y_neg = tf.constant([[0.0, 0.0, 0.0, 0.0, 0.0]], dtype=tf.float32)
    pred_a = tf.constant([[0.2, 0.1, 0.1, 0.1, 0.1]], dtype=tf.float32)
    pred_b = tf.constant([[0.2, 0.9, 0.9, 0.9, 0.9]], dtype=tf.float32)
    assert float(loss_fn(y_neg, pred_a).numpy()[0]) == pytest.approx(
        float(loss_fn(y_neg, pred_b).numpy()[0]),
        abs=1e-6,
    )


def test_detector_dry_run_tflite_export_and_golden_samples(tmp_path: pathlib.Path) -> None:
    pos_dir = tmp_path / "raw_faces"
    neg_dir = tmp_path / "negatives"
    ckpt_dir = tmp_path / "checkpoints"
    artifacts_dir = tmp_path / "artifacts"
    reports_dir = tmp_path / "reports"
    mock_mobile_models = tmp_path / "mock_mobile" / "assets" / "models"
    mock_mobile_golden = tmp_path / "mock_mobile" / "test" / "golden_detector"

    # Buat 6 folder identitas sintetis × 2 citra
    rng = np.random.default_rng(12)
    for sid in range(6):
        sdir = pos_dir / f"subj_{sid:03d}"
        sdir.mkdir(parents=True)
        for k in range(2):
            arr = rng.integers(80, 220, size=(64, 64, 3), dtype=np.uint8)
            Image.fromarray(arr).save(sdir / f"{k}.png", format="PNG")

    neg_info = generate_synthetic_negatives(output_dir=neg_dir, n_images=12, image_size=64, seed=42)
    assert neg_info["total_negative_images"] == 12

    tflite_out = artifacts_dir / "detector.tflite"
    keras_out = artifacts_dir / "detector.keras"
    thr_out = artifacts_dir / "detector_threshold.json"
    golden_dir = artifacts_dir / "golden_detector"

    summary = run_detector_pipeline(
        positive_dir=pos_dir,
        negative_dir=neg_dir,
        preprocess_config_path=PREPROCESS_JSON,
        checkpoint_dir=ckpt_dir,
        model_output_path=keras_out,
        tflite_output_path=tflite_out,
        threshold_output_path=thr_out,
        golden_dir=golden_dir,
        reports_dir=reports_dir,
        input_size=64,
        include_bbox=True,
        max_positives=12,
        n_synthetic_negatives=12,
        batch_size=4,
        epochs=1,
        max_steps_per_epoch=1,
        max_eval_batches=1,
        copy_to_mobile=True,
        mobile_models_dir=mock_mobile_models,
        mobile_golden_dir=mock_mobile_golden,
        seed=42,
    )

    assert keras_out.exists()
    assert tflite_out.exists() and tflite_out.stat().st_size > 1024
    assert thr_out.exists()
    assert (mock_mobile_models / "detector.tflite").exists()
    assert (mock_mobile_models / "detector_threshold.json").exists()
    assert (mock_mobile_golden / "detector_golden.json").exists()

    # Verifikasi inferensi TFLite secara langsung: [1, 64, 64, 3] -> [1, 5]
    interpreter = tf.lite.Interpreter(model_path=str(tflite_out))
    interpreter.allocate_tensors()
    in_det = interpreter.get_input_details()
    out_det = interpreter.get_output_details()
    assert tuple(in_det[0]["shape"]) == (1, 64, 64, 3)
    assert tuple(out_det[0]["shape"]) == (1, 5)

    manifest = json.loads((golden_dir / "detector_golden.json").read_text(encoding="utf-8"))
    assert manifest["output_format"] == ["face_score", "cx", "cy", "w", "h"]
    assert len(manifest["samples"]) == 4
    for item in manifest["samples"]:
        assert 0.0 <= item["face_score"] <= 1.0
        assert len(item["bbox_cxcywh"]) == 4
        assert item["max_abs_diff"] < 1e-3

    with open(summary["metrics_csv_path"], "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert {r["split"] for r in rows} == {"val", "test"}
