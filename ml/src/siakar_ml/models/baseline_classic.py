"""
baseline_classic.py — Baseline klasik SIAKAR menggunakan HOG / LBP.

Sesuai ML_SPEC.md §3.2:
- HOG (Histogram of Oriented Gradients) dan LBP sebagai pembanding metode klasik
- Cosine similarity untuk verifikasi
- Linear SVM untuk klasifikasi
"""

from __future__ import annotations

import numpy as np
from skimage.color import rgb2gray
from skimage.feature import hog, local_binary_pattern
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.svm import LinearSVC


def extract_hog_features(image_rgb: np.ndarray, input_size: int = 112) -> np.ndarray:
    """Ekstraksi fitur HOG dari gambar RGB."""
    gray = rgb2gray(image_rgb)
    features = hog(
        gray,
        orientations=8,
        pixels_per_cell=(16, 16),
        cells_per_block=(1, 1),
        visualize=False,
    )
    # L2-normalize fitur HOG
    norm = np.linalg.norm(features)
    if norm > 1e-12:
        features = features / norm
    return features.astype(np.float32)


def compute_baseline_similarity(vec_a: np.ndarray, vec_b: np.ndarray) -> float:
    """Cosine similarity antara dua vektor fitur baseline."""
    vec_a = vec_a.reshape(1, -1)
    vec_b = vec_b.reshape(1, -1)
    return float(cosine_similarity(vec_a, vec_b)[0, 0])


class ClassicBaselineClassifier:
    """Classifier baseline klasik menggunakan HOG + Linear SVM."""

    def __init__(self):
        self.clf = LinearSVC(random_state=42, max_iter=2000)

    def fit(self, X_features: np.ndarray, y_labels: np.ndarray):
        self.clf.fit(X_features, y_labels)

    def predict(self, X_features: np.ndarray) -> np.ndarray:
        return self.clf.predict(X_features)

    def score(self, X_features: np.ndarray, y_labels: np.ndarray) -> float:
        return self.clf.score(X_features, y_labels)
