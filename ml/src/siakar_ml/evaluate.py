"""
evaluate.py — Protokol Evaluasi Model SIAKAR (Klasifikasi & Verifikasi, ML_SPEC §6 & §7).

Mencakup:
- Klasifikasi tertutup (Kelompok A, set aksesori yang ditahan):
  Top-1 accuracy, Top-5 accuracy, akurasi per identitas, dan identitas paling sering salah.
- Verifikasi terbuka (Kelompok B & C):
  - Pasangan validasi (Kelompok B) memilih ambang optimal pada titik EER (Equal Error Rate)
    -> ditulis ke ml/artifacts/threshold.json.
  - Pasangan uji (Kelompok C) dievaluasi memakai ambang tetap dari validasi (tanpa tuning ulang):
    FAR, FRR, EER, ROC AUC, TAR@FAR=1%, TAR@FAR=0.1%, dan akurasi verifikasi.
- Penulisan tabel CSV metrik (per run + rekap ablasi), grafik ROC & FAR/FRR (PNG),
  serta dokumen laporan ml/reports/analysis.md (perbandingan vs baseline & keterbatasan selisih domain).
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

import numpy as np
import yaml


def _roc_curve_and_auc(y_true: np.ndarray, scores: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray, float]:
    """Hitung kurva ROC (FPR, TPR, thresholds) dan ROC AUC."""
    try:
        from sklearn.metrics import auc as sk_auc
        from sklearn.metrics import roc_curve as sk_roc_curve

        fpr, tpr, thresholds = sk_roc_curve(y_true, scores)
        return fpr, tpr, thresholds, float(sk_auc(fpr, tpr))
    except ImportError:
        desc_idx = np.argsort(scores, kind="mergesort")[::-1]
        s_sorted = scores[desc_idx]
        y_sorted = y_true[desc_idx]

        distinct_idx = np.where(np.diff(s_sorted))[0]
        thr_idxs = np.r_[distinct_idx, y_sorted.size - 1]

        tps = np.cumsum(y_sorted == 1)[thr_idxs].astype(np.float64)
        fps = np.cumsum(y_sorted == 0)[thr_idxs].astype(np.float64)

        tps = np.r_[0.0, tps]
        fps = np.r_[0.0, fps]
        thresholds = np.r_[np.inf, s_sorted[thr_idxs]]

        fpr = fps / max(fps[-1], 1.0)
        tpr = tps / max(tps[-1], 1.0)
        area = float(np.trapz(tpr, fpr))
        return fpr, tpr, thresholds, area


def compute_tar_at_far(fpr: np.ndarray, tpr: np.ndarray, target_far: float) -> float:
    """Hitung True Accept Rate (TAR = 1 - FRR) tertinggi pada batas FAR <= target_far."""
    valid = np.where(fpr <= target_far)[0]
    if len(valid) == 0:
        return 0.0
    return float(np.max(tpr[valid]))


def compute_verification_metrics(
    similarities: Sequence[float] | np.ndarray,
    labels: Sequence[int] | np.ndarray,
    fixed_threshold: Optional[float] = None,
) -> Dict[str, Any]:
    """Hitung metrik verifikasi lengkap (FAR, FRR, EER, ROC AUC, TAR@FAR, akurasi)."""
    scores = np.asarray(similarities, dtype=np.float64).ravel()
    y_true = np.asarray(labels, dtype=np.int32).ravel()

    if scores.shape[0] != y_true.shape[0] or scores.shape[0] == 0:
        raise ValueError("Panjang similarities dan labels harus sama dan tidak boleh kosong.")
    if len(np.unique(y_true)) < 2:
        raise ValueError("Labels verifikasi harus memuat kelas genuine (1) dan impostor (0).")

    fpr, tpr, thresholds, roc_auc_val = _roc_curve_and_auc(y_true, scores)
    fnr = 1.0 - tpr

    finite_mask = np.isfinite(thresholds)
    if np.any(finite_mask):
        finite_indices = np.where(finite_mask)[0]
        rel_idx = int(np.nanargmin(np.abs(fpr[finite_indices] - fnr[finite_indices])))
        eer_idx = int(finite_indices[rel_idx])
    else:
        eer_idx = int(np.nanargmin(np.abs(fpr - fnr)))

    eer = float((fpr[eer_idx] + fnr[eer_idx]) / 2.0)

    genuine_scores = scores[y_true == 1]
    impostor_scores = scores[y_true == 0]
    if eer == 0.0 and float(np.min(genuine_scores)) > float(np.max(impostor_scores)):
        eer_threshold = float((np.min(genuine_scores) + np.max(impostor_scores)) / 2.0)
    elif np.isfinite(thresholds[eer_idx]):
        eer_threshold = float(thresholds[eer_idx])
    else:
        eer_threshold = float(np.median(scores))

    applied_threshold = float(fixed_threshold) if fixed_threshold is not None else eer_threshold

    preds = (scores >= applied_threshold).astype(np.int32)
    far = float(np.mean(scores[y_true == 0] >= applied_threshold))
    frr = float(np.mean(scores[y_true == 1] < applied_threshold))
    accuracy = float(np.mean(preds == y_true))

    tar_1pct = compute_tar_at_far(fpr, tpr, target_far=0.01)
    tar_01pct = compute_tar_at_far(fpr, tpr, target_far=0.001)

    return {
        "optimal_threshold": eer_threshold,
        "applied_threshold": applied_threshold,
        "eer": eer,
        "roc_auc": roc_auc_val,
        "far": far,
        "frr": frr,
        "far_at_threshold": far,
        "frr_at_threshold": frr,
        "accuracy": accuracy,
        "tar_at_far_1pct": tar_1pct,
        "tar_at_far_01pct": tar_01pct,
        "n_pairs": int(scores.shape[0]),
        "curves": {
            "fpr": fpr,
            "tpr": tpr,
            "fnr": fnr,
            "thresholds": thresholds,
        },
    }


def compute_classification_metrics(
    y_true: Sequence[int] | np.ndarray,
    y_pred: Sequence[int] | np.ndarray,
    decision_scores: Optional[np.ndarray] = None,
    id_names: Optional[Dict[int, str]] = None,
    worst_k: int = 5,
) -> Dict[str, Any]:
    """Hitung metrik klasifikasi set tertutup (ML_SPEC.md §6.1)."""
    yt = np.asarray(y_true, dtype=np.int32).ravel()
    yp = np.asarray(y_pred, dtype=np.int32).ravel()
    if yt.shape[0] == 0 or yt.shape[0] != yp.shape[0]:
        raise ValueError("y_true dan y_pred harus berukuran sama dan tidak kosong.")

    top1_acc = float(np.mean(yt == yp))

    top5_acc: Optional[float] = None
    if decision_scores is not None and decision_scores.ndim == 2:
        k = min(5, decision_scores.shape[1])
        topk_indices = np.argsort(decision_scores, axis=1)[:, -k:]
        hits = [yt[i] in topk_indices[i] for i in range(yt.shape[0])]
        top5_acc = float(np.mean(hits))

    per_class_acc: Dict[str, float] = {}
    for cls in np.unique(yt):
        mask = yt == cls
        cls_name = id_names.get(int(cls), str(int(cls))) if id_names else str(int(cls))
        per_class_acc[cls_name] = float(np.mean(yp[mask] == yt[mask]))

    sorted_worst = sorted(per_class_acc.items(), key=lambda kv: (kv[1], kv[0]))[:worst_k]

    return {
        "top1_accuracy": top1_acc,
        "top5_accuracy": top5_acc,
        "n_samples": int(yt.shape[0]),
        "n_classes": int(len(per_class_acc)),
        "per_identity_accuracy": per_class_acc,
        "worst_identities": [
            {"identity": name, "accuracy": round(acc, 4)} for name, acc in sorted_worst
        ],
    }


def save_threshold_artifact(output_path: str | Path, metrics: Dict[str, Any], n_pairs: int) -> Path:
    """Simpan artefak threshold.json (ML_SPEC.md §7) untuk dikonsumsi Laravel backend."""
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)

    threshold_data = {
        "threshold": round(float(metrics["optimal_threshold"]), 4),
        "metric_basis": "EER (Equal Error Rate) pada pasangan validasi Kelompok B",
        "far": round(float(metrics["far_at_threshold"]), 4),
        "frr": round(float(metrics["frr_at_threshold"]), 4),
        "eer": round(float(metrics["eer"]), 4),
        "roc_auc": round(float(metrics["roc_auc"]), 4),
        "val_pairs": int(n_pairs),
        "date": datetime.now().isoformat(),
    }

    with open(out, "w", encoding="utf-8") as f:
        json.dump(threshold_data, f, indent=2)
    return out


def save_metrics_csv(rows: Sequence[Dict[str, Any]], csv_path: str | Path) -> Path:
    """Simpan tabel metrik eksperimen ke berkas CSV."""
    out = Path(csv_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        return out

    fieldnames = list(rows[0].keys())
    with open(out, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    return out


def upsert_ablation_row(row: Dict[str, Any], csv_path: Path) -> Path:
    """Tambahkan atau perbarui baris run pada tabel komparasi ablasi CSV."""
    existing: List[Dict[str, Any]] = []
    if csv_path.exists():
        with open(csv_path, "r", encoding="utf-8") as f:
            existing = list(csv.DictReader(f))

    key_name = str(row.get("run_name", row.get("method", "cnn")))
    filtered = [r for r in existing if str(r.get("run_name", r.get("method", ""))) != key_name]
    filtered.append({k: str(v) for k, v in row.items()})
    return save_metrics_csv(filtered, csv_path)


def plot_roc_and_eer_curves(
    method_to_metrics: Dict[str, Dict[str, Any]],
    output_png_path: str | Path,
    title_prefix: str = "Evaluasi SIAKAR",
) -> Path:
    """Gambar kurva ROC dan kurva FAR/FRR terhadap Threshold ke satu berkas PNG."""
    out = Path(output_png_path)
    out.parent.mkdir(parents=True, exist_ok=True)

    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(12, 5))

        ax_roc = axes[0]
        for method_name, metrics in method_to_metrics.items():
            curves = metrics["curves"]
            label = (
                f"{method_name.upper()} "
                f"(AUC={metrics['roc_auc']:.3f}, EER={metrics['eer'] * 100:.1f}%)"
            )
            ax_roc.plot(curves["fpr"], curves["tpr"], linewidth=2.0, label=label)

        ax_roc.plot([0, 1], [0, 1], linestyle="--", color="gray", linewidth=1.0, label="Acak")
        ax_roc.set_title(f"{title_prefix} — Kurva ROC")
        ax_roc.set_xlabel("False Accept Rate (FAR)")
        ax_roc.set_ylabel("True Accept Rate (TAR = 1 - FRR)")
        ax_roc.set_xlim(0.0, 1.0)
        ax_roc.set_ylim(0.0, 1.02)
        ax_roc.grid(True, alpha=0.3)
        ax_roc.legend(loc="lower right", fontsize=8)

        ax_err = axes[1]
        for method_name, metrics in method_to_metrics.items():
            curves = metrics["curves"]
            thr = curves["thresholds"]
            finite = np.isfinite(thr)
            ax_err.plot(
                thr[finite],
                curves["fpr"][finite],
                linestyle="-",
                linewidth=1.6,
                label=f"{method_name.upper()} FAR",
            )
            ax_err.plot(
                thr[finite],
                curves["fnr"][finite],
                linestyle="--",
                linewidth=1.6,
                label=f"{method_name.upper()} FRR",
            )

        ax_err.set_title(f"{title_prefix} — FAR & FRR vs Ambang")
        ax_err.set_xlabel("Ambang Cosine Similarity")
        ax_err.set_ylabel("Tingkat Kesalahan")
        ax_err.set_ylim(0.0, 1.02)
        ax_err.grid(True, alpha=0.3)
        ax_err.legend(loc="best", fontsize=8)

        fig.tight_layout()
        fig.savefig(out, dpi=150)
        plt.close(fig)
        return out
    except ImportError:
        from PIL import Image, ImageDraw

        width, height = 960, 440
        pad = 60
        img = Image.new("RGB", (width, height), (255, 254, 242))
        draw = ImageDraw.Draw(img)
        palette = [(51, 143, 74), (30, 30, 73), (154, 91, 0)]

        x0, y0, x1, y1 = pad, pad, width // 2 - pad // 2, height - pad
        draw.rectangle([x0, y0, x1, y1], outline=(30, 30, 73), width=2)
        draw.line([x0, y1, x1, y0], fill=(180, 180, 180), width=1)
        draw.text((x0, 20), f"{title_prefix} - ROC", fill=(30, 30, 73))

        for idx, (method_name, metrics) in enumerate(method_to_metrics.items()):
            color = palette[idx % len(palette)]
            fpr = metrics["curves"]["fpr"]
            tpr = metrics["curves"]["tpr"]
            pts = [
                (
                    int(x0 + float(fx) * (x1 - x0)),
                    int(y1 - float(ty) * (y1 - y0)),
                )
                for fx, ty in zip(fpr, tpr)
            ]
            if len(pts) >= 2:
                draw.line(pts, fill=color, width=2)
            draw.text(
                (width // 2 + 20, pad + idx * 28),
                f"{method_name.upper()}: AUC={metrics['roc_auc']:.3f}, EER={metrics['eer']:.3f}",
                fill=color,
            )

        img.save(out, format="PNG")
        return out


def _extract_backbone_embeddings_batched(
    backbone_model: Any,
    unique_paths: Iterable[str],
    preprocess_cfg: Dict[str, Any],
    base_dir: Path,
    batch_size: int = 32,
    input_size_override: Optional[int] = None,
) -> Dict[str, np.ndarray]:
    """Hitung embedding L2-normalized secara mini-batch dari disk tanpa menumpuk citra di RAM."""
    from siakar_ml.data.dataset_loader import create_classification_dataset

    ordered_paths = list(dict.fromkeys(unique_paths))
    if not ordered_paths:
        return {}

    samples = [{"path": p, "label": 0} for p in ordered_paths]
    ds = create_classification_dataset(
        samples=samples,
        preprocess_cfg=preprocess_cfg,
        batch_size=batch_size,
        training=False,
        base_dir=base_dir,
        input_size_override=input_size_override,
    )

    vectors: List[np.ndarray] = []
    for batch_x, _ in ds:
        emb = backbone_model(batch_x, training=False).numpy()
        vectors.append(emb.astype(np.float32))

    all_emb = np.vstack(vectors)
    return {path_str: all_emb[idx] for idx, path_str in enumerate(ordered_paths)}


def _score_pairs_with_backbone(
    backbone_model: Any,
    pairs: Sequence[Dict[str, Any]],
    preprocess_cfg: Dict[str, Any],
    base_dir: Path,
    batch_size: int = 32,
    input_size_override: Optional[int] = None,
) -> Tuple[np.ndarray, np.ndarray]:
    all_paths: List[str] = []
    for item in pairs:
        all_paths.append(item["img1"])
        all_paths.append(item["img2"])

    emb_map = _extract_backbone_embeddings_batched(
        backbone_model=backbone_model,
        unique_paths=all_paths,
        preprocess_cfg=preprocess_cfg,
        base_dir=base_dir,
        batch_size=batch_size,
        input_size_override=input_size_override,
    )

    sims = np.empty(len(pairs), dtype=np.float32)
    labels = np.empty(len(pairs), dtype=np.int32)
    for idx, item in enumerate(pairs):
        v1 = emb_map[item["img1"]]
        v2 = emb_map[item["img2"]]
        denom = float(np.linalg.norm(v1) * np.linalg.norm(v2))
        cos_val = float(np.dot(v1, v2) / denom) if denom > 1e-12 else 0.0
        sims[idx] = max(-1.0, min(1.0, cos_val))
        labels[idx] = int(item["label"])
    return sims, labels


def write_analysis_report(
    reports_dir: Path,
    ablation_csv_path: Path,
    baseline_csv_path: Path,
    threshold_json_path: Optional[Path] = None,
) -> Path:
    """Bangkitkan laporan ml/reports/analysis.md (perbandingan vs baseline, ablasi, selisih domain)."""
    analysis_path = reports_dir / "analysis.md"

    baseline_rows: List[Dict[str, str]] = []
    if baseline_csv_path.exists():
        with open(baseline_csv_path, "r", encoding="utf-8") as f:
            baseline_rows = list(csv.DictReader(f))

    cnn_rows: List[Dict[str, str]] = []
    if ablation_csv_path.exists():
        with open(ablation_csv_path, "r", encoding="utf-8") as f:
            cnn_rows = list(csv.DictReader(f))

    thr_info: Dict[str, Any] = {}
    if threshold_json_path is not None and threshold_json_path.exists():
        thr_info = json.loads(threshold_json_path.read_text(encoding="utf-8"))

    lines = [
        "# Analisis Evaluasi Model Pengenalan Wajah SIAKAR (`ML_SPEC` §6 & §8)",
        "",
        "## 1. Perbandingan CNN Embedding (Dari Nol) vs Baseline Klasik (HOG / LBP)",
        "",
        "| Model / Run | Klasifikasi Top-1 (A) | Ambang Validasi (B) | Test FAR (C) | Test FRR (C) | Test EER (C) | Test ROC AUC (C) | TAR@FAR=1% |",
        "|---|---|---|---|---|---|---|---|",
    ]

    for b in baseline_rows:
        lines.append(
            f"| Baseline `{b.get('method', '').upper()}` | {b.get('cls_top1_acc', '-')} | "
            f"{b.get('val_threshold', '-')} | {b.get('test_far', '-')} | {b.get('test_frr', '-')} | "
            f"{b.get('test_eer', '-')} | {b.get('test_roc_auc', '-')} | {b.get('test_tar_far_1pct', '-')} |"
        )

    for c in cnn_rows:
        lines.append(
            f"| CNN `{c.get('run_name', 'cnn')}` | {c.get('cls_top1_acc', '-')} | "
            f"{c.get('val_threshold', '-')} | {c.get('test_far', '-')} | {c.get('test_frr', '-')} | "
            f"{c.get('test_eer', '-')} | {c.get('test_roc_auc', '-')} | {c.get('test_tar_far_1pct', '-')} |"
        )

    lines.extend(
        [
            "",
            "### Analisis Perbandingan Metode",
            "- **Baseline klasik (HOG/LBP)** mengekstrak gradien tepi dan tekstur mikro lokal secara statis, "
            "sehingga sensitif terhadap perubahan pose, rotasi, dan aksesori pada set aksesori yang ditahan.",
            "- **CNN Embedding (dibangun dari nol)** mempelajari representasi hierarkis ter-normalisasi L2 "
            "berdimensi 128 yang lebih invarian terhadap variasi pose/pencahayaan antar set aksesori.",
            "",
            "## 2. Pemilihan Ambang Verifikasi (`threshold.json`)",
            f"- **Dasar pemilihan**: Titik *Equal Error Rate* (EER, di mana FAR ≈ FRR) pada pasangan validasi "
            "**Kelompok B** (identitas tidak pernah dilatih), kemudian diterapkan apa adanya pada pasangan uji "
            "**Kelompok C** tanpa penyetelan ulang pada data uji (`ML_SPEC.md` §6.2 & §7).",
        ]
    )

    if thr_info:
        lines.append(
            f"- **Ambang terpilih saat ini**: `{thr_info.get('threshold')}` "
            f"(Validasi EER = `{thr_info.get('eer')}`, ROC AUC = `{thr_info.get('roc_auc')}`, "
            f"`val_pairs` = `{thr_info.get('val_pairs')}`). Nilai ini disalin ke `admin/config/face.php`."
        )

    lines.extend(
        [
            "",
            "## 3. Studi Ablasi (`T-203`)",
            "- Bandingkan baris `main_cnn` (augmentasi aktif, `dim=128`, `softmax`) terhadap varian ablasi "
            "(`abl_no_aug`, `abl_dim64`, atau `abl_cosface`) pada tabel di atas:",
            "  1. **Dampak Augmentasi**: Augmentasi kecerahan, kontras, dan flip mencegah *overfitting* pada "
            "kondisi pencahayaan seragam serta meningkatkan generalisasi pada identitas baru.",
            "  2. **Dimensi Embedding (64 vs 128)**: Vektor 128-d menyediakan kapasitas pemisahan sudut "
            "antar-identitas yang lebih longgar dibanding 64-d dengan selisih ukuran berkas `.tflite` yang sangat kecil.",
            "  3. **Fungsi Loss (Softmax vs Margin CosFace)**: Penalti margin sudut mendorong jarak kosinus intra-identitas "
            "lebih rapat di ruang hipersfer L2.",
            "",
            "## 4. Keterbatasan & Selisih Domain Sintetis → Wajah Nyata (`ML_SPEC` §6.5)",
            "- **Seluruh data latih, validasi, dan uji berasal dari dataset sintetis DigiFace-1M.** Angka akurasi, "
            "EER, dan ROC AUC pada laporan ini **tidak dapat diklaim sebagai akurasi pada wajah manusia nyata**.",
            "- Citra kamera ponsel nyata memiliki karakteristik sensor, derau optik, *motion blur*, distorsi lensa depan, "
            "serta distribusi tekstur kulit yang berbeda dari render 3D sintetis (*synthetic-to-real domain gap*).",
            "- Pendekatan *alignment-free* dengan panduan bingkai oval mengandalkan kepatuhan pengguna memposisikan wajah "
            "di tengah bingkai; kemiringan ekstrem di luar rentang augmentasi dapat menurunkan skor kosinus.",
            "- Uji coba pada perangkat fisik di aplikasi hanya berstatus **uji asap (*smoke test*) fungsional**, "
            "bukan pengukuran akurasi biometrik.",
            "",
        ]
    )

    analysis_path.write_text("\n".join(lines), encoding="utf-8")
    return analysis_path


def evaluate_cnn_pipeline(
    model_path: str | Path,
    split_path: str | Path,
    pairs_val_path: str | Path,
    pairs_test_path: str | Path,
    preprocess_config_path: str | Path,
    reports_dir: str | Path,
    threshold_output_path: Optional[str | Path] = "artifacts/threshold.json",
    run_name: str = "main_cnn",
    batch_size: int = 32,
    save_threshold: bool = True,
    base_dir: str | Path = ".",
) -> Dict[str, Any]:
    """Jalankan evaluasi penuh model CNN sesuai protokol ML_SPEC §6 & §7."""
    from tensorflow import keras

    from siakar_ml.data.dataset_loader import create_classification_dataset
    from siakar_ml.models.embedding_cnn import CUSTOM_OBJECTS, extract_embedding_backbone
    from siakar_ml.preprocess import load_preprocess_config

    root = Path(base_dir)
    rep_dir = Path(reports_dir)
    rep_dir.mkdir(parents=True, exist_ok=True)

    preprocess_cfg = load_preprocess_config(str(preprocess_config_path))
    with open(split_path, "r", encoding="utf-8") as f:
        split_data = json.load(f)
    with open(pairs_val_path, "r", encoding="utf-8") as f:
        pairs_val = json.load(f)
    with open(pairs_test_path, "r", encoding="utf-8") as f:
        pairs_test = json.load(f)

    loaded_model = keras.models.load_model(model_path, custom_objects=CUSTOM_OBJECTS)
    backbone = extract_embedding_backbone(loaded_model)
    model_input_size = int(backbone.input_shape[1])

    # 1. Evaluasi Klasifikasi Set Tertutup (Kelompok A — set aksesori ditahan)
    cls_test = split_data["classification"]["test"]
    inv_label_map = {int(v): k for k, v in split_data.get("label_map", {}).items()}
    has_cls_head = any(layer.name == "classification_head" for layer in loaded_model.layers)

    if has_cls_head:
        cls_ds = create_classification_dataset(
            samples=cls_test,
            preprocess_cfg=preprocess_cfg,
            batch_size=batch_size,
            training=False,
            base_dir=root,
            input_size_override=model_input_size,
        )
        all_scores: List[np.ndarray] = []
        all_true: List[np.ndarray] = []
        for bx, by in cls_ds:
            scores = loaded_model(bx, training=False).numpy()
            all_scores.append(scores)
            all_true.append(by.numpy())
        dec_scores = np.vstack(all_scores)
        y_true = np.concatenate(all_true)
        y_pred = np.argmax(dec_scores, axis=1)
    else:
        # Jika model yang dievaluasi adalah backbone murni: klasifikasi prototipe kosinus terdekat
        cls_train = split_data["classification"]["train"]
        all_cls_paths = [s["path"] for s in cls_train] + [s["path"] for s in cls_test]
        emb_map = _extract_backbone_embeddings_batched(
            backbone,
            all_cls_paths,
            preprocess_cfg,
            root,
            batch_size=batch_size,
            input_size_override=model_input_size,
        )
        n_classes = len(split_data["train_identities"])
        emb_dim = int(backbone.output_shape[-1])
        prototypes = np.zeros((n_classes, emb_dim), dtype=np.float32)
        for s in cls_train:
            prototypes[int(s["label"])] += emb_map[s["path"]]
        norms = np.linalg.norm(prototypes, axis=1, keepdims=True)
        prototypes = prototypes / np.maximum(norms, 1e-12)

        x_test_emb = np.vstack([emb_map[s["path"]] for s in cls_test])
        y_true = np.array([int(s["label"]) for s in cls_test], dtype=np.int32)
        dec_scores = x_test_emb @ prototypes.T
        y_pred = np.argmax(dec_scores, axis=1)

    cls_metrics = compute_classification_metrics(
        y_true=y_true,
        y_pred=y_pred,
        decision_scores=dec_scores,
        id_names=inv_label_map,
    )

    # 2. Verifikasi pada Kelompok B (pilih ambang optimal EER)
    val_sims, val_labels = _score_pairs_with_backbone(
        backbone,
        pairs_val,
        preprocess_cfg,
        root,
        batch_size=batch_size,
        input_size_override=model_input_size,
    )
    val_metrics = compute_verification_metrics(val_sims, val_labels, fixed_threshold=None)
    chosen_thr = float(val_metrics["optimal_threshold"])

    thr_path_saved: Optional[Path] = None
    if save_threshold and threshold_output_path is not None:
        thr_path_saved = save_threshold_artifact(threshold_output_path, val_metrics, len(pairs_val))

    # 3. Verifikasi pada Kelompok C menggunakan ambang tetap dari Kelompok B
    test_sims, test_labels = _score_pairs_with_backbone(
        backbone,
        pairs_test,
        preprocess_cfg,
        root,
        batch_size=batch_size,
        input_size_override=model_input_size,
    )
    test_metrics = compute_verification_metrics(test_sims, test_labels, fixed_threshold=chosen_thr)

    row = {
        "run_name": run_name,
        "embedding_dim": int(backbone.output_shape[-1]),
        "input_size": model_input_size,
        "cls_top1_acc": round(cls_metrics["top1_accuracy"], 4),
        "cls_top5_acc": (
            round(cls_metrics["top5_accuracy"], 4)
            if cls_metrics["top5_accuracy"] is not None
            else ""
        ),
        "val_threshold": round(chosen_thr, 4),
        "val_eer": round(val_metrics["eer"], 4),
        "val_roc_auc": round(val_metrics["roc_auc"], 4),
        "test_far": round(test_metrics["far"], 4),
        "test_frr": round(test_metrics["frr"], 4),
        "test_eer": round(test_metrics["eer"], 4),
        "test_roc_auc": round(test_metrics["roc_auc"], 4),
        "test_tar_far_1pct": round(test_metrics["tar_at_far_1pct"], 4),
        "test_tar_far_01pct": round(test_metrics["tar_at_far_01pct"], 4),
        "test_verif_acc": round(test_metrics["accuracy"], 4),
    }

    run_csv = save_metrics_csv([row], rep_dir / f"cnn_metrics_{run_name}.csv")
    ablation_csv = upsert_ablation_row(row, rep_dir / "ablation_comparison.csv")
    roc_png = plot_roc_and_eer_curves(
        {run_name: test_metrics},
        rep_dir / f"cnn_roc_eer_{run_name}.png",
        title_prefix=f"CNN Embedding ({run_name} — Uji Kelompok C)",
    )
    analysis_md = write_analysis_report(
        reports_dir=rep_dir,
        ablation_csv_path=ablation_csv,
        baseline_csv_path=rep_dir / "baseline_metrics.csv",
        threshold_json_path=thr_path_saved,
    )

    return {
        "run_name": run_name,
        "row": row,
        "classification": cls_metrics,
        "validation": {k: v for k, v in val_metrics.items() if k != "curves"},
        "test": {k: v for k, v in test_metrics.items() if k != "curves"},
        "threshold_path": str(thr_path_saved) if thr_path_saved else None,
        "csv_path": str(run_csv),
        "ablation_csv_path": str(ablation_csv),
        "png_path": str(roc_png),
        "analysis_md_path": str(analysis_md),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluasi penuh model CNN SIAKAR (ML_SPEC §6 & §7).")
    parser.add_argument("--config", type=str, default="configs/embedding.yaml")
    parser.add_argument("--model", type=str, default=None, help="Path ke .keras (training atau backbone)")
    parser.add_argument("--run-name", type=str, default="main_cnn", help="Nama run untuk tabel & laporan")
    parser.add_argument("--no-save-threshold", action="store_true", help="Jangan timpa artifacts/threshold.json (mis. saat evaluasi ablasi)")
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    data_cfg = cfg.get("data", {})
    train_cfg = cfg.get("training", {})
    export_cfg = cfg.get("export", {})

    splits_dir = Path(data_cfg.get("splits_dir", "data/splits"))
    model_path = args.model or train_cfg.get("training_model_path", "artifacts/embedding_training.keras")
    batch_size = int(train_cfg.get("batch_size", 32))
    threshold_out = export_cfg.get("threshold_path", "artifacts/threshold.json")

    res = evaluate_cnn_pipeline(
        model_path=model_path,
        split_path=cfg.get("split_output", str(splits_dir / "split.json")),
        pairs_val_path=splits_dir / "pairs_val.json",
        pairs_test_path=splits_dir / "pairs_test.json",
        preprocess_config_path=cfg.get("preprocess_config", "artifacts/preprocess.json"),
        reports_dir=cfg.get("reports_dir", "reports"),
        threshold_output_path=threshold_out,
        run_name=args.run_name,
        batch_size=batch_size,
        save_threshold=not args.no_save_threshold,
        base_dir=Path.cwd(),
    )

    r = res["row"]
    print("=" * 68)
    print(f"[evaluate] Evaluasi '{args.run_name}' selesai!")
    print(f"  - Klasifikasi Top-1 (A) : {r['cls_top1_acc']:.4f}")
    print(f"  - Ambang Validasi (B)   : {r['val_threshold']:.4f} (Val EER={r['val_eer']:.4f})")
    print(
        f"  - Uji Verifikasi (C)    : FAR={r['test_far']:.4f}, FRR={r['test_frr']:.4f}, "
        f"EER={r['test_eer']:.4f}, ROC AUC={r['test_roc_auc']:.4f}"
    )
    if res["threshold_path"]:
        print(f"  - threshold.json        : {res['threshold_path']}")
    print(f"  - Laporan analisis      : {res['analysis_md_path']}")
    print("=" * 68)


if __name__ == "__main__":
    main()
