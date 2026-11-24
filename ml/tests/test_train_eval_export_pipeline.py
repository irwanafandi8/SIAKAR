"""
test_train_eval_export_pipeline.py — Uji integrasi cepat (dry-run 1-2 step dummy) untuk
seluruh alur ML5 & ML6 (T-201 s.d. T-204):
1. train_embedding_pipeline (checkpoint tiap epoch + resume + ablasi cosface/no-aug)
2. evaluate_cnn_pipeline (klasifikasi A + ambang EER B -> threshold.json + verifikasi C + analysis.md)
3. export_and_verify_pipeline (siakar_embedding.tflite tanpa kepala softmax + paritas >= 0.999
   + golden_vectors.json + penyalinan ke struktur mobile mock).
"""

from __future__ import annotations

import csv
import json
import pathlib
import sys

import numpy as np
from PIL import Image

_ML_ROOT = pathlib.Path(__file__).parent.parent
_SRC_DIR = _ML_ROOT / "src"
if str(_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_SRC_DIR))

from siakar_ml.data.split import build_and_save_all_splits
from siakar_ml.evaluate import evaluate_cnn_pipeline
from siakar_ml.export_tflite import export_and_verify_pipeline
from siakar_ml.train_embedding import train_embedding_pipeline

PREPROCESS_JSON = _ML_ROOT / "artifacts" / "preprocess.json"


def _create_tiny_synthetic_dataset(root: pathlib.Path, n_identities: int = 8, n_imgs: int = 4) -> pathlib.Path:
    raw_dir = root / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(77)

    for sid in range(n_identities):
        sdir = raw_dir / f"id_{sid:03d}"
        sdir.mkdir()
        for k in range(n_imgs):
            arr = rng.integers(0, 256, size=(64, 64, 3), dtype=np.uint8)
            Image.fromarray(arr).save(sdir / f"{k}.png", format="PNG")
    return raw_dir


