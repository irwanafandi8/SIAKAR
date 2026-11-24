"""
train_detector.py — Pelatihan, Evaluasi, Ekspor TFLite, & Golden Samples Detektor Wajah SIAKAR (ML7 / T-205).

Sesuai ML_SPEC.md §3.3 & §3.4:
- Dibangun & dilatih dari nol (tanpa ML Kit, tanpa Haar/DNN OpenCV, tanpa bobot pretrained).
- Sampel positif: citra wajah sintetis DigiFace ditempatkan pada kanvas latar dengan variasi posisi
  (cx, cy) dan skala (w, h) untuk meniru wajah yang berada di dalam area oval panduan kamera,
  menghasilkan target [1.0, cx, cy, w, h].
- Sampel negatif: citra non-wajah dari data/negatives (ditambah potongan ekstrem di luar wajah
  dengan IoU < 0.10), menghasilkan target [0.0, 0.0, 0.0, 0.0, 0.0].
- Evaluasi pada data validasi (pemilihan ambang F1 optimal -> detector_threshold.json), data uji
  (akurasi, presisi, recall, F1, ROC AUC, rata-rata IoU kotak wajah), serta skenario tangkapan
  kamera sintetis.
- Ekspor ke ml/artifacts/detector.tflite (TFLITE_BUILTINS) beserta verifikasi paritas & golden samples
  di ml/artifacts/golden_detector/detector_golden.json.
"""

from __future__ import annotations

import argparse
import json
import random
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, Sequence, Tuple

import numpy as np
from PIL import Image
import tensorflow as tf
from tensorflow import keras
import yaml

from siakar_ml.data.prepare_negatives import (
    generate_procedural_nonface,
    generate_synthetic_negatives,
    list_negative_images,
)
from siakar_ml.data.split import list_identity_images
from siakar_ml.evaluate import _roc_curve_and_auc, save_metrics_csv
from siakar_ml.models.detector_cnn import (
    DETECTOR_CUSTOM_OBJECTS,
    DetectorFaceAccuracy,
    DetectorMultiTaskLoss,
    build_detector_model,
    compute_iou_cxcywh,
)
from siakar_ml.preprocess import (
    bilinear_resize_raw,
    crop_to_oval_region,
    float_to_uint8_floor_half_up,
    load_preprocess_config,
    normalize_image,
    resize_image,
)


def _resize_hw_u8(image_rgb: np.ndarray, out_h: int, out_w: int) -> np.ndarray:
    """Resize citra RGB ke [out_h, out_w, 3] uint8 memakai bilinear murni + floor_half_up."""
    return float_to_uint8_floor_half_up(bilinear_resize_raw(image_rgb, out_height=out_h, out_width=out_w))


def preprocess_for_detector(
    image_rgb: np.ndarray,
    preprocess_cfg: Dict[str, Any],
    detector_size: int = 64,
    already_cropped: bool = False,
) -> np.ndarray:
    """Praproses citra untuk detektor memakai kontrak bilinear murni D-32."""
    patch = image_rgb if already_cropped else crop_to_oval_region(image_rgb, preprocess_cfg)
    resized_u8 = resize_image(patch, detector_size)
    mean = float(preprocess_cfg.get("normalization_mean", 127.5))
    std = float(preprocess_cfg.get("normalization_std", 127.5))
    return normalize_image(resized_u8, mean=mean, std=std)


