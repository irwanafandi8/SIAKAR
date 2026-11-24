"""
baseline_classic.py — Baseline klasik SIAKAR menggunakan HOG, LBP, dan gabungan HOG+LBP (T-106).

Sesuai ML_SPEC.md §3.2 & §6:
- Menggunakan pipeline praproses tunggal (preprocess.py) sebelum ekstraksi fitur grayscale.
- Ekstraksi fitur:
  1. HOG (Histogram of Oriented Gradients) ter-normalisasi L2
  2. LBP (Uniform Local Binary Pattern) histogram spasial per grid ter-normalisasi L2
  3. HOG+LBP gabungan ter-normalisasi L2
- Klasifikasi set tertutup (Kelompok A, set aksesori ditahan) dengan LinearSVC.
- Verifikasi set terbuka: pemilihan ambang EER pada pairs_val (Kelompok B), lalu evaluasi
  FAR, FRR, EER, ROC AUC, TAR@FAR(1%, 0.1%), dan akurasi pada pairs_test (Kelompok C)
  tanpa menyetel ulang hyperparameter pada data uji.
- Pembacaan gambar dari disk secara bertahap (tanpa memuat seluruh dataset ke RAM).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, Iterable, List, Literal, Optional, Sequence, Tuple

import numpy as np
import yaml
from skimage.color import rgb2gray
from skimage.feature import hog, local_binary_pattern
from skimage.io import imread

from siakar_ml.evaluate import (
    compute_classification_metrics,
    compute_verification_metrics,
    plot_roc_and_eer_curves,
    save_metrics_csv,
)
from siakar_ml.preprocess import load_preprocess_config, preprocess

BaselineMethod = Literal["hog", "lbp", "hog_lbp"]
SUPPORTED_METHODS: Tuple[BaselineMethod, ...] = ("hog", "lbp", "hog_lbp")


def _to_grayscale_unit(image: np.ndarray) -> np.ndarray:
    """Konversi citra RGB uint8 [0..255] atau hasil preprocess float32 [-1..1] ke grayscale [0..1]."""
    if image.ndim == 2:
        if image.dtype == np.uint8:
            return image.astype(np.float32) / 255.0
        if float(np.min(image)) < -1e-3:
            return np.clip((image.astype(np.float32) + 1.0) * 0.5, 0.0, 1.0)
        return np.clip(image.astype(np.float32), 0.0, 1.0)

    if image.dtype == np.uint8:
        rgb_unit = image.astype(np.float32) / 255.0
    elif float(np.min(image)) < -1e-3 or float(np.max(image)) <= 1.0 + 1e-3:
        if float(np.min(image)) < -1e-3:
            rgb_unit = np.clip((image.astype(np.float32) + 1.0) * 0.5, 0.0, 1.0)
        else:
            rgb_unit = np.clip(image.astype(np.float32), 0.0, 1.0)
    else:
        rgb_unit = np.clip(image.astype(np.float32) / 255.0, 0.0, 1.0)

    return rgb2gray(rgb_unit).astype(np.float32)


def _l2_normalize_vector(vec: np.ndarray) -> np.ndarray:
    arr = np.asarray(vec, dtype=np.float32).ravel()
    norm = float(np.linalg.norm(arr))
    if norm > 1e-12:
        arr = arr / norm
    return arr.astype(np.float32)


def extract_hog_features(
    image: np.ndarray,
    orientations: int = 8,
    pixels_per_cell: Tuple[int, int] = (16, 16),
    cells_per_block: Tuple[int, int] = (2, 2),
) -> np.ndarray:
    """Ekstraksi fitur HOG ter-normalisasi L2 dari citra RGB/grayscale."""
    gray = _to_grayscale_unit(image)
    features = hog(
        gray,
        orientations=orientations,
        pixels_per_cell=pixels_per_cell,
        cells_per_block=cells_per_block,
        block_norm="L2-Hys",
        visualize=False,
        feature_vector=True,
    )
    return _l2_normalize_vector(features)


def extract_lbp_features(
    image: np.ndarray,
    n_points: int = 8,
    radius: float = 1.0,
    grid_shape: Tuple[int, int] = (4, 4),
) -> np.ndarray:
    """Ekstraksi histogram spasial Uniform LBP per sel grid ter-normalisasi L2."""
    gray = _to_grayscale_unit(image)
    gray_u8 = np.clip(np.round(gray * 255.0), 0, 255).astype(np.uint8)

    lbp = local_binary_pattern(gray_u8, P=n_points, R=radius, method="uniform")
    n_bins = n_points + 2  # pola uniform P + 2 bin

    h, w = lbp.shape
    gh, gw = grid_shape
    histograms: List[np.ndarray] = []

    for r in range(gh):
        y1 = (r * h) // gh
        y2 = ((r + 1) * h) // gh
        for c in range(gw):
            x1 = (c * w) // gw
            x2 = ((c + 1) * w) // gw
            patch = lbp[y1:y2, x1:x2]
            hist, _ = np.histogram(patch.ravel(), bins=n_bins, range=(0, n_bins), density=False)
            histograms.append(hist.astype(np.float32))

    concat = np.concatenate(histograms, axis=0)
    return _l2_normalize_vector(concat)


def extract_classic_features(
    image_rgb: np.ndarray,
    preprocess_cfg: Dict[str, Any],
    method: BaselineMethod = "hog",
) -> np.ndarray:
    """Jalankan praproses standar SIAKAR lalu ekstrak fitur baseline klasik ('hog', 'lbp', 'hog_lbp')."""
    processed = preprocess(image_rgb, preprocess_cfg)

    if method == "hog":
        return extract_hog_features(processed)
    if method == "lbp":
        return extract_lbp_features(processed)
    if method == "hog_lbp":
        f_hog = extract_hog_features(processed)
        f_lbp = extract_lbp_features(processed)
        return _l2_normalize_vector(np.concatenate([f_hog, f_lbp], axis=0))

    raise ValueError(f"Metode baseline tidak dikenal: {method}. Pilih dari {SUPPORTED_METHODS}.")


def compute_baseline_similarity(vec_a: np.ndarray, vec_b: np.ndarray) -> float:
    """Hitung cosine similarity murni dalam [-1.0, 1.0] antara dua vektor fitur 1D."""
    a = np.asarray(vec_a, dtype=np.float64).ravel()
    b = np.asarray(vec_b, dtype=np.float64).ravel()
    if a.shape != b.shape or a.size == 0:
        raise ValueError("Dimensi kedua vektor fitur harus sama dan tidak kosong.")

    denom = float(np.linalg.norm(a) * np.linalg.norm(b))
    if denom <= 1e-12:
        return 0.0
    sim = float(np.dot(a, b) / denom)
    return max(-1.0, min(1.0, sim))


def load_rgb_image(image_path: str | Path) -> np.ndarray:
    """Baca satu citra dari disk sebagai array RGB uint8 [H, W, 3]."""
    img = imread(str(image_path))
    if img.ndim == 2:
        img = np.stack([img, img, img], axis=-1)
    elif img.ndim == 3 and img.shape[2] == 4:
        img = img[:, :, :3]
    if img.dtype != np.uint8:
        img = np.clip(img, 0, 255).astype(np.uint8)
    return img


class ClassicBaselineClassifier:
    """Klasifikator set tertutup menggunakan fitur klasik + Linear SVM.

    Menggunakan ``sklearn.svm.LinearSVC`` bila scikit-learn terpasang, atau optimisasi
    One-vs-Rest L2-regularized squared-hinge Linear SVM via ``scipy.optimize`` bila belum.
    """

    def __init__(self, seed: int = 42, c: float = 1.0, max_iter: int = 3000) -> None:
        self.seed = seed
        self.c = float(c)
        self.max_iter = int(max_iter)
        self._sk_clf: Any = None
        self._classes: Optional[np.ndarray] = None
        self._weights: Optional[np.ndarray] = None
        self._bias: Optional[np.ndarray] = None

        try:
            from sklearn.svm import LinearSVC

            self._sk_clf = LinearSVC(C=self.c, random_state=seed, max_iter=max_iter, dual="auto")
        except ImportError:
            self._sk_clf = None

    def fit(self, x_features: np.ndarray, y_labels: np.ndarray) -> "ClassicBaselineClassifier":
        x = np.asarray(x_features, dtype=np.float64)
        y = np.asarray(y_labels, dtype=np.int32).ravel()

        if self._sk_clf is not None:
            self._sk_clf.fit(x, y)
            return self

        from scipy.optimize import minimize

        classes = np.unique(y)
        n_samples, n_dim = x.shape
        weights = np.zeros((len(classes), n_dim), dtype=np.float64)
        bias = np.zeros(len(classes), dtype=np.float64)

        for idx, cls in enumerate(classes):
            y_bin = np.where(y == cls, 1.0, -1.0)

            def loss_and_grad(wb: np.ndarray) -> Tuple[float, np.ndarray]:
                w = wb[:-1]
                b = wb[-1]
                margins = 1.0 - y_bin * (x @ w + b)
                active = np.maximum(0.0, margins)
                loss = 0.5 * float(np.dot(w, w)) + self.c * float(np.sum(active ** 2)) / n_samples
                coeff = (-2.0 * self.c / n_samples) * active * y_bin
                grad_w = w + x.T @ coeff
                grad_b = float(np.sum(coeff))
                return loss, np.append(grad_w, grad_b)

            res = minimize(
                loss_and_grad,
                np.zeros(n_dim + 1, dtype=np.float64),
                jac=True,
                method="L-BFGS-B",
                options={"maxiter": self.max_iter},
            )
            weights[idx] = res.x[:-1]
            bias[idx] = res.x[-1]

        self._classes = classes
        self._weights = weights
        self._bias = bias
        return self

    def decision_function(self, x_features: np.ndarray) -> np.ndarray:
        x = np.asarray(x_features, dtype=np.float64)
        if self._sk_clf is not None:
            scores = self._sk_clf.decision_function(x)
            if scores.ndim == 1:
                scores = np.column_stack([-scores, scores])
            return scores

        assert self._weights is not None and self._bias is not None
        return x @ self._weights.T + self._bias

    def predict(self, x_features: np.ndarray) -> np.ndarray:
        if self._sk_clf is not None:
            return self._sk_clf.predict(x_features)

        assert self._classes is not None
        scores = self.decision_function(x_features)
        return self._classes[np.argmax(scores, axis=1)]

    def score(self, x_features: np.ndarray, y_labels: np.ndarray) -> float:
        preds = self.predict(x_features)
        return float(np.mean(preds == np.asarray(y_labels, dtype=np.int32).ravel()))


def _resolve_path(path_str: str, base_dir: Path) -> Path:
    p = Path(path_str)
    if p.is_absolute() and p.exists():
        return p
    candidate = base_dir / p
    if candidate.exists():
        return candidate
    return p


def _extract_features_streaming(
    paths: Iterable[str],
    preprocess_cfg: Dict[str, Any],
    method: BaselineMethod,
    base_dir: Path,
) -> Dict[str, np.ndarray]:
    """Ekstrak vektor fitur 1D per path unik secara bertahap tanpa menyimpan citra mentah di RAM."""
    cache: Dict[str, np.ndarray] = {}
    for rel_path in paths:
        if rel_path in cache:
            continue
        img_rgb = load_rgb_image(_resolve_path(rel_path, base_dir))
        cache[rel_path] = extract_classic_features(img_rgb, preprocess_cfg, method=method)
    return cache


def score_verification_pairs(
    pairs: Sequence[Dict[str, Any]],
    preprocess_cfg: Dict[str, Any],
    method: BaselineMethod,
    base_dir: Path,
) -> Tuple[np.ndarray, np.ndarray]:
    """Hitung skor cosine similarity dan label biner untuk daftar pasangan verifikasi."""
    unique_paths: List[str] = []
    for item in pairs:
        unique_paths.append(item["img1"])
        unique_paths.append(item["img2"])

    feat_map = _extract_features_streaming(unique_paths, preprocess_cfg, method, base_dir)

    similarities = np.empty(len(pairs), dtype=np.float32)
    labels = np.empty(len(pairs), dtype=np.int32)
    for idx, item in enumerate(pairs):
        similarities[idx] = compute_baseline_similarity(
            feat_map[item["img1"]],
            feat_map[item["img2"]],
        )
        labels[idx] = int(item["label"])
    return similarities, labels


def evaluate_baseline_method(
    split_data: Dict[str, Any],
    pairs_val: Sequence[Dict[str, Any]],
    pairs_test: Sequence[Dict[str, Any]],
    preprocess_cfg: Dict[str, Any],
    method: BaselineMethod = "hog",
    seed: int = 42,
    base_dir: str | Path = ".",
) -> Dict[str, Any]:
    """Evaluasi lengkap satu metode baseline klasik (klasifikasi Kelompok A + verifikasi B & C)."""
    root = Path(base_dir)

    # 1. Klasifikasi tertutup pada Kelompok A (set aksesori ditahan)
    cls_train = split_data["classification"]["train"]
    cls_test = split_data["classification"]["test"]

    cls_paths = [s["path"] for s in cls_train] + [s["path"] for s in cls_test]
    cls_feat_map = _extract_features_streaming(cls_paths, preprocess_cfg, method, root)

    x_train = np.vstack([cls_feat_map[s["path"]] for s in cls_train])
    y_train = np.array([int(s["label"]) for s in cls_train], dtype=np.int32)

    x_test = np.vstack([cls_feat_map[s["path"]] for s in cls_test])
    y_test = np.array([int(s["label"]) for s in cls_test], dtype=np.int32)

    inv_label_map = {int(v): k for k, v in split_data.get("label_map", {}).items()}

    clf = ClassicBaselineClassifier(seed=seed)
    clf.fit(x_train, y_train)
    y_pred = clf.predict(x_test)
    dec_scores = clf.decision_function(x_test)

    cls_metrics = compute_classification_metrics(
        y_true=y_test,
        y_pred=y_pred,
        decision_scores=dec_scores,
        id_names=inv_label_map,
    )

    del cls_feat_map, x_train, x_test

    # 2. Verifikasi pada Kelompok B (pilih ambang optimal pada titik EER)
    val_sims, val_labels = score_verification_pairs(pairs_val, preprocess_cfg, method, root)
    val_metrics = compute_verification_metrics(val_sims, val_labels, fixed_threshold=None)
    chosen_threshold = float(val_metrics["optimal_threshold"])

    # 3. Verifikasi pada Kelompok C menggunakan ambang tetap dari Kelompok B (tanpa tuning ulang)
    test_sims, test_labels = score_verification_pairs(pairs_test, preprocess_cfg, method, root)
    test_metrics = compute_verification_metrics(
        test_sims,
        test_labels,
        fixed_threshold=chosen_threshold,
    )

    return {
        "method": method,
        "classification": cls_metrics,
        "validation": val_metrics,
        "test": test_metrics,
    }


def run_baseline_suite(
    split_path: str | Path,
    pairs_val_path: str | Path,
    pairs_test_path: str | Path,
    preprocess_config_path: str | Path,
    reports_dir: str | Path,
    methods: Sequence[BaselineMethod] = ("hog", "lbp", "hog_lbp"),
    seed: int = 42,
    base_dir: str | Path = ".",
) -> Dict[str, Any]:
    """Jalankan eksperimen baseline klasik untuk daftar metode dan simpan CSV, JSON, & PNG."""
    with open(split_path, "r", encoding="utf-8") as f:
        split_data = json.load(f)
    with open(pairs_val_path, "r", encoding="utf-8") as f:
        pairs_val = json.load(f)
    with open(pairs_test_path, "r", encoding="utf-8") as f:
        pairs_test = json.load(f)

    preprocess_cfg = load_preprocess_config(str(preprocess_config_path))

    csv_rows: List[Dict[str, Any]] = []
    test_curves_for_plot: Dict[str, Dict[str, Any]] = {}
    summary_payload: Dict[str, Any] = {"seed": seed, "methods": {}}

    for method in methods:
        res = evaluate_baseline_method(
            split_data=split_data,
            pairs_val=pairs_val,
            pairs_test=pairs_test,
            preprocess_cfg=preprocess_cfg,
            method=method,
            seed=seed,
            base_dir=base_dir,
        )

        cls_m = res["classification"]
        val_m = res["validation"]
        tst_m = res["test"]

        csv_rows.append(
            {
                "method": method,
                "cls_top1_acc": round(cls_m["top1_accuracy"], 4),
                "cls_top5_acc": (
                    round(cls_m["top5_accuracy"], 4)
                    if cls_m["top5_accuracy"] is not None
                    else ""
                ),
                "val_threshold": round(val_m["optimal_threshold"], 4),
                "val_eer": round(val_m["eer"], 4),
                "val_roc_auc": round(val_m["roc_auc"], 4),
                "test_far": round(tst_m["far"], 4),
                "test_frr": round(tst_m["frr"], 4),
                "test_eer": round(tst_m["eer"], 4),
                "test_roc_auc": round(tst_m["roc_auc"], 4),
                "test_tar_far_1pct": round(tst_m["tar_at_far_1pct"], 4),
                "test_tar_far_01pct": round(tst_m["tar_at_far_01pct"], 4),
                "test_verif_acc": round(tst_m["accuracy"], 4),
            }
        )

        test_curves_for_plot[method] = tst_m

        # Simpan ringkasan JSON tanpa array kurva besar
        val_clean = {k: v for k, v in val_m.items() if k != "curves"}
        tst_clean = {k: v for k, v in tst_m.items() if k != "curves"}
        summary_payload["methods"][method] = {
            "classification": {
                "top1_accuracy": cls_m["top1_accuracy"],
                "top5_accuracy": cls_m["top5_accuracy"],
                "n_samples": cls_m["n_samples"],
                "n_classes": cls_m["n_classes"],
                "worst_identities": cls_m["worst_identities"],
            },
            "validation": val_clean,
            "test": tst_clean,
        }

    rep_dir = Path(reports_dir)
    rep_dir.mkdir(parents=True, exist_ok=True)

    csv_file = save_metrics_csv(csv_rows, rep_dir / "baseline_metrics.csv")
    png_file = plot_roc_and_eer_curves(
        test_curves_for_plot,
        rep_dir / "baseline_roc_eer.png",
        title_prefix="Baseline Klasik HOG / LBP (Uji Kelompok C)",
    )
    json_file = rep_dir / "baseline_summary.json"
    with open(json_file, "w", encoding="utf-8") as f:
        json.dump(summary_payload, f, indent=2)

    return {
        "rows": csv_rows,
        "csv_path": str(csv_file),
        "png_path": str(png_file),
        "json_path": str(json_file),
        "summary": summary_payload,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Evaluasi baseline klasik HOG/LBP sesuai protokol ML_SPEC §3.2 & §6 (T-106)."
    )
    parser.add_argument("--config", type=str, default="configs/embedding.yaml")
    parser.add_argument(
        "--methods",
        nargs="+",
        choices=list(SUPPORTED_METHODS),
        default=["hog", "lbp", "hog_lbp"],
        help="Metode fitur klasik yang dievaluasi.",
    )
    parser.add_argument("--splits-dir", type=str, default=None)
    parser.add_argument("--reports-dir", type=str, default=None)
    args = parser.parse_args()

    cfg: Dict[str, Any] = {}
    cfg_path = Path(args.config)
    if cfg_path.exists():
        with open(cfg_path, "r", encoding="utf-8") as f:
            cfg = yaml.safe_load(f) or {}

    data_cfg = cfg.get("data", {})
    splits_dir = Path(args.splits_dir or data_cfg.get("splits_dir", "data/splits"))
    reports_dir = Path(args.reports_dir or cfg.get("reports_dir", "reports"))
    preprocess_cfg_path = Path(cfg.get("preprocess_config", "artifacts/preprocess.json"))
    seed = int(data_cfg.get("seed", 42))

    result = run_baseline_suite(
        split_path=splits_dir / "split.json",
        pairs_val_path=splits_dir / "pairs_val.json",
        pairs_test_path=splits_dir / "pairs_test.json",
        preprocess_config_path=preprocess_cfg_path,
        reports_dir=reports_dir,
        methods=args.methods,
        seed=seed,
        base_dir=Path.cwd(),
    )

    print(f"[baseline_classic] Tabel metrik tersimpan di: {result['csv_path']}")
    print(f"[baseline_classic] Grafik ROC & FAR/FRR tersimpan di: {result['png_path']}")
    for row in result["rows"]:
        print(
            f"  - {row['method'].upper():7s} | "
            f"Cls Top-1={row['cls_top1_acc']:.4f} | "
            f"Val Thr={row['val_threshold']:.4f} | "
            f"Test FAR={row['test_far']:.4f}, FRR={row['test_frr']:.4f}, "
            f"EER={row['test_eer']:.4f}, AUC={row['test_roc_auc']:.4f}"
        )


if __name__ == "__main__":
    main()
