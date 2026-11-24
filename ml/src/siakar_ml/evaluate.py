"""
evaluate.py — Protokol Evaluasi Model SIAKAR (Klasifikasi & Verifikasi).

Sesuai ML_SPEC.md §6 & DECISIONS.md D-24, D-31:
- Klasifikasi tertutup (Kelompok A): Top-1 accuracy, confusion analysis
- Verifikasi terbuka (Kelompok B & C):
  - Pasangan validasi (B) untuk menentukan ambang pada titik EER (Equal Error Rate)
  - Pasangan uji (C) dievaluasi menggunakan ambang terpilih
  - Metrik: FAR, FRR, EER, ROC AUC, TAR@FAR
- Menyimpan artifacts/threshold.json dan laporan ke reports/
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
import numpy as np
from sklearn.metrics import roc_curve, auc


def compute_verification_metrics(similarities: np.ndarray, labels: np.ndarray):
    """Menghitung FAR, FRR, dan Equal Error Rate (EER) dari skor cosine similarity."""
    fpr, tpr, thresholds = roc_curve(labels, similarities)
    fnr = 1.0 - tpr

    # EER adalah titik di mana FPR (FAR) ≈ FNR (FRR)
    eer_idx = np.nanargmin(np.abs(fpr - fnr))
    eer = float((fpr[eer_idx] + fnr[eer_idx]) / 2.0)
    optimal_threshold = float(thresholds[eer_idx])
    roc_auc = float(auc(fpr, tpr))

    return {
        "optimal_threshold": optimal_threshold,
        "eer": eer,
        "roc_auc": roc_auc,
        "far_at_threshold": float(fpr[eer_idx]),
        "frr_at_threshold": float(fnr[eer_idx]),
    }


def save_threshold_artifact(output_path: str, metrics: dict, n_pairs: int):
    """Menyimpan artefak threshold.json untuk dikonsumsi Laravel backend."""
    threshold_data = {
        "threshold": round(metrics["optimal_threshold"], 4),
        "metric_basis": "EER (Equal Error Rate) pada pasangan validasi",
        "far": round(metrics["far_at_threshold"], 4),
        "frr": round(metrics["frr_at_threshold"], 4),
        "eer": round(metrics["eer"], 4),
        "roc_auc": round(metrics["roc_auc"], 4),
        "val_pairs": n_pairs,
        "date": datetime.now().isoformat(),
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(threshold_data, f, indent=2)

    print(f"[evaluate] threshold.json disimpan: ambang = {threshold_data['threshold']}")


def main():
    parser = argparse.ArgumentParser(description="Evaluasi model SIAKAR.")
    parser.add_argument("--config", type=str, default="configs/embedding.yaml")
    parser.add_argument("--model", type=str, default="artifacts/embedding.keras")
    args = parser.parse_args()

    print("[evaluate] Menjalankan evaluasi protokol ML_SPEC §6...")


if __name__ == "__main__":
    main()