def compose_face_in_oval_patch(
    face_rgb: np.ndarray,
    bg_rgb: np.ndarray,
    out_size: int,
    rng: random.Random,
    cx_range: Tuple[float, float] = (0.34, 0.66),
    cy_range: Tuple[float, float] = (0.34, 0.66),
    scale_range: Tuple[float, float] = (0.52, 0.92),
) -> Tuple[np.ndarray, np.ndarray]:
    """Tempelkan potongan wajah di dalam kanvas latar pada posisi/skala terkontrol.

    Returns:
        Tuple ``(patch_u8 [out_size, out_size, 3], target [5] -> [1.0, cx, cy, w, h])``.
    """
    canvas = resize_image(bg_rgb, out_size).copy()

    box_w_ratio = rng.uniform(scale_range[0], scale_range[1])
    box_h_ratio = min(0.96, box_w_ratio * rng.uniform(0.92, 1.08))

    half_w = box_w_ratio / 2.0
    half_h = box_h_ratio / 2.0
    min_cx = max(cx_range[0], half_w + 0.02)
    max_cx = min(cx_range[1], 1.0 - half_w - 0.02)
    min_cy = max(cy_range[0], half_h + 0.02)
    max_cy = min(cy_range[1], 1.0 - half_h - 0.02)

    cx = rng.uniform(min_cx, max_cx) if min_cx < max_cx else 0.5
    cy = rng.uniform(min_cy, max_cy) if min_cy < max_cy else 0.5

    pw = max(8, int(round(box_w_ratio * out_size)))
    ph = max(8, int(round(box_h_ratio * out_size)))
    x1 = int(np.clip(round(cx * out_size - pw / 2.0), 0, out_size - pw))
    y1 = int(np.clip(round(cy * out_size - ph / 2.0), 0, out_size - ph))
    x2 = x1 + pw
    y2 = y1 + ph

    canvas[y1:y2, x1:x2] = _resize_hw_u8(face_rgb, ph, pw)

    actual_cx = ((x1 + x2) / 2.0) / out_size
    actual_cy = ((y1 + y2) / 2.0) / out_size
    actual_w = float(pw) / out_size
    actual_h = float(ph) / out_size

    target = np.array([1.0, actual_cx, actual_cy, actual_w, actual_h], dtype=np.float32)
    return canvas, target


def collect_detector_splits(
    positive_dir: str | Path,
    negative_dir: str | Path,
    max_positives: int = 4000,
    n_synthetic_negatives: int = 2000,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    seed: int = 42,
) -> Dict[str, Dict[str, List[Path]]]:
    """Bagi citra positif (per folder identitas) dan citra negatif ke train/val/test."""
    pos_root = Path(positive_dir)
    neg_root = Path(negative_dir)
    rng = random.Random(seed)

    if not pos_root.exists():
        raise FileNotFoundError(
            f"Direktori wajah positif tidak ditemukan: {pos_root}. "
            "Pastikan subset DigiFace-1M tersedia di ml/data/raw/digiface."
        )

    subj_dirs = sorted([d for d in pos_root.iterdir() if d.is_dir()], key=lambda p: p.name)
    valid_subjects: List[List[Path]] = []
    for d in subj_dirs:
        imgs = [Path(p) for p in list_identity_images(d)]
        if imgs:
            valid_subjects.append(imgs)

    if len(valid_subjects) < 3:
        raise ValueError(f"Minimal 3 folder identitas wajah dibutuhkan di {pos_root}.")

    rng.shuffle(valid_subjects)
    n_subj = len(valid_subjects)
    n_val_s = max(1, int(round(n_subj * val_ratio)))
    n_test_s = max(1, int(round(n_subj * test_ratio)))
    n_train_s = max(1, n_subj - n_val_s - n_test_s)

    train_subj = valid_subjects[:n_train_s]
    val_subj = valid_subjects[n_train_s : n_train_s + n_val_s]
    test_subj = valid_subjects[n_train_s + n_val_s :]

    def _flatten_and_cap(groups: List[List[Path]], cap: int) -> List[Path]:
        flat = [img for g in groups for img in g]
        rng.shuffle(flat)
        return flat[:cap]

    train_cap = max(2, int(round(max_positives * (1.0 - val_ratio - test_ratio))))
    val_cap = max(2, int(round(max_positives * val_ratio)))
    test_cap = max(2, int(round(max_positives * test_ratio)))

    pos_train = _flatten_and_cap(train_subj, train_cap)
    pos_val = _flatten_and_cap(val_subj, val_cap)
    pos_test = _flatten_and_cap(test_subj, test_cap)

    neg_files = list_negative_images(neg_root)
    min_needed_neg = len(pos_train) + len(pos_val) + len(pos_test)
    if len(neg_files) < max(6, min(n_synthetic_negatives, min_needed_neg)):
        generate_synthetic_negatives(
            output_dir=neg_root,
            n_images=max(6, max(n_synthetic_negatives, min_needed_neg)),
            seed=seed,
        )
        neg_files = list_negative_images(neg_root)

    rng.shuffle(neg_files)
    n_neg = len(neg_files)
    n_neg_val = max(1, int(round(n_neg * val_ratio)))
    n_neg_test = max(1, int(round(n_neg * test_ratio)))
    n_neg_train = max(1, n_neg - n_neg_val - n_neg_test)

    neg_train = neg_files[: min(n_neg_train, len(pos_train) * 2)]
    neg_val = neg_files[n_neg_train : n_neg_train + min(n_neg_val, max(2, len(pos_val) * 2))]
    neg_test = neg_files[n_neg_train + n_neg_val : n_neg_train + n_neg_val + min(n_neg_test, max(2, len(pos_test) * 2))]

    return {
        "train": {"pos": pos_train, "neg": neg_train},
        "val": {"pos": pos_val, "neg": neg_val},
        "test": {"pos": pos_test, "neg": neg_test},
    }


