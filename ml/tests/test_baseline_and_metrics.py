"""
test_baseline_and_metrics.py — Unit test untuk metrik FAR/FRR/EER/ROC AUC (evaluate.py)
serta pipeline baseline klasik HOG/LBP (baseline_classic.py) pada data sintetis dummy (T-106).
"""

from __future__ import annotations

import csv
import json
import pathlib
import sys

import numpy as np
import pytest
from skimage.io import imsave

_ML_ROOT = pathlib.Path(__file__).parent.parent
_SRC_DIR = _ML_ROOT / "src"
if str(_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_SRC_DIR))

from siakar_ml.data.split import build_and_save_all_splits
from siakar_ml.evaluate import compute_classification_metrics, compute_verification_metrics
from siakar_ml.models.baseline_classic import (
    compute_baseline_similarity,
    extract_classic_features,
    extract_hog_features,
    extract_lbp_features,
    run_baseline_suite,
)
from siakar_ml.preprocess import load_preprocess_config

PREPROCESS_JSON = _ML_ROOT / "artifacts" / "preprocess.json"


def _generate_patterned_face(subj_idx: int, var_idx: int, size: int = 64) -> np.ndarray:
    """Buat citra sintetis berpola frekuensi/orientasi unik per identitas + derau kecil."""
    rng = np.random.default_rng(subj_idx * 1000 + var_idx)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size

    freq_x = (subj_idx % 5) + 1.0
    freq_y = (subj_idx // 5) + 1.0
    phase = (subj_idx * 0.7) + (var_idx * 0.05)

    pattern = 0.5 + 0.4 * np.sin(2.0 * np.pi * (freq_x * xx + freq_y * yy) + phase)
    noise = rng.normal(0.0, 0.03, size=(size, size)).astype(np.float32)
    gray = np.clip((pattern + noise) * 255.0, 0, 255).astype(np.uint8)
    return np.stack([gray, gray, gray], axis=-1)


def test_verification_metrics_perfect_separation_and_fixed_threshold() -> None:
    scores = np.array([0.10, 0.20, 0.25, 0.30, 0.80, 0.85, 0.90, 0.95], dtype=np.float32)
    labels = np.array([0, 0, 0, 0, 1, 1, 1, 1], dtype=np.int32)

    val_m = compute_verification_metrics(scores, labels)
    assert val_m["eer"] == pytest.approx(0.0, abs=1e-6)
    assert val_m["roc_auc"] == pytest.approx(1.0, abs=1e-6)
    assert 0.30 < val_m["optimal_threshold"] < 0.80
    assert np.isfinite(val_m["optimal_threshold"])
    assert val_m["far"] == pytest.approx(0.0)
    assert val_m["frr"] == pytest.approx(0.0)
    assert val_m["tar_at_far_1pct"] == pytest.approx(1.0)

    # Uji evaluasi dengan ambang tetap dari validasi pada skor yang sedikit tumpang tindih
    test_scores = np.array([0.20, 0.60, 0.50, 0.90], dtype=np.float32)
    test_labels = np.array([0, 0, 1, 1], dtype=np.int32)
    fixed_thr = 0.55

    test_m = compute_verification_metrics(test_scores, test_labels, fixed_threshold=fixed_thr)
    assert test_m["applied_threshold"] == pytest.approx(0.55)
    # Impostor [0.20, 0.60] >= 0.55 -> 1/2 = 0.5 FAR
    assert test_m["far"] == pytest.approx(0.5)
    # Genuine [0.50, 0.90] < 0.55 -> 1/2 = 0.5 FRR
    assert test_m["frr"] == pytest.approx(0.5)
    assert test_m["accuracy"] == pytest.approx(0.5)


def test_classification_metrics_top1_and_worst_identities() -> None:
    y_true = np.array([0, 0, 1, 1, 2, 2])
    y_pred = np.array([0, 0, 1, 0, 0, 0])
    scores = np.array(
        [
            [3.0, 1.0, 0.0],
            [2.5, 0.5, 0.1],
            [0.2, 2.0, 0.1],
            [1.5, 1.2, 0.0],
            [2.0, 0.5, 1.0],
            [1.8, 0.2, 0.9],
        ]
    )
    m = compute_classification_metrics(
        y_true,
        y_pred,
        decision_scores=scores,
        id_names={0: "id_a", 1: "id_b", 2: "id_c"},
    )
    assert m["top1_accuracy"] == pytest.approx(3.0 / 6.0)
    assert m["worst_identities"][0]["identity"] == "id_c"
    assert m["worst_identities"][0]["accuracy"] == pytest.approx(0.0)


def test_hog_and_lbp_feature_extractors() -> None:
    cfg = load_preprocess_config(str(PREPROCESS_JSON))
    img_a1 = _generate_patterned_face(subj_idx=0, var_idx=0, size=112)
    img_a2 = _generate_patterned_face(subj_idx=0, var_idx=1, size=112)
    img_b1 = _generate_patterned_face(subj_idx=7, var_idx=0, size=112)

    hog_vec = extract_hog_features(img_a1)
    lbp_vec = extract_lbp_features(img_a1)
    assert hog_vec.dtype == np.float32
    assert lbp_vec.dtype == np.float32
    assert np.linalg.norm(hog_vec) == pytest.approx(1.0, abs=1e-5)
    assert np.linalg.norm(lbp_vec) == pytest.approx(1.0, abs=1e-5)

    for method in ("hog", "lbp", "hog_lbp"):
        fa1 = extract_classic_features(img_a1, cfg, method=method)
        fa2 = extract_classic_features(img_a2, cfg, method=method)
        fb1 = extract_classic_features(img_b1, cfg, method=method)

        assert np.linalg.norm(fa1) == pytest.approx(1.0, abs=1e-5)
        assert compute_baseline_similarity(fa1, fa1) == pytest.approx(1.0, abs=1e-5)
        assert compute_baseline_similarity(fa1, fa2) > compute_baseline_similarity(fa1, fb1)


def test_end_to_end_baseline_suite_on_synthetic_data(tmp_path: pathlib.Path) -> None:
    raw_dir = tmp_path / "raw_synth"
    splits_dir = tmp_path / "splits_synth"
    reports_dir = tmp_path / "reports_synth"
    raw_dir.mkdir(parents=True)

    # Buat 10 identitas × 8 gambar sintetis kecil
    for subj_idx in range(10):
        subj_dir = raw_dir / f"id_{subj_idx:03d}"
        subj_dir.mkdir()
        for var_idx in range(8):
            img = _generate_patterned_face(subj_idx, var_idx, size=64)
            imsave(subj_dir / f"{var_idx}.png", img, check_contrast=False)

    build_and_save_all_splits(
        dataset_dir=raw_dir,
        output_dir=splits_dir,
        n_identities=10,
        train_ratio=0.60,
        val_ratio=0.20,
        test_ratio=0.20,
        n_val_pairs=12,
        n_test_pairs=12,
        seed=42,
        base_dir=tmp_path,
    )

    out = run_baseline_suite(
        split_path=splits_dir / "split.json",
        pairs_val_path=splits_dir / "pairs_val.json",
        pairs_test_path=splits_dir / "pairs_test.json",
        preprocess_config_path=PREPROCESS_JSON,
        reports_dir=reports_dir,
        methods=("hog", "lbp", "hog_lbp"),
        seed=42,
        base_dir=tmp_path,
    )

    csv_path = pathlib.Path(out["csv_path"])
    png_path = pathlib.Path(out["png_path"])
    json_path = pathlib.Path(out["json_path"])

    assert csv_path.exists() and csv_path.stat().st_size > 0
    assert png_path.exists() and png_path.stat().st_size > 0
    assert json_path.exists() and json_path.stat().st_size > 0

    with open(csv_path, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == 3
    assert {r["method"] for r in rows} == {"hog", "lbp", "hog_lbp"}
    for r in rows:
        for col in (
            "cls_top1_acc",
            "val_threshold",
            "test_far",
            "test_frr",
            "test_eer",
            "test_roc_auc",
            "test_tar_far_1pct",
            "test_verif_acc",
        ):
            assert r[col] != ""

    summary = json.loads(json_path.read_text(encoding="utf-8"))
    assert set(summary["methods"].keys()) == {"hog", "lbp", "hog_lbp"}
