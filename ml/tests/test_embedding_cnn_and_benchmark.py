"""
test_embedding_cnn_and_benchmark.py — Unit test arsitektur CNN embedding dari nol,
loader tf.data sesuai preprocess.json, dan dry-run 1 batch benchmark (T-107).

Catatan: Hanya mengeksekusi 1 batch dummy (max_steps=1), TIDAK menjalankan 1 epoch penuh.
"""

from __future__ import annotations

import json
import pathlib
import sys

import numpy as np
import pytest
from PIL import Image
import tensorflow as tf
from tensorflow import keras

_ML_ROOT = pathlib.Path(__file__).parent.parent
_SRC_DIR = _ML_ROOT / "src"
if str(_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_SRC_DIR))

from siakar_ml.benchmark_epoch import (
    get_process_memory_mb,
    propose_hyperparameters,
    run_benchmark,
    run_single_train_step,
)
from siakar_ml.data.dataset_loader import create_classification_dataset
from siakar_ml.models.embedding_cnn import (
    build_embedding_backbone,
    build_training_model,
    extract_embedding_backbone,
)
from siakar_ml.preprocess import load_preprocess_config

PREPROCESS_JSON = _ML_ROOT / "artifacts" / "preprocess.json"


def test_backbone_and_training_model_tensor_shapes_and_l2_norm() -> None:
    cfg = load_preprocess_config(str(PREPROCESS_JSON))
    input_size = int(cfg["input_size"])

    backbone = build_embedding_backbone(input_size=input_size, embedding_dim=128, seed=42)
    assert backbone.input_shape == (None, input_size, input_size, 3)
    assert backbone.output_shape == (None, 128)

    dummy_batch = tf.random.uniform((4, input_size, input_size, 3), minval=-1.0, maxval=1.0, seed=7)
    emb = backbone(dummy_batch, training=False).numpy()
    assert emb.shape == (4, 128)
    assert emb.dtype == np.float32
    norms = np.linalg.norm(emb, axis=1)
    assert np.allclose(norms, 1.0, atol=1e-5)

    train_model = build_training_model(num_classes=5, input_size=input_size, embedding_dim=128, seed=42)
    probs = train_model(dummy_batch, training=False).numpy()
    assert probs.shape == (4, 5)
    assert np.allclose(np.sum(probs, axis=1), 1.0, atol=1e-5)

    extracted = extract_embedding_backbone(train_model)
    extracted_emb = extracted(dummy_batch, training=False).numpy()
    assert extracted_emb.shape == (4, 128)
    assert np.allclose(np.linalg.norm(extracted_emb, axis=1), 1.0, atol=1e-5)

    # Pastikan hanya memakai operasi standar TFLite builtin (ML_SPEC §3.1 R-06)
    converter = tf.lite.TFLiteConverter.from_keras_model(extracted)
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    tflite_bytes = converter.convert()
    assert len(tflite_bytes) > 1024


def test_single_batch_forward_backward_pass_updates_weights() -> None:
    cfg = load_preprocess_config(str(PREPROCESS_JSON))
    input_size = int(cfg["input_size"])

    model = build_training_model(num_classes=3, input_size=input_size, embedding_dim=128, seed=42)
    optimizer = keras.optimizers.Adam(learning_rate=1e-3)
    loss_fn = keras.losses.SparseCategoricalCrossentropy()

    x_batch = tf.random.uniform((4, input_size, input_size, 3), minval=-1.0, maxval=1.0, seed=11)
    y_batch = tf.constant([0, 1, 2, 1], dtype=tf.int32)

    weights_before = [w.numpy().copy() for w in model.trainable_variables]
    loss_val, probs = run_single_train_step(model, optimizer, loss_fn, x_batch, y_batch)
    weights_after = [w.numpy() for w in model.trainable_variables]

    assert np.isfinite(loss_val) and loss_val > 0.0
    assert probs.shape == (4, 3)
    assert any(not np.allclose(b, a) for b, a in zip(weights_before, weights_after))


def test_tf_data_loader_and_one_batch_dry_run_benchmark(tmp_path: pathlib.Path) -> None:
    cfg = load_preprocess_config(str(PREPROCESS_JSON))
    input_size = int(cfg["input_size"])

    # Buat 4 citra sintetis kecil di tmp_path untuk menguji pipeline tf.data dari disk
    rng = np.random.default_rng(99)
    samples = []
    for idx in range(4):
        arr = rng.integers(0, 256, size=(120, 120, 3), dtype=np.uint8)
        img_path = tmp_path / f"sample_{idx}.png"
        Image.fromarray(arr).save(img_path, format="PNG")
        samples.append({"path": f"sample_{idx}.png", "label": idx % 2})

    ds = create_classification_dataset(
        samples=samples,
        preprocess_cfg=cfg,
        batch_size=4,
        training=True,
        seed=42,
        base_dir=tmp_path,
    )

    for batch_x, batch_y in ds.take(1):
        assert batch_x.shape == (4, input_size, input_size, 3)
        assert batch_x.dtype == tf.float32
        assert float(tf.reduce_min(batch_x).numpy()) >= -1.0 - 1e-5
        assert float(tf.reduce_max(batch_x).numpy()) <= 1.0 + 1e-5
        assert batch_y.shape == (4,)

    reports_dir = tmp_path / "reports"
    report = run_benchmark(
        dataset=ds,
        num_classes=2,
        input_size=input_size,
        embedding_dim=128,
        max_steps=1,
        reports_dir=reports_dir,
    )

    mem_info = get_process_memory_mb()
    assert mem_info["peak_rss_mb"] > 0.0
    assert report["config_tested"]["steps_executed"] == 1
    assert report["config_tested"]["total_images_processed"] == 4
    assert report["memory"]["peak_rss_mb"] > 0.0
    assert (reports_dir / "benchmark_1epoch.json").exists()
    assert (reports_dir / "benchmark_1epoch.md").exists()

    loaded = json.loads((reports_dir / "benchmark_1epoch.json").read_text(encoding="utf-8"))
    assert "recommended_n_identities" in loaded["proposal"]
    assert "recommended_input_size" in loaded["proposal"]

    prop_fast = propose_hyperparameters(measured_img_per_sec=120.0, measured_input_size=112, peak_ram_mb=900.0)
    prop_slow = propose_hyperparameters(measured_img_per_sec=4.0, measured_input_size=112, peak_ram_mb=900.0)
    assert prop_fast["recommended_n_identities"] >= prop_slow["recommended_n_identities"]