def _load_rgb_u8(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.uint8)


def build_detector_tf_dataset(
    pos_paths: Sequence[Path],
    neg_paths: Sequence[Path],
    input_size: int = 64,
    include_bbox: bool = True,
    batch_size: int = 32,
    training: bool = False,
    seed: int = 42,
) -> Tuple[tf.data.Dataset, int]:
    """Buat ``tf.data.Dataset`` streaming seimbang positif & negatif tanpa memuat semua ke RAM."""
    entries: List[Tuple[int, Path]] = [(1, p) for p in pos_paths] + [(0, p) for p in neg_paths]
    if not entries:
        raise ValueError("Daftar citra detektor kosong.")

    out_dim = 5 if include_bbox else 1

    def _gen() -> Iterator[Tuple[np.ndarray, np.ndarray]]:
        local_rng = random.Random(seed)
        order = list(entries)
        if training:
            local_rng.shuffle(order)

        for idx, (is_pos, img_path) in enumerate(order):
            raw = _load_rgb_u8(img_path)
            if is_pos == 1:
                bg_path = neg_paths[idx % len(neg_paths)] if neg_paths else None
                bg = _load_rgb_u8(bg_path) if bg_path is not None else generate_procedural_nonface(idx, size=input_size, seed=seed)
                patch_u8, target_5 = compose_face_in_oval_patch(raw, bg, out_size=input_size, rng=local_rng)
                x_norm = normalize_image(patch_u8)
                y_target = target_5 if include_bbox else target_5[:1]
            else:
                patch_u8 = resize_image(raw, input_size)
                x_norm = normalize_image(patch_u8)
                y_target = np.zeros((out_dim,), dtype=np.float32)

            if training and local_rng.random() < 0.5:
                x_norm = np.ascontiguousarray(x_norm[:, ::-1, :])
                if include_bbox and is_pos == 1:
                    y_target = y_target.copy()
                    y_target[1] = 1.0 - y_target[1]

            yield x_norm.astype(np.float32), y_target.astype(np.float32)

    output_signature = (
        tf.TensorSpec(shape=(input_size, input_size, 3), dtype=tf.float32),
        tf.TensorSpec(shape=(out_dim,), dtype=tf.float32),
    )
    ds = tf.data.Dataset.from_generator(_gen, output_signature=output_signature)
    ds = ds.batch(batch_size, drop_remainder=False).prefetch(tf.data.AUTOTUNE)
    return ds, len(entries)


def _select_best_f1_threshold(scores: np.ndarray, labels: np.ndarray) -> Dict[str, float]:
    candidates = np.linspace(0.15, 0.85, 71)
    best_thr = 0.50
    best_f1 = -1.0
    best_prec = 0.0
    best_rec = 0.0
    best_acc = 0.0

    for thr in candidates:
        preds = (scores >= thr).astype(np.int32)
        tp = int(np.sum((preds == 1) & (labels == 1)))
        fp = int(np.sum((preds == 1) & (labels == 0)))
        fn = int(np.sum((preds == 0) & (labels == 1)))

        prec = tp / max(tp + fp, 1)
        rec = tp / max(tp + fn, 1)
        f1 = (2.0 * prec * rec) / max(prec + rec, 1e-12)
        acc = float(np.mean(preds == labels))

        if f1 > best_f1:
            best_f1 = float(f1)
            best_thr = float(thr)
            best_prec = float(prec)
            best_rec = float(rec)
            best_acc = acc

    return {
        "threshold": round(best_thr, 4),
        "f1": round(best_f1, 4),
        "precision": round(best_prec, 4),
        "recall": round(best_rec, 4),
        "accuracy": round(best_acc, 4),
    }