def test_dry_run_train_resume_ablation_evaluate_export_and_golden_vectors(tmp_path: pathlib.Path) -> None:
    raw_dir = _create_tiny_synthetic_dataset(tmp_path, n_identities=8, n_imgs=4)
    splits_dir = tmp_path / "splits"
    ckpt_dir = tmp_path / "checkpoints"
    reports_dir = tmp_path / "reports"
    artifacts_dir = tmp_path / "artifacts"

    build_and_save_all_splits(
        dataset_dir=raw_dir,
        output_dir=splits_dir,
        n_identities=8,
        train_ratio=0.50,
        val_ratio=0.25,
        test_ratio=0.25,
        n_val_pairs=6,
        n_test_pairs=6,
        seed=42,
        base_dir=tmp_path,
    )

    split_json = splits_dir / "split.json"
    pairs_val = splits_dir / "pairs_val.json"
    pairs_test = splits_dir / "pairs_test.json"

    # 1. Dry-run pelatihan epoch 1 (maks 2 step dummy)
    train_model_path = artifacts_dir / "embedding_training.keras"
    backbone_model_path = artifacts_dir / "embedding_backbone.keras"

    res_ep1 = train_embedding_pipeline(
        split_path=split_json,
        preprocess_config_path=PREPROCESS_JSON,
        checkpoint_dir=ckpt_dir,
        reports_dir=reports_dir,
        training_model_out=train_model_path,
        backbone_model_out=backbone_model_path,
        run_name="main_cnn",
        embedding_dim=128,
        head_type="softmax",
        use_augmentation=True,
        batch_size=4,
        epochs=1,
        max_steps_per_epoch=2,
        max_val_steps=1,
        seed=42,
        base_dir=tmp_path,
    )
    assert res_ep1["epochs_ran"] == 1
    assert train_model_path.exists()
    assert backbone_model_path.exists()
    assert (ckpt_dir / "main_cnn_epoch_001.keras").exists()

    # 2. Dry-run resume ke epoch 2 dari direktori checkpoint
    res_ep2 = train_embedding_pipeline(
        split_path=split_json,
        preprocess_config_path=PREPROCESS_JSON,
        checkpoint_dir=ckpt_dir,
        reports_dir=reports_dir,
        training_model_out=train_model_path,
        backbone_model_out=backbone_model_path,
        run_name="main_cnn",
        batch_size=4,
        epochs=2,
        resume_from=ckpt_dir,
        max_steps_per_epoch=1,
        max_val_steps=1,
        seed=42,
        base_dir=tmp_path,
    )
    assert res_ep2["initial_epoch"] == 1
    assert res_ep2["epochs_ran"] == 1
    assert (ckpt_dir / "main_cnn_epoch_002.keras").exists()

    # 3. Dry-run satu varian ablasi (CosFace margin loss + tanpa augmentasi, 1 step)
    abl_model_path = artifacts_dir / "abl_cosface_training.keras"
    abl_back_path = artifacts_dir / "abl_cosface_backbone.keras"
    train_embedding_pipeline(
        split_path=split_json,
        preprocess_config_path=PREPROCESS_JSON,
        checkpoint_dir=ckpt_dir,
        reports_dir=reports_dir,
        training_model_out=abl_model_path,
        backbone_model_out=abl_back_path,
        run_name="abl_cosface",
        embedding_dim=128,
        head_type="cosface",
        use_augmentation=False,
        batch_size=4,
        epochs=1,
        max_steps_per_epoch=1,
        max_val_steps=1,
        seed=42,
        base_dir=tmp_path,
    )
    assert abl_model_path.exists()

    # 4. Evaluasi main_cnn (-> threshold.json) & abl_cosface (-> ablation_comparison.csv & analysis.md)
    threshold_json = artifacts_dir / "threshold.json"
    eval_main = evaluate_cnn_pipeline(
        model_path=train_model_path,
        split_path=split_json,
        pairs_val_path=pairs_val,
        pairs_test_path=pairs_test,
        preprocess_config_path=PREPROCESS_JSON,
        reports_dir=reports_dir,
        threshold_output_path=threshold_json,
        run_name="main_cnn",
        batch_size=4,
        save_threshold=True,
        base_dir=tmp_path,
    )
    assert threshold_json.exists()
    thr_payload = json.loads(threshold_json.read_text(encoding="utf-8"))
    assert "threshold" in thr_payload and "eer" in thr_payload

    evaluate_cnn_pipeline(
        model_path=abl_model_path,
        split_path=split_json,
        pairs_val_path=pairs_val,
        pairs_test_path=pairs_test,
        preprocess_config_path=PREPROCESS_JSON,
        reports_dir=reports_dir,
        threshold_output_path=threshold_json,
        run_name="abl_cosface",
        batch_size=4,
        save_threshold=False,
        base_dir=tmp_path,
    )

    ablation_csv = pathlib.Path(eval_main["ablation_csv_path"])
    with open(ablation_csv, "r", encoding="utf-8") as f:
        abl_rows = list(csv.DictReader(f))
    assert {r["run_name"] for r in abl_rows} == {"main_cnn", "abl_cosface"}

    analysis_text = (reports_dir / "analysis.md").read_text(encoding="utf-8")
    assert "Selisih Domain" in analysis_text
    assert "main_cnn" in analysis_text and "abl_cosface" in analysis_text

    # 5. Ekspor ke siakar_embedding.tflite + uji paritas >= 0.999 + golden vectors + salin ke mock mobile
    tflite_out = artifacts_dir / "siakar_embedding.tflite"
    golden_dir = artifacts_dir / "golden"
    mock_mobile_models = tmp_path / "mock_mobile" / "assets" / "models"
    mock_mobile_golden = tmp_path / "mock_mobile" / "test" / "golden"

    exp_res = export_and_verify_pipeline(
        keras_model_or_path=train_model_path,
        output_tflite_path=tflite_out,
        preprocess_config_path=PREPROCESS_JSON,
        golden_dir=golden_dir,
        expected_embedding_dim=128,
        n_golden_samples=3,
        min_parity_cosine=0.999,
        copy_to_mobile=True,
        threshold_json_path=threshold_json,
        mobile_models_dir=mock_mobile_models,
        mobile_golden_dir=mock_mobile_golden,
    )

    assert exp_res["min_parity_cosine"] >= 0.999
    assert tflite_out.exists()
    assert (mock_mobile_models / "siakar_embedding.tflite").exists()
    assert (mock_mobile_models / "preprocess.json").exists()
    assert (mock_mobile_models / "threshold.json").exists()
    assert (mock_mobile_golden / "golden_vectors.json").exists()
    assert (mock_mobile_golden / "sample_0.png").exists()

    manifest = json.loads((golden_dir / "golden_vectors.json").read_text(encoding="utf-8"))
    assert manifest["embedding_dim"] == 128
    assert len(manifest["samples"]) == 3
    for s in manifest["samples"]:
        assert len(s["reference_embedding"]) == 128
        assert s["keras_vs_tflite_cosine"] >= 0.999
