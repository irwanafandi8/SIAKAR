"""
export_tflite.py — Ekspor Model Keras ke TFLite + Uji Paritas + Generator Golden Vectors (ML6 / T-204).

Sesuai ML_SPEC.md §5 & §7 serta kebutuhan tes paritas Flutter (M3 / T-221):
- Mengekstrak sub-model backbone TANPA kepala softmax/cosface.
- Memvalidasi kontrak input float32 [1, H, W, 3] RGB [-1, 1] (sesuai preprocess.json)
  dan output float32 [1, 128] ter-normalisasi L2.
- Mengekspor float32 siakar_embedding.tflite menggunakan TFLITE_BUILTINS.
- Membangkitkan citra uji sintetis deterministik + golden_vectors.json di ml/artifacts/golden/
  dan memverifikasi paritas numerik Keras vs TFLite (cosine similarity >= 0.999).
- Opsional menyalin artefak (siakar_embedding.tflite, preprocess.json, threshold.json, golden/)
  ke folder mobile/ agar langsung siap diuji pada T-221.
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
from PIL import Image
import tensorflow as tf
from tensorflow import keras
import yaml

from siakar_ml.models.embedding_cnn import CUSTOM_OBJECTS, extract_embedding_backbone
from siakar_ml.preprocess import load_preprocess_config, preprocess_for_model


def _cosine_similarity(vec_a: np.ndarray, vec_b: np.ndarray) -> float:
    a = np.asarray(vec_a, dtype=np.float64).ravel()
    b = np.asarray(vec_b, dtype=np.float64).ravel()
    denom = float(np.linalg.norm(a) * np.linalg.norm(b))
    if denom <= 1e-12:
        return 0.0
    return float(np.dot(a, b) / denom)


def generate_synthetic_golden_image(sample_idx: int, height: int = 160, width: int = 128) -> np.ndarray:
    """Bangkitkan citra RGB uint8 sintetis halus & deterministik (tanpa data wajah pribadi/dataset).

    Pola gelombang 2D + elips terpusat memastikan crop oval, interpolasi bilinear, dan normalisasi
    lintas bahasa (Python skimage vs Dart package:image) diuji pada gradien warna yang kaya namun mulus.
    """
    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    yn = yy / max(height - 1, 1)
    xn = xx / max(width - 1, 1)

    cx = 0.5 + 0.04 * ((sample_idx % 3) - 1)
    cy = 0.5 + 0.04 * ((sample_idx // 3) - 0.5)
    radial = np.sqrt(((xn - cx) / 0.32) ** 2 + ((yn - cy) / 0.40) ** 2)
    oval_mask = np.clip(1.2 - radial, 0.0, 1.0)

    freq_a = float(sample_idx + 1) * 2.0
    freq_b = float((sample_idx % 4) + 2) * 1.5

    r_ch = 0.5 + 0.35 * np.sin(2.0 * np.pi * (freq_a * xn + yn)) * oval_mask
    g_ch = 0.5 + 0.35 * np.cos(2.0 * np.pi * (xn - freq_b * yn)) * oval_mask
    b_ch = 0.5 + 0.35 * np.sin(2.0 * np.pi * (freq_b * xn + freq_a * yn)) * (1.0 - 0.5 * oval_mask)

    rgb = np.stack([r_ch, g_ch, b_ch], axis=-1)
    return np.clip(np.round(rgb * 255.0), 0, 255).astype(np.uint8)


def export_backbone_to_tflite(
    model_or_backbone: keras.Model,
    output_tflite_path: str | Path,
    expected_input_size: int = 112,
    expected_embedding_dim: int = 128,
) -> bytes:
    """Ekstrak backbone (tanpa softmax head), validasi kontrak tensor, lalu ekspor ke .tflite float32."""
    backbone = extract_embedding_backbone(model_or_backbone)

    in_shape = backbone.input_shape
    out_shape = backbone.output_shape
    if in_shape[1:] != (expected_input_size, expected_input_size, 3):
        raise ValueError(
            f"Input backbone {in_shape} tidak sesuai kontrak preprocess.json "
            f"(diharapkan (None, {expected_input_size}, {expected_input_size}, 3))."
        )
    if out_shape[1:] != (expected_embedding_dim,):
        raise ValueError(
            f"Output backbone {out_shape} tidak sesuai kontrak ML_SPEC §5 "
            f"(diharapkan (None, {expected_embedding_dim}))."
        )

    converter = tf.lite.TFLiteConverter.from_keras_model(backbone)
    converter.optimizations = []  # float32 murni sesuai ML_SPEC §5
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    tflite_bytes = converter.convert()

    out_path = Path(output_tflite_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(tflite_bytes)
    return tflite_bytes


def generate_golden_vectors_and_verify_parity(
    keras_model: keras.Model,
    tflite_path: str | Path,
    preprocess_config_path: str | Path,
    golden_dir: str | Path,
    n_samples: int = 5,
    min_cosine: float = 0.999,
) -> Dict[str, Any]:
    """Bangkitkan citra golden + golden_vectors.json dan uji paritas Keras vs TFLite (>= min_cosine)."""
    backbone = extract_embedding_backbone(keras_model)
    preprocess_cfg = load_preprocess_config(str(preprocess_config_path))
    input_size = int(preprocess_cfg["input_size"])

    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    in_dtype = input_details[0]["dtype"]
    out_shape = tuple(int(d) for d in output_details[0]["shape"])
    if in_dtype != np.float32:
        raise AssertionError(f"Tipe input TFLite harus float32, ditemukan {in_dtype}.")
    if len(out_shape) != 2 or out_shape[0] != 1:
        raise AssertionError(f"Shape output TFLite harus [1, D], ditemukan {out_shape}.")

    out_golden_dir = Path(golden_dir)
    out_golden_dir.mkdir(parents=True, exist_ok=True)

    samples_payload: List[Dict[str, Any]] = []
    cosines: List[float] = []

    for idx in range(n_samples):
        # Variasikan rasio potret (160x128) dan persegi (112x112) untuk menguji crop oval & resize Dart
        h, w = (160, 128) if idx % 2 == 0 else (input_size, input_size)
        raw_rgb = generate_synthetic_golden_image(sample_idx=idx, height=h, width=w)

        img_filename = f"sample_{idx}.png"
        img_path = out_golden_dir / img_filename
        Image.fromarray(raw_rgb).save(img_path, format="PNG")

        # Baca kembali dari PNG agar byte piksel identik persis dengan yang akan dibaca di tes Dart
        reloaded_rgb = np.asarray(Image.open(img_path).convert("RGB"), dtype=np.uint8)
        nhwc_input = preprocess_for_model(reloaded_rgb, preprocess_cfg)

        keras_emb = backbone(nhwc_input, training=False).numpy().reshape(-1).astype(np.float32)

        interpreter.set_tensor(input_details[0]["index"], nhwc_input)
        interpreter.invoke()
        tflite_emb = interpreter.get_tensor(output_details[0]["index"]).reshape(-1).astype(np.float32)

        tflite_norm = float(np.linalg.norm(tflite_emb))
        if not np.all(np.isfinite(tflite_emb)) or abs(tflite_norm - 1.0) > 1e-3:
            raise AssertionError(
                f"Output TFLite pada {img_filename} tidak ter-normalisasi L2 (norm={tflite_norm:.6f})."
            )

        cos_sim = _cosine_similarity(keras_emb, tflite_emb)
        if cos_sim < min_cosine:
            raise AssertionError(
                f"Paritas Keras vs TFLite gagal pada {img_filename}: cosine={cos_sim:.6f} < {min_cosine}"
            )
        cosines.append(cos_sim)

        samples_payload.append(
            {
                "id": f"golden_{idx}",
                "image_file": img_filename,
                "image_width": int(w),
                "image_height": int(h),
                "preprocessed_shape": list(nhwc_input.shape),
                "preprocessed_head16": [round(float(v), 6) for v in nhwc_input.ravel()[:16]],
                "keras_embedding": [round(float(v), 7) for v in keras_emb.tolist()],
                "tflite_embedding": [round(float(v), 7) for v in tflite_emb.tolist()],
                "reference_embedding": [round(float(v), 7) for v in tflite_emb.tolist()],
                "keras_vs_tflite_cosine": round(cos_sim, 7),
            }
        )

    min_cos = float(min(cosines))
    golden_manifest: Dict[str, Any] = {
        "generated_at": datetime.now().isoformat(),
        "model_file": Path(tflite_path).name,
        "embedding_dim": int(out_shape[1]),
        "preprocess_config": preprocess_cfg,
        "keras_vs_tflite_min_cosine": round(min_cos, 7),
        "dart_parity_min_cosine_target": 0.99,
        "samples": samples_payload,
    }

    manifest_path = out_golden_dir / "golden_vectors.json"
    manifest_path.write_text(json.dumps(golden_manifest, indent=2), encoding="utf-8")
    return {
        "manifest_path": str(manifest_path),
        "min_cosine": min_cos,
        "n_samples": len(samples_payload),
    }


def copy_artifacts_to_mobile(
    tflite_path: Path,
    preprocess_json_path: Path,
    threshold_json_path: Optional[Path],
    golden_dir: Path,
    mobile_models_dir: Path,
    mobile_golden_dir: Optional[Path] = None,
) -> List[str]:
    """Salin siakar_embedding.tflite, preprocess.json, threshold.json, & golden vectors ke mobile/."""
    copied: List[str] = []
    mobile_models_dir.mkdir(parents=True, exist_ok=True)

    for src in [tflite_path, preprocess_json_path]:
        if src.exists():
            dst = mobile_models_dir / src.name
            shutil.copy2(src, dst)
            copied.append(str(dst))

    if threshold_json_path is not None and threshold_json_path.exists():
        dst_thr = mobile_models_dir / threshold_json_path.name
        shutil.copy2(threshold_json_path, dst_thr)
        copied.append(str(dst_thr))

    if mobile_golden_dir is not None and golden_dir.exists():
        mobile_golden_dir.mkdir(parents=True, exist_ok=True)
        for item in golden_dir.iterdir():
            if item.is_file():
                dst_g = mobile_golden_dir / item.name
                shutil.copy2(item, dst_g)
                copied.append(str(dst_g))

    return copied


def export_and_verify_pipeline(
    keras_model_or_path: keras.Model | str | Path,
    output_tflite_path: str | Path,
    preprocess_config_path: str | Path,
    golden_dir: str | Path,
    expected_embedding_dim: int = 128,
    n_golden_samples: int = 5,
    min_parity_cosine: float = 0.999,
    copy_to_mobile: bool = False,
    threshold_json_path: Optional[str | Path] = None,
    mobile_models_dir: Optional[str | Path] = None,
    mobile_golden_dir: Optional[str | Path] = None,
) -> Dict[str, Any]:
    """Pipeline lengkap ML6: muat model -> ekspor .tflite -> uji paritas & golden vectors -> salin mobile."""
    if isinstance(keras_model_or_path, keras.Model):
        model = keras_model_or_path
    else:
        model = keras.models.load_model(keras_model_or_path, custom_objects=CUSTOM_OBJECTS)

    preprocess_cfg = load_preprocess_config(str(preprocess_config_path))
    input_size = int(preprocess_cfg["input_size"])

    tflite_bytes = export_backbone_to_tflite(
        model_or_backbone=model,
        output_tflite_path=output_tflite_path,
        expected_input_size=input_size,
        expected_embedding_dim=expected_embedding_dim,
    )

    parity = generate_golden_vectors_and_verify_parity(
        keras_model=model,
        tflite_path=output_tflite_path,
        preprocess_config_path=preprocess_config_path,
        golden_dir=golden_dir,
        n_samples=n_golden_samples,
        min_cosine=min_parity_cosine,
    )

    copied_files: List[str] = []
    if copy_to_mobile and mobile_models_dir is not None:
        copied_files = copy_artifacts_to_mobile(
            tflite_path=Path(output_tflite_path),
            preprocess_json_path=Path(preprocess_config_path),
            threshold_json_path=Path(threshold_json_path) if threshold_json_path else None,
            golden_dir=Path(golden_dir),
            mobile_models_dir=Path(mobile_models_dir),
            mobile_golden_dir=Path(mobile_golden_dir) if mobile_golden_dir else None,
        )

    return {
        "tflite_path": str(output_tflite_path),
        "tflite_size_bytes": len(tflite_bytes),
        "golden_manifest_path": parity["manifest_path"],
        "min_parity_cosine": parity["min_cosine"],
        "n_golden_samples": parity["n_samples"],
        "copied_to_mobile": copied_files,
    }


def verify_tflite_parity(
    keras_model: keras.Model,
    tflite_path: str,
    num_samples: int = 5,
    input_size: int = 112,
) -> float:
    """Helper uji cepat paritas numerik Keras vs TFLite pada tensor acak [-1, 1]."""
    backbone = extract_embedding_backbone(keras_model)
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    in_det = interpreter.get_input_details()
    out_det = interpreter.get_output_details()

    rng = np.random.default_rng(seed=42)
    sims: List[float] = []
    for _ in range(num_samples):
        sample = rng.uniform(-1.0, 1.0, size=(1, input_size, input_size, 3)).astype(np.float32)
        k_out = backbone(sample, training=False).numpy().ravel()
        interpreter.set_tensor(in_det[0]["index"], sample)
        interpreter.invoke()
        t_out = interpreter.get_tensor(out_det[0]["index"]).ravel()
        sims.append(_cosine_similarity(k_out, t_out))

    min_sim = float(min(sims))
    if min_sim < 0.999:
        raise AssertionError(f"Paritas gagal: min cosine {min_sim:.6f} < 0.999")
    return min_sim


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Ekspor model CNN SIAKAR ke TFLite + uji paritas + buat golden vectors (T-204)."
    )
    parser.add_argument("--config", type=str, default="configs/embedding.yaml")
    parser.add_argument("--model", type=str, default=None, help="Path model .keras (training atau backbone)")
    parser.add_argument("--out", type=str, default=None, help="Path output .tflite")
    parser.add_argument("--golden-dir", type=str, default=None, help="Folder output golden vectors")
    parser.add_argument(
        "--copy-to-mobile",
        action="store_true",
        help="Salin siakar_embedding.tflite, preprocess.json, threshold.json, & golden/ ke mobile/",
    )
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    model_cfg = cfg.get("model", {})
    train_cfg = cfg.get("training", {})
    export_cfg = cfg.get("export", {})

    backbone_candidate = Path(train_cfg.get("backbone_model_path", "artifacts/embedding_backbone.keras"))
    training_candidate = Path(train_cfg.get("training_model_path", "artifacts/embedding_training.keras"))
    default_model = backbone_candidate if backbone_candidate.exists() else training_candidate

    model_path = Path(args.model) if args.model else default_model
    out_tflite = Path(args.out or export_cfg.get("tflite_path", "artifacts/siakar_embedding.tflite"))
    golden_dir = Path(args.golden_dir or export_cfg.get("golden_dir", "artifacts/golden"))
    preprocess_path = Path(cfg.get("preprocess_config", "artifacts/preprocess.json"))
    threshold_path = Path(export_cfg.get("threshold_path", "artifacts/threshold.json"))

    res = export_and_verify_pipeline(
        keras_model_or_path=model_path,
        output_tflite_path=out_tflite,
        preprocess_config_path=preprocess_path,
        golden_dir=golden_dir,
        expected_embedding_dim=int(model_cfg.get("embedding_dim", 128)),
        n_golden_samples=int(export_cfg.get("n_golden_samples", 5)),
        min_parity_cosine=float(export_cfg.get("min_parity_cosine", 0.999)),
        copy_to_mobile=args.copy_to_mobile,
        threshold_json_path=threshold_path,
        mobile_models_dir=export_cfg.get("mobile_models_dir", "../mobile/assets/models"),
        mobile_golden_dir=export_cfg.get("mobile_golden_dir", "../mobile/test/golden"),
    )

    print("=" * 68)
    print("[export_tflite] Ekspor & Uji Paritas TFLite LULUS!")
    print(f"  - Berkas TFLite   : {res['tflite_path']} ({res['tflite_size_bytes'] / 1024:.1f} KB)")
    print(f"  - Paritas min cos : {res['min_parity_cosine']:.7f} (syarat >= 0.999)")
    print(f"  - Golden vectors  : {res['golden_manifest_path']} ({res['n_golden_samples']} sampel)")
    if res["copied_to_mobile"]:
        print(f"  - Disalin ke app  : {len(res['copied_to_mobile'])} berkas ke mobile/")
    print("=" * 68)


if __name__ == "__main__":
    main()
