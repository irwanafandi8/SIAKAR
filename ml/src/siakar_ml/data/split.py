"""
split.py — Pemisahan dataset DigiFace-1M per identitas (Kelompok A, B, C),
pemisahan set aksesori untuk klasifikasi tertutup (Kelompok A), dan pembangkitan
pasangan verifikasi tetap deterministik (pairs_val.json & pairs_test.json).

Sesuai ML_SPEC.md §2.2 & §6.1–§6.2.
"""

from __future__ import annotations

import argparse
import json
import random
import re
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

import yaml

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg"}


def _natural_image_sort_key(path: Path) -> Tuple[int, str]:
    """Urutkan nama berkas gambar secara numerik (0.png, 1.png, ..., 71.png) lalu leksikografis."""
    match = re.search(r"(\d+)", path.stem)
    num = int(match.group(1)) if match else 10**9
    return (num, path.name)


def list_identity_images(subj_dir: Path, relative_to: Path | None = None) -> List[str]:
    """Daftar seluruh path gambar milik satu folder identitas dengan urutan deterministik."""
    files = [
        p
        for p in subj_dir.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    ]
    files.sort(key=_natural_image_sort_key)

    if relative_to is not None:
        try:
            return [f.relative_to(relative_to).as_posix() for f in files]
        except ValueError:
            pass
    return [f.as_posix() for f in files]


def partition_into_accessory_sets(
    images: Sequence[str],
    n_sets: int = 4,
) -> List[List[str]]:
    """Bagi daftar gambar terurut milik satu identitas ke dalam ``n_sets`` set aksesori.

    Pada DigiFace-1M (72 gambar = 4 set aksesori × 18 gambar), indeks 0..17, 18..35,
    36..53, dan 54..71 terpetakan langsung ke set 0, 1, 2, dan 3.
    Untuk jumlah gambar lebih sedikit (mis. subset 5 gambar atau data uji sintetis),
    pembagian kontigu menjaga urutan deterministik tanpa pengacakan per gambar.
    """
    n_sets = max(2, int(n_sets))
    total = len(images)
    if total == 0:
        return [[] for _ in range(n_sets)]

    sets: List[List[str]] = []
    for idx in range(n_sets):
        start = (idx * total) // n_sets
        end = ((idx + 1) * total) // n_sets
        sets.append(list(images[start:end]))
    return sets


def split_classification_images_by_accessory(
    images: Sequence[str],
    n_sets: int = 4,
    heldout_set_idx: int = 3,
) -> Tuple[List[str], List[str]]:
    """Pisahkan gambar identitas Kelompok A menjadi latih klasifikasi dan uji klasifikasi
    berdasarkan set aksesori (ML_SPEC.md §2.2 — DILARANG acak per gambar).
    """
    if len(images) < 2:
        return list(images), []

    sets = partition_into_accessory_sets(images, n_sets=n_sets)
    heldout_idx = min(max(0, heldout_set_idx), len(sets) - 1)

    train_imgs: List[str] = []
    test_imgs: List[str] = []
    for i, group in enumerate(sets):
        if i == heldout_idx:
            test_imgs.extend(group)
        else:
            train_imgs.extend(group)

    # Jaminan minimal 1 gambar uji dan 1 gambar latih bila jumlah gambar >= 2
    if not test_imgs:
        test_imgs = [train_imgs.pop()]
    elif not train_imgs:
        train_imgs = [test_imgs.pop(0)]

    return train_imgs, test_imgs