def _evaluate_predictions(
    preds_raw: np.ndarray,
    targets_raw: np.ndarray,
    threshold: float,
) -> Dict[str, Any]:
    scores = preds_raw[:, 0].astype(np.float64)
    labels = (targets_raw[:, 0] >= 0.5).astype(np.int32)

    bin_preds = (scores >= threshold).astype(np.int32)
    tp = int(np.sum((bin_preds == 1) & (labels == 1)))
    fp = int(np.sum((bin_preds == 1) & (labels == 0)))
    fn = int(np.sum((bin_preds == 0) & (labels == 1)))
    tn = int(np.sum((bin_preds == 0) & (labels == 0)))

    precision = float(tp / max(tp + fp, 1))
    recall = float(tp / max(tp + fn, 1))
    f1 = float((2.0 * precision * recall) / max(precision + recall, 1e-12))
    accuracy = float((tp + tn) / max(len(labels), 1))

    if len(np.unique(labels)) >= 2:
        _, _, _, roc_auc = _roc_curve_and_auc(labels, scores)
    else:
        roc_auc = 0.0

    mean_iou: Optional[float] = None
    bbox_mae: Optional[float] = None
    if preds_raw.shape[1] >= 5 and np.any(labels == 1):
        pos_idx = np.where(labels == 1)[0]
        ious = [compute_iou_cxcywh(targets_raw[i, 1:5], preds_raw[i, 1:5]) for i in pos_idx]
        mean_iou = float(np.mean(ious))
        bbox_mae = float(np.mean(np.abs(targets_raw[pos_idx, 1:5] - preds_raw[pos_idx, 1:5])))

    return {
        "threshold": round(float(threshold), 4),
        "accuracy": round(accuracy, 4),
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
        "roc_auc": round(float(roc_auc), 4),
        "mean_bbox_iou": round(mean_iou, 4) if mean_iou is not None else None,
        "bbox_mae": round(bbox_mae, 4) if bbox_mae is not None else None,
        "n_samples": int(len(labels)),
    }


def _make_synthetic_camera_frame(mode: str, sample_face: Optional[np.ndarray] = None, seed: int = 42) -> np.ndarray:
    """Buat tangkapan kamera potret sintetis 160x128 dengan/tanpa wajah di area oval tengah."""
    bg = generate_procedural_nonface(idx=10 if mode.startswith("pos") else 22, size=160, seed=seed)
    frame = bg[:, :128, :].copy()

    if sample_face is None:
        yy, xx = np.mgrid[0:64, 0:64].astype(np.float32) / 63.0
        r_d = np.sqrt(((xx - 0.5) / 0.38) ** 2 + ((yy - 0.5) / 0.45) ** 2)
        skin = np.clip(1.0 - 0.6 * r_d, 0.2, 1.0)
        eyes = np.exp(-((yy - 0.40) ** 2) / 0.004) * (
            np.exp(-((xx - 0.35) ** 2) / 0.006) + np.exp(-((xx - 0.65) ** 2) / 0.006)
        )
        val = np.clip((skin - 0.55 * eyes) * 255.0, 0, 255).astype(np.uint8)
        sample_face = np.stack([val, (val * 0.85).astype(np.uint8), (val * 0.75).astype(np.uint8)], axis=-1)

    if mode == "pos_centered":
        face_rs = _resize_hw_u8(sample_face, 88, 72)
        frame[36:124, 28:100] = face_rs
    elif mode == "pos_shifted":
        face_rs = _resize_hw_u8(sample_face, 76, 62)
        frame[46:122, 42:104] = face_rs
    elif mode == "neg_grid":
        frame = generate_procedural_nonface(idx=2, size=160, seed=seed + 5)[:, :128, :]
    elif mode == "neg_gradient":
        frame = generate_procedural_nonface(idx=0, size=160, seed=seed + 9)[:, :128, :]

    return frame


