"""
split.py — Pemisahan dataset DigiFace-1M per identitas (Kelompok A, B, C)
dan pembuatan pasangan verifikasi tetap (genuine & impostor).

Sesuai ML_SPEC.md §2.2 & §6.2.
"""

from __future__ import annotations

import json
import os
import random
from pathlib import Path
from typing import Dict, List, Tuple


def create_splits(
    dataset_dir: str,
    output_dir: str,
    n_identities: int = 500,
    train_ratio: float = 0.70,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    seed: int = 42,
) -> Dict[str, List[str]]:
    """Bagi identitas dataset menjadi 3 kelompok tidak beririsan:
    - Kelompok A: Identitas latih (classifier + embedding)
    - Kelompok B: Identitas validasi (menentukan ambang EER)
    - Kelompok C: Identitas uji (verifikasi identitas baru)
    """
    random.seed(seed)
    data_path = Path(dataset_dir)

    # Identifikasi folder identitas (format DigiFace: subj_id_x atau folder numerik)
    all_subj_dirs = [d for d in data_path.iterdir() if d.is_dir()]
    all_subj_dirs.sort(key=lambda p: p.name)

    if not all_subj_dirs:
        print(f"[split] Peringatan: Tidak ada folder identitas di {dataset_dir}")
        return {"train": [], "val": [], "test": []}

    # Batasi ke n_identities
    selected_dirs = all_subj_dirs[:n_identities]
    random.shuffle(selected_dirs)

    n_total = len(selected_dirs)
    n_train = int(n_total * train_ratio)
    n_val = int(n_total * val_ratio)

    train_dirs = selected_dirs[:n_train]
    val_dirs = selected_dirs[n_train : n_train + n_val]
    test_dirs = selected_dirs[n_train + n_val :]

    splits = {
        "train_identities": [d.name for d in train_dirs],
        "val_identities": [d.name for d in val_dirs],
        "test_identities": [d.name for d in test_dirs],
    }

    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    with open(out_path / "split.json", "w", encoding="utf-8") as f:
        json.dump(splits, f, indent=2)

    print(
        f"[split] Sukses membagi {n_total} identitas: "
        f"Latih (A)={len(train_dirs)}, Validasi (B)={len(val_dirs)}, Uji (C)={len(test_dirs)}"
    )
    return splits


def generate_verification_pairs(
    dataset_dir: str,
    identities: List[str],
    n_pairs: int = 2000,
    seed: int = 42,
) -> List[Dict[str, any]]:
    """Buat pasangan verifikasi tetap (seimbang: 50% genuine, 50% impostor).
    - Genuine: 2 gambar dari identitas yang sama.
    - Impostor: 2 gambar dari identitas berbeda.
    """
    random.seed(seed)
    data_path = Path(dataset_dir)

    # Kumpulkan gambar per identitas
    id_to_images: Dict[str, List[str]] = {}
    for id_name in identities:
        subj_folder = data_path / id_name
        if subj_folder.exists():
            imgs = [str(p) for p in subj_folder.glob("*.png")] + [
                str(p) for p in subj_folder.glob("*.jpg")
            ]
            if len(imgs) >= 2:
                id_to_images[id_name] = imgs

    valid_ids = list(id_to_images.keys())
    if len(valid_ids) < 2:
        return []

    pairs = []
    n_genuine = n_pairs // 2
    n_impostor = n_pairs - n_genuine

    # 1. Genuine Pairs
    for _ in range(n_genuine):
        chosen_id = random.choice(valid_ids)
        img1, img2 = random.sample(id_to_images[chosen_id], 2)
        pairs.append({"img1": img1, "img2": img2, "is_same": True, "label": 1})

    # 2. Impostor Pairs
    for _ in range(n_impostor):
        id1, id2 = random.sample(valid_ids, 2)
        img1 = random.choice(id_to_images[id1])
        img2 = random.choice(id_to_images[id2])
        pairs.append({"img1": img1, "img2": img2, "is_same": False, "label": 0})

    random.shuffle(pairs)
    return pairs