def create_splits(
    dataset_dir: str | Path,
    output_dir: str | Path,
    n_identities: int = 500,
    train_ratio: float = 0.70,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    n_accessory_sets: int = 4,
    heldout_accessory_idx: int = 3,
    seed: int = 42,
    base_dir: str | Path | None = None,
) -> Dict[str, Any]:
    """Bagi identitas dataset menjadi 3 kelompok tidak beririsan secara deterministik:
    - Kelompok A (train): melatih classifier + embedding; dibagi per set aksesori
      menjadi ``classification_train`` dan ``classification_test``.
    - Kelompok B (val): menentukan ambang verifikasi (EER) & hyperparameter.
    - Kelompok C (test): evaluasi akhir verifikasi identitas baru.
    """
    if abs((train_ratio + val_ratio + test_ratio) - 1.0) > 1e-6:
        raise ValueError("Jumlah train_ratio + val_ratio + test_ratio harus = 1.0.")

    data_path = Path(dataset_dir)
    if not data_path.exists():
        raise FileNotFoundError(f"Direktori dataset tidak ditemukan: {data_path}")

    rel_root = Path(base_dir) if base_dir is not None else None
    rng = random.Random(seed)

    # Hanya ambil folder identitas yang memiliki minimal 2 gambar
    valid_subj_dirs: List[Tuple[Path, List[str]]] = []
    for d in sorted([p for p in data_path.iterdir() if p.is_dir()], key=lambda p: p.name):
        imgs = list_identity_images(d, relative_to=rel_root)
        if len(imgs) >= 2:
            valid_subj_dirs.append((d, imgs))

    if len(valid_subj_dirs) < 3:
        raise ValueError(
            f"Dataset di {data_path} harus memiliki minimal 3 identitas dengan >=2 gambar "
            f"(ditemukan: {len(valid_subj_dirs)})."
        )

    selected = valid_subj_dirs[: min(n_identities, len(valid_subj_dirs))]
    rng.shuffle(selected)

    n_total = len(selected)
    n_val = max(1, int(round(n_total * val_ratio)))
    n_test = max(1, int(round(n_total * test_ratio)))
    n_train = n_total - n_val - n_test
    if n_train < 1:
        n_train = 1
        n_val = max(1, (n_total - n_train) // 2)
        n_test = n_total - n_train - n_val

    train_entries = sorted(selected[:n_train], key=lambda item: item[0].name)
    val_entries = sorted(selected[n_train : n_train + n_val], key=lambda item: item[0].name)
    test_entries = sorted(selected[n_train + n_val :], key=lambda item: item[0].name)

    cls_train_samples: List[Dict[str, Any]] = []
    cls_test_samples: List[Dict[str, Any]] = []
    label_map: Dict[str, int] = {}

    train_images_by_id: Dict[str, List[str]] = {}
    for class_idx, (subj_dir, imgs) in enumerate(train_entries):
        subj_id = subj_dir.name
        label_map[subj_id] = class_idx
        train_images_by_id[subj_id] = imgs
        tr_imgs, te_imgs = split_classification_images_by_accessory(
            imgs,
            n_sets=n_accessory_sets,
            heldout_set_idx=heldout_accessory_idx,
        )
        for p in tr_imgs:
            cls_train_samples.append({"path": p, "identity": subj_id, "label": class_idx})
        for p in te_imgs:
            cls_test_samples.append({"path": p, "identity": subj_id, "label": class_idx})

    val_images_by_id = {subj_dir.name: imgs for subj_dir, imgs in val_entries}
    test_images_by_id = {subj_dir.name: imgs for subj_dir, imgs in test_entries}

    split_payload: Dict[str, Any] = {
        "metadata": {
            "seed": seed,
            "dataset_dir": data_path.as_posix(),
            "n_identities_total": n_total,
            "n_train_identities": len(train_entries),
            "n_val_identities": len(val_entries),
            "n_test_identities": len(test_entries),
            "n_accessory_sets": n_accessory_sets,
            "heldout_accessory_idx": heldout_accessory_idx,
            "n_classification_train_images": len(cls_train_samples),
            "n_classification_test_images": len(cls_test_samples),
        },
        "train_identities": [d.name for d, _ in train_entries],
        "val_identities": [d.name for d, _ in val_entries],
        "test_identities": [d.name for d, _ in test_entries],
        "label_map": label_map,
        "classification": {
            "train": cls_train_samples,
            "test": cls_test_samples,
        },
        "images_by_identity": {
            "train": train_images_by_id,
            "val": val_images_by_id,
            "test": test_images_by_id,
        },
    }

    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    with open(out_path / "split.json", "w", encoding="utf-8") as f:
        json.dump(split_payload, f, indent=2)

    return split_payload


def generate_verification_pairs(
    dataset_dir: str | Path,
    identities: Sequence[str],
    n_pairs: int = 2000,
    n_accessory_sets: int = 4,
    seed: int = 42,
    base_dir: str | Path | None = None,
) -> List[Dict[str, Any]]:
    """Buat pasangan verifikasi tetap yang seimbang (50% genuine, 50% impostor).

    - Genuine: 2 gambar dari identitas sama, diutamakan berasal dari set aksesori berbeda.
    - Impostor: 2 gambar dari 2 identitas berbeda.
    """
    rng = random.Random(seed)
    data_path = Path(dataset_dir)
    rel_root = Path(base_dir) if base_dir is not None else None

    id_to_images: Dict[str, List[str]] = {}
    id_to_nonempty_sets: Dict[str, List[List[str]]] = {}

    for id_name in sorted(identities):
        subj_folder = data_path / id_name
        if not subj_folder.exists():
            continue
        imgs = list_identity_images(subj_folder, relative_to=rel_root)
        if len(imgs) >= 2:
            id_to_images[id_name] = imgs
            acc_sets = [s for s in partition_into_accessory_sets(imgs, n_sets=n_accessory_sets) if s]
            id_to_nonempty_sets[id_name] = acc_sets

    valid_ids = sorted(id_to_images.keys())
    if len(valid_ids) < 2 or n_pairs <= 0:
        return []

    n_genuine = n_pairs // 2
    n_impostor = n_pairs - n_genuine

    pairs: List[Dict[str, Any]] = []
    seen_genuine: set[Tuple[str, str]] = set()
    seen_impostor: set[Tuple[str, str]] = set()

    # 1. Pasangan Genuine (prioritaskan lintas set aksesori)
    max_tries = max(n_genuine * 20, 200)
    tries = 0
    while len(pairs) < n_genuine and tries < max_tries:
        tries += 1
        chosen_id = rng.choice(valid_ids)
        acc_sets = id_to_nonempty_sets[chosen_id]
        if len(acc_sets) >= 2:
            s1, s2 = rng.sample(acc_sets, 2)
            img1 = rng.choice(s1)
            img2 = rng.choice(s2)
        else:
            img1, img2 = rng.sample(id_to_images[chosen_id], 2)

        key = (img1, img2) if img1 <= img2 else (img2, img1)
        if key in seen_genuine and tries < max_tries // 2:
            continue
        seen_genuine.add(key)
        pairs.append(
            {
                "img1": img1,
                "img2": img2,
                "id1": chosen_id,
                "id2": chosen_id,
                "is_same": True,
                "label": 1,
            }
        )

    # Jika kombinasi unik habis pada dataset mini, lengkapi deterministik sampai tepat n_genuine
    while len(pairs) < n_genuine:
        chosen_id = rng.choice(valid_ids)
        img1, img2 = rng.sample(id_to_images[chosen_id], 2)
        pairs.append(
            {
                "img1": img1,
                "img2": img2,
                "id1": chosen_id,
                "id2": chosen_id,
                "is_same": True,
                "label": 1,
            }
        )

    # 2. Pasangan Impostor
    tries = 0
    max_imp_tries = max(n_impostor * 20, 200)
    while len(pairs) < (n_genuine + n_impostor) and tries < max_imp_tries:
        tries += 1
        id1, id2 = rng.sample(valid_ids, 2)
        img1 = rng.choice(id_to_images[id1])
        img2 = rng.choice(id_to_images[id2])

        key = (img1, img2) if img1 <= img2 else (img2, img1)
        if key in seen_impostor and tries < max_imp_tries // 2:
            continue
        seen_impostor.add(key)
        pairs.append(
            {
                "img1": img1,
                "img2": img2,
                "id1": id1,
                "id2": id2,
                "is_same": False,
                "label": 0,
            }
        )

    while len(pairs) < (n_genuine + n_impostor):
        id1, id2 = rng.sample(valid_ids, 2)
        img1 = rng.choice(id_to_images[id1])
        img2 = rng.choice(id_to_images[id2])
        pairs.append(
            {
                "img1": img1,
                "img2": img2,
                "id1": id1,
                "id2": id2,
                "is_same": False,
                "label": 0,
            }
        )

    rng.shuffle(pairs)
    return pairs


def build_and_save_all_splits(
    dataset_dir: str | Path,
    output_dir: str | Path,
    n_identities: int = 500,
    train_ratio: float = 0.70,
    val_ratio: float = 0.15,
    test_ratio: float = 0.15,
    n_accessory_sets: int = 4,
    heldout_accessory_idx: int = 3,
    n_val_pairs: int = 2000,
    n_test_pairs: int = 2000,
    seed: int = 42,
    base_dir: str | Path | None = None,
) -> Dict[str, Any]:
    """Jalankan pembuatan split.json, pairs_val.json, dan pairs_test.json sekaligus."""
    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    split_data = create_splits(
        dataset_dir=dataset_dir,
        output_dir=out_path,
        n_identities=n_identities,
        train_ratio=train_ratio,
        val_ratio=val_ratio,
        test_ratio=test_ratio,
        n_accessory_sets=n_accessory_sets,
        heldout_accessory_idx=heldout_accessory_idx,
        seed=seed,
        base_dir=base_dir,
    )

    pairs_val = generate_verification_pairs(
        dataset_dir=dataset_dir,
        identities=split_data["val_identities"],
        n_pairs=n_val_pairs,
        n_accessory_sets=n_accessory_sets,
        seed=seed + 1,
        base_dir=base_dir,
    )

    pairs_test = generate_verification_pairs(
        dataset_dir=dataset_dir,
        identities=split_data["test_identities"],
        n_pairs=n_test_pairs,
        n_accessory_sets=n_accessory_sets,
        seed=seed + 2,
        base_dir=base_dir,
    )

    with open(out_path / "pairs_val.json", "w", encoding="utf-8") as f:
        json.dump(pairs_val, f, indent=2)

    with open(out_path / "pairs_test.json", "w", encoding="utf-8") as f:
        json.dump(pairs_test, f, indent=2)

    return {
        "split": split_data,
        "pairs_val": pairs_val,
        "pairs_test": pairs_test,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Bagi dataset DigiFace-1M per identitas (A/B/C) & bangkitkan pasangan verifikasi tetap."
    )
    parser.add_argument("--config", type=str, default="configs/embedding.yaml")
    parser.add_argument("--dataset-dir", type=str, default=None)
    parser.add_argument("--output-dir", type=str, default=None)
    parser.add_argument("--n-identities", type=int, default=None)
    parser.add_argument("--n-val-pairs", type=int, default=None)
    parser.add_argument("--n-test-pairs", type=int, default=None)
    parser.add_argument("--seed", type=int, default=None)
    args = parser.parse_args()

    cfg: Dict[str, Any] = {}
    cfg_path = Path(args.config)
    if cfg_path.exists():
        with open(cfg_path, "r", encoding="utf-8") as f:
            cfg = yaml.safe_load(f) or {}

    data_cfg = cfg.get("data", {})
    dataset_dir = args.dataset_dir or data_cfg.get("raw_dir", "data/raw/digiface")
    output_dir = args.output_dir or data_cfg.get("splits_dir", "data/splits")
    n_identities = args.n_identities or int(data_cfg.get("n_identities", 500))
    train_ratio = float(data_cfg.get("train_ratio", 0.70))
    val_ratio = float(data_cfg.get("val_ratio", 0.15))
    test_ratio = float(data_cfg.get("test_ratio", 0.15))
    n_acc_sets = int(data_cfg.get("n_accessory_sets", 4))
    heldout_idx = int(data_cfg.get("heldout_accessory_idx", 3))
    n_val_pairs = args.n_val_pairs or int(data_cfg.get("n_val_pairs", 2000))
    n_test_pairs = args.n_test_pairs or int(data_cfg.get("n_test_pairs", 2000))
    seed = args.seed if args.seed is not None else int(data_cfg.get("seed", 42))

    result = build_and_save_all_splits(
        dataset_dir=dataset_dir,
        output_dir=output_dir,
        n_identities=n_identities,
        train_ratio=train_ratio,
        val_ratio=val_ratio,
        test_ratio=test_ratio,
        n_accessory_sets=n_acc_sets,
        heldout_accessory_idx=heldout_idx,
        n_val_pairs=n_val_pairs,
        n_test_pairs=n_test_pairs,
        seed=seed,
        base_dir=Path.cwd(),
    )

    meta = result["split"]["metadata"]
    print(
        f"[split] Selesai! Total identitas={meta['n_identities_total']} "
        f"(A={meta['n_train_identities']}, B={meta['n_val_identities']}, C={meta['n_test_identities']})"
    )
    print(
        f"[split] Klasifikasi Kelompok A: latih={meta['n_classification_train_images']} gambar, "
        f"uji={meta['n_classification_test_images']} gambar (set aksesori ke-{heldout_idx + 1})"
    )
    print(
        f"[split] Pasangan verifikasi: val={len(result['pairs_val'])}, "
        f"test={len(result['pairs_test'])} -> disimpan di {output_dir}"
    )


if __name__ == "__main__":
    main()