def export_detector_tflite_and_golden(
    keras_model: keras.Model,
    output_tflite_path: str | Path,
    preprocess_config_path: str | Path,
    golden_dir: str | Path,
    threshold: float = 0.50,
    sample_face_rgb: Optional[np.ndarray] = None,
    copy_to_mobile: bool = False,
    threshold_json_path: Optional[str | Path] = None,
    mobile_models_dir: Optional[str | Path] = None,
    mobile_golden_dir: Optional[str | Path] = None,
) -> Dict[str, Any]:
    """Ekspor model detektor ke .tflite, verifikasi paritas, dan simpan golden samples."""
    preprocess_cfg = load_preprocess_config(str(preprocess_config_path))
    det_size = int(keras_model.input_shape[1])

    converter = tf.lite.TFLiteConverter.from_keras_model(keras_model)
    converter.optimizations = []
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    tflite_bytes = converter.convert()

    out_tflite = Path(output_tflite_path)
    out_tflite.parent.mkdir(parents=True, exist_ok=True)
    out_tflite.write_bytes(tflite_bytes)

    interpreter = tf.lite.Interpreter(model_path=str(out_tflite))
    interpreter.allocate_tensors()
    in_det = interpreter.get_input_details()
    out_det = interpreter.get_output_details()

    out_golden = Path(golden_dir)
    out_golden.mkdir(parents=True, exist_ok=True)

    modes = [
        ("pos_centered", 1),
        ("pos_shifted", 1),
        ("neg_grid", 0),
        ("neg_gradient", 0),
    ]

    samples_manifest: List[Dict[str, Any]] = []
    max_diffs: List[float] = []

    for mode_name, expected_label in modes:
        frame = _make_synthetic_camera_frame(mode_name, sample_face=sample_face_rgb)
        img_file = f"{mode_name}.png"
        img_path = out_golden / img_file
        Image.fromarray(frame).save(img_path, format="PNG")

        reloaded = np.asarray(Image.open(img_path).convert("RGB"), dtype=np.uint8)
        inp = np.expand_dims(
            preprocess_for_detector(reloaded, preprocess_cfg, detector_size=det_size),
            axis=0,
        ).astype(np.float32)

        k_out = keras_model(inp, training=False).numpy().reshape(-1).astype(np.float32)
        interpreter.set_tensor(in_det[0]["index"], inp)
        interpreter.invoke()
        t_out = interpreter.get_tensor(out_det[0]["index"]).reshape(-1).astype(np.float32)

        diff = float(np.max(np.abs(k_out - t_out)))
        if diff > 1e-3:
            raise AssertionError(f"Selisih Keras vs TFLite detektor terlalu besar ({diff:.6f}) pada {img_file}.")
        max_diffs.append(diff)

        score = float(t_out[0])
        bbox = [round(float(v), 6) for v in t_out[1:5].tolist()] if t_out.size >= 5 else None

        samples_manifest.append(
            {
                "id": mode_name,
                "image_file": img_file,
                "image_width": int(frame.shape[1]),
                "image_height": int(frame.shape[0]),
                "synthetic_expected_label": expected_label,
                "detector_input_shape": list(inp.shape),
                "keras_output": [round(float(v), 6) for v in k_out.tolist()],
                "tflite_output": [round(float(v), 6) for v in t_out.tolist()],
                "face_score": round(score, 6),
                "bbox_cxcywh": bbox,
                "predicted_has_face": bool(score >= threshold),
                "max_abs_diff": round(diff, 7),
            }
        )

    manifest = {
        "generated_at": datetime.now().isoformat(),
        "model_file": out_tflite.name,
        "input_size": det_size,
        "output_format": ["face_score", "cx", "cy", "w", "h"] if int(keras_model.output_shape[-1]) == 5 else ["face_score"],
        "threshold": round(float(threshold), 4),
        "max_keras_tflite_abs_diff": round(float(max(max_diffs)), 7),
        "preprocess_oval_config": preprocess_cfg,
        "samples": samples_manifest,
    }
    manifest_path = out_golden / "detector_golden.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    copied: List[str] = []
    if copy_to_mobile and mobile_models_dir is not None:
        mob_models = Path(mobile_models_dir)
        mob_models.mkdir(parents=True, exist_ok=True)
        dst_m = mob_models / out_tflite.name
        shutil.copy2(out_tflite, dst_m)
        copied.append(str(dst_m))

        if threshold_json_path is not None and Path(threshold_json_path).exists():
            dst_t = mob_models / Path(threshold_json_path).name
            shutil.copy2(threshold_json_path, dst_t)
            copied.append(str(dst_t))

        if mobile_golden_dir is not None:
            mob_gold = Path(mobile_golden_dir)
            mob_gold.mkdir(parents=True, exist_ok=True)
            for item in out_golden.iterdir():
                if item.is_file():
                    dst_g = mob_gold / item.name
                    shutil.copy2(item, dst_g)
                    copied.append(str(dst_g))

    return {
        "tflite_path": str(out_tflite),
        "tflite_size_bytes": len(tflite_bytes),
        "golden_manifest_path": str(manifest_path),
        "max_abs_diff": float(max(max_diffs)),
        "copied_to_mobile": copied,
    }


