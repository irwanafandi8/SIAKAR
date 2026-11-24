"""
test_split_and_prepare.py — Unit test untuk prepare_digiface.py & split.py (T-103, T-105)
menggunakan data dummy sintetis di tmp_path.
"""

from __future__ import annotations

import io
import json
import pathlib
import sys
import zipfile

import numpy as np
import pytest
from PIL import Image

_ML_ROOT = pathlib.Path(__file__).parent.parent
_SRC_DIR = _ML_ROOT / "src"
if str(_SRC_DIR) not in sys.path:
    sys.path.insert(0, str(_SRC_DIR))

from siakar_ml.data.prepare_digiface import (
    extract_digiface_subset,
    inspect_digiface_directory,
)
from siakar_ml.data.split import build_and_save_all_splits


def _make_tiny_png_bytes(seed: int) -> bytes:
    rng = np.random.default_rng(seed)
    arr = rng.integers(0, 256, size=(16, 16, 3), dtype=np.uint8)
    buf = io.BytesIO()
    Image.fromarray(arr).save(buf, format="PNG")
    return buf.getvalue()


@pytest.fixture()
def synthetic_digiface_dir(tmp_path: pathlib.Path) -> pathlib.Path:
    """Buat dataset sintetis mini: 20 identitas × 8 gambar (4 set aksesori × 2 gambar)."""
    raw_dir = tmp_path / "raw" / "digiface"
    raw_dir.mkdir(parents=True, exist_ok=True)
    (raw_dir / "LICENSE.txt").write_text("Synthetic test license", encoding="utf-8")

    for subj_idx in range(20):
        subj_dir = raw_dir / f"subj_{subj_idx:04d}"
        subj_dir.mkdir()
        for img_idx in range(8):
            png_bytes = _make_tiny_png_bytes(subj_idx * 100 + img_idx)
            (subj_dir / f"{img_idx}.png").write_bytes(png_bytes)

    return raw_dir


def test_extract_and_inspect_digiface_subset(tmp_path: pathlib.Path) -> None:
    zip_path = tmp_path / "mini_digiface.zip"
    with zipfile.ZipFile(zip_path, "w") as zf:
        zf.writestr("LICENSE", "Non-commercial research")
        for s in range(5):
            for k in range(4):
                zf.writestr(f"subj_{s:03d}/{k}.png", _make_tiny_png_bytes(s * 10 + k))

    target_dir = tmp_path / "extracted"
    ext = extract_digiface_subset(zip_path, target_dir, max_identities=3)
    assert ext["extracted_identities"] == 3
    assert ext["extracted_images"] == 12
    assert (target_dir / "LICENSE").exists()

    stats_path = tmp_path / "reports" / "dataset_stats.json"
    summary = inspect_digiface_directory(target_dir, stats_output=stats_path)
    assert summary["total_identities"] == 3
    assert summary["total_images"] == 12
    assert stats_path.exists()


def test_identity_splits_are_disjoint_and_accessory_heldout(
    synthetic_digiface_dir: pathlib.Path,
    tmp_path: pathlib.Path,
) -> None:
    out_dir = tmp_path / "splits_run1"
    result = build_and_save_all_splits(
        dataset_dir=synthetic_digiface_dir,
        output_dir=out_dir,
        n_identities=20,
        train_ratio=0.70,
        val_ratio=0.15,
        test_ratio=0.15,
        n_accessory_sets=4,
        heldout_accessory_idx=3,
        n_val_pairs=20,
        n_test_pairs=20,
        seed=42,
        base_dir=tmp_path,
    )

    split = result["split"]
    set_a = set(split["train_identities"])
    set_b = set(split["val_identities"])
    set_c = set(split["test_identities"])

    # Tidak boleh ada identitas yang sama di dua kelompok
    assert len(set_a) == 14
    assert len(set_b) == 3
    assert len(set_c) == 3
    assert set_a.isdisjoint(set_b)
    assert set_a.isdisjoint(set_c)
    assert set_b.isdisjoint(set_c)

    # Di dalam Kelompok A: gambar latih dan uji klasifikasi dipisah per set aksesori
    cls_train_paths = {item["path"] for item in split["classification"]["train"]}
    cls_test_paths = {item["path"] for item in split["classification"]["test"]}
    assert cls_train_paths.isdisjoint(cls_test_paths)
    # 8 gambar dibagi 4 set -> set ke-4 (indeks 6.png & 7.png) masuk ke classification.test
    for p in cls_test_paths:
        assert p.endswith("/6.png") or p.endswith("/7.png")

    # Cek keseimbangan dan isolasi identitas pada pairs_val & pairs_test
    for pairs, allowed_ids in [(result["pairs_val"], set_b), (result["pairs_test"], set_c)]:
        assert len(pairs) == 20
        labels = [p["label"] for p in pairs]
        assert labels.count(1) == 10
        assert labels.count(0) == 10
        for p in pairs:
            assert p["id1"] in allowed_ids
            assert p["id2"] in allowed_ids
            if p["is_same"]:
                assert p["id1"] == p["id2"]
                assert p["img1"] != p["img2"]
            else:
                assert p["id1"] != p["id2"]


def test_splits_and_pairs_are_deterministic_across_runs(
    synthetic_digiface_dir: pathlib.Path,
    tmp_path: pathlib.Path,
) -> None:
    out1 = tmp_path / "det_1"
    out2 = tmp_path / "det_2"

    build_and_save_all_splits(
        dataset_dir=synthetic_digiface_dir,
        output_dir=out1,
        n_identities=20,
        n_val_pairs=16,
        n_test_pairs=16,
        seed=123,
        base_dir=tmp_path,
    )
    build_and_save_all_splits(
        dataset_dir=synthetic_digiface_dir,
        output_dir=out2,
        n_identities=20,
        n_val_pairs=16,
        n_test_pairs=16,
        seed=123,
        base_dir=tmp_path,
    )

    for fname in ("split.json", "pairs_val.json", "pairs_test.json"):
        text1 = (out1 / fname).read_text(encoding="utf-8")
        text2 = (out2 / fname).read_text(encoding="utf-8")
        assert text1 == text2, f"{fname} berbeda antar-run pada seed yang sama!"
        # Pastikan juga valid JSON
        json.loads(text1)