def run_detector_pipeline(
    positive_dir: str | Path,
    negative_dir: str | Path,
    preprocess_config_path: str | Path,
    checkpoint_dir: str | Path,
    model_output_path: str | Path,
    tflite_output_path: str | Path,
    threshold_output_path: str | Path,
    golden_dir: str | Path,
    reports_dir: str | Path,
    input_size: int = 64,
    filters: Sequence[int] = (32, 64, 128),
    dense_units: int = 64,
    include_bbox: bool = True,
    bbox_loss_weight: float = 2.0,
    max_positives: int = 4000,
    n_synthetic_negatives: int = 2000,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    batch_size: int = 32,
    epochs: int = 25,
    learning_rate: float = 1e-3,
    min_learning_rate: float = 1e-6,
    early_stopping_patience: int = 6,
    reduce_lr_patience: int = 3,
    reduce_lr_factor: float = 0.5,
    seed: int = 42,
    max_steps_per_epoch: Optional[int] = None,
    max_eval_batches: Optional[int] = None,
    copy_to_mobile: bool = False,
    mobile_models_dir: Optional[str | Path] = None,
    mobile_golden_dir: Optional[str | Path] = None,
) -> Dict[str, Any]:
    """Jalankan alur lengkap ML7: split -> latih detektor -> evaluasi -> ekspor .tflite & golden."""
    tf.random.set_seed(seed)
    np.random.seed(seed)
    random.seed(seed)

    splits = collect_detector_splits(
        positive_dir=positive_dir,
        negative_dir=negative_dir,
        max_positives=max_positives,
        n_synthetic_negatives=n_synthetic_negatives,
        val_ratio=val_ratio,
        test_ratio=test_ratio,
        seed=seed,
    )

    train_ds, _ = build_detector_tf_dataset(
        splits["train"]["pos"],
        splits["train"]["neg"],
        input_size=input_size,
        include_bbox=include_bbox,
        batch_size=batch_size,
        training=True,
        seed=seed,
    )
    val_ds, _ = build_detector_tf_dataset(
        splits["val"]["pos"],
        splits["val"]["neg"],
        input_size=input_size,
        include_bbox=include_bbox,
        batch_size=batch_size,
        training=False,
        seed=seed + 1,
    )
    test_ds, _ = build_detector_tf_dataset(
        splits["test"]["pos"],
        splits["test"]["neg"],
        input_size=input_size,
        include_bbox=include_bbox,
        batch_size=batch_size,
        training=False,
        seed=seed + 2,
    )

    if max_steps_per_epoch is not None:
        train_ds = train_ds.take(max_steps_per_epoch)
    if max_eval_batches is not None:
        val_ds = val_ds.take(max_eval_batches)
        test_ds = test_ds.take(max_eval_batches)

    model = build_detector_model(
        input_size=input_size,
        filters=filters,
        dense_units=dense_units,
        include_bbox=include_bbox,
        seed=seed,
    )
    loss_fn = DetectorMultiTaskLoss(bbox_weight=bbox_loss_weight)
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=learning_rate),
        loss=loss_fn,
        metrics=[DetectorFaceAccuracy(name="face_acc")],
    )

    ckpt_dir = Path(checkpoint_dir)
    ckpt_dir.mkdir(parents=True, exist_ok=True)
    rep_dir = Path(reports_dir)
    rep_dir.mkdir(parents=True, exist_ok=True)

    callbacks: List[keras.callbacks.Callback] = [
        keras.callbacks.ModelCheckpoint(
            filepath=str(ckpt_dir / "detector_epoch_{epoch:03d}.keras"),
            save_best_only=False,
            verbose=0,
        ),
        keras.callbacks.ModelCheckpoint(
            filepath=str(ckpt_dir / "detector_best.keras"),
            monitor="val_loss",
            save_best_only=True,
            verbose=0,
        ),
        keras.callbacks.CSVLogger(str(rep_dir / "detector_training_history.csv")),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=reduce_lr_factor,
            patience=reduce_lr_patience,
            min_lr=min_learning_rate,
            verbose=1,
        ),
        keras.callbacks.EarlyStopping(
            monitor="val_loss",
            patience=early_stopping_patience,
            restore_best_weights=True,
            verbose=1,
        ),
    ]

    model.fit(train_ds, validation_data=val_ds, epochs=epochs, callbacks=callbacks, verbose=1)

    out_keras = Path(model_output_path)
    out_keras.parent.mkdir(parents=True, exist_ok=True)
    model.save(out_keras)

    # Evaluasi pada himpunan validasi -> pilih ambang F1 terbaik
    def _collect_preds_and_targets(ds: tf.data.Dataset) -> Tuple[np.ndarray, np.ndarray]:
        ps: List[np.ndarray] = []
        ts: List[np.ndarray] = []
        for bx, by in ds:
            ps.append(model(bx, training=False).numpy())
            ts.append(by.numpy())
        return np.vstack(ps), np.vstack(ts)

    val_preds, val_targets = _collect_preds_and_targets(val_ds)
    best_val = _select_best_f1_threshold(val_preds[:, 0], (val_targets[:, 0] >= 0.5).astype(np.int32))
    chosen_thr = float(best_val["threshold"])
    val_metrics = _evaluate_predictions(val_preds, val_targets, threshold=chosen_thr)

    thr_out = Path(threshold_output_path)
    thr_out.parent.mkdir(parents=True, exist_ok=True)
    thr_out.write_text(
        json.dumps(
            {
                "threshold": chosen_thr,
                "metric_basis": "F1 maksimum pada himpunan validasi detektor",
                "val_f1": val_metrics["f1"],
                "val_precision": val_metrics["precision"],
                "val_recall": val_metrics["recall"],
                "val_mean_bbox_iou": val_metrics["mean_bbox_iou"],
                "date": datetime.now().isoformat(),
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    # Evaluasi pada himpunan uji dengan ambang tetap dari validasi
    test_preds, test_targets = _collect_preds_and_targets(test_ds)
    test_metrics = _evaluate_predictions(test_preds, test_targets, threshold=chosen_thr)

    csv_path = save_metrics_csv(
        [
            {"split": "val", **val_metrics},
            {"split": "test", **test_metrics},
        ],
        rep_dir / "detector_metrics.csv",
    )

    sample_face = _load_rgb_u8(splits["test"]["pos"][0]) if splits["test"]["pos"] else None
    export_res = export_detector_tflite_and_golden(
        keras_model=model,
        output_tflite_path=tflite_output_path,
        preprocess_config_path=preprocess_config_path,
        golden_dir=golden_dir,
        threshold=chosen_thr,
        sample_face_rgb=sample_face,
        copy_to_mobile=copy_to_mobile,
        threshold_json_path=thr_out,
        mobile_models_dir=mobile_models_dir,
        mobile_golden_dir=mobile_golden_dir,
    )

    summary = {
        "validation": val_metrics,
        "test": test_metrics,
        "threshold_path": str(thr_out),
        "metrics_csv_path": str(csv_path),
        "export": export_res,
    }
    (rep_dir / "detector_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Latih, evaluasi, dan ekspor detektor wajah SIAKAR ke detector.tflite (ML7 / T-205)."
    )
    parser.add_argument("--config", type=str, default="configs/detector.yaml")
    parser.add_argument("--epochs", type=int, default=None)
    parser.add_argument("--batch-size", type=int, default=None)
    parser.add_argument("--max-positives", type=int, default=None)
    parser.add_argument("--max-steps-per-epoch", type=int, default=None)
    parser.add_argument("--copy-to-mobile", action="store_true", help="Salin detector.tflite ke mobile/assets/models/")
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    m_cfg = cfg.get("model", {})
    d_cfg = cfg.get("data", {})
    t_cfg = cfg.get("training", {})
    e_cfg = cfg.get("export", {})

    summary = run_detector_pipeline(
        positive_dir=d_cfg.get("positive_dir", "data/raw/digiface"),
        negative_dir=d_cfg.get("negative_dir", "data/negatives"),
        preprocess_config_path=cfg.get("preprocess_config", "artifacts/preprocess.json"),
        checkpoint_dir=t_cfg.get("checkpoint_dir", "artifacts/checkpoints/detector"),
        model_output_path=t_cfg.get("model_path", "artifacts/detector.keras"),
        tflite_output_path=e_cfg.get("tflite_path", "artifacts/detector.tflite"),
        threshold_output_path=e_cfg.get("threshold_path", "artifacts/detector_threshold.json"),
        golden_dir=e_cfg.get("golden_dir", "artifacts/golden_detector"),
        reports_dir=cfg.get("reports_dir", "reports"),
        input_size=int(m_cfg.get("input_size", 64)),
        filters=m_cfg.get("filters", [32, 64, 128]),
        dense_units=int(m_cfg.get("dense_units", 64)),
        include_bbox=bool(m_cfg.get("include_bbox", True)),
        bbox_loss_weight=float(m_cfg.get("bbox_loss_weight", 2.0)),
        max_positives=int(args.max_positives or d_cfg.get("max_positives", 4000)),
        n_synthetic_negatives=int(d_cfg.get("n_synthetic_negatives", 4000)),
        val_ratio=float(d_cfg.get("val_ratio", 0.15)),
        test_ratio=float(d_cfg.get("test_ratio", 0.15)),
        batch_size=int(args.batch_size or d_cfg.get("batch_size", 32)),
        epochs=int(args.epochs or t_cfg.get("epochs", 25)),
        learning_rate=float(t_cfg.get("learning_rate", 1e-3)),
        min_learning_rate=float(t_cfg.get("min_learning_rate", 1e-6)),
        early_stopping_patience=int(t_cfg.get("early_stopping_patience", 6)),
        reduce_lr_patience=int(t_cfg.get("reduce_lr_patience", 3)),
        reduce_lr_factor=float(t_cfg.get("reduce_lr_factor", 0.5)),
        seed=int(d_cfg.get("seed", 42)),
        max_steps_per_epoch=args.max_steps_per_epoch,
        copy_to_mobile=args.copy_to_mobile,
        mobile_models_dir=e_cfg.get("mobile_models_dir", "../mobile/assets/models"),
        mobile_golden_dir=e_cfg.get("mobile_golden_dir", "../mobile/test/golden_detector"),
    )

    tst = summary["test"]
    exp = summary["export"]
    print("=" * 68)
    print("[train_detector] Pelatihan, Evaluasi, & Ekspor Detektor Selesai!")
    print(
        f"  - Metrik Uji      : Acc={tst['accuracy']:.4f}, Prec={tst['precision']:.4f}, "
        f"Rec={tst['recall']:.4f}, F1={tst['f1']:.4f}, Mean BBox IoU={tst['mean_bbox_iou']}"
    )
    print(f"  - Ambang Detektor : {summary['threshold_path']} (thr={tst['threshold']})")
    print(f"  - Model TFLite    : {exp['tflite_path']} ({exp['tflite_size_bytes'] / 1024:.1f} KB)")
    print(f"  - Golden Samples  : {exp['golden_manifest_path']} (max_diff={exp['max_abs_diff']:.7f})")
    print("=" * 68)


if __name__ == "__main__":
    main()
