"""
prepare_digiface.py — Penyiapan & validasi subset DigiFace-1M di ml/data/raw/digiface (T-103).

Fitur:
- Opsional mengekstrak arsip .zip DigiFace-1M secara streaming (tanpa memuat seluruh zip ke RAM)
  dengan batas jumlah identitas (--max-identities) agar hemat ruang disk & memori.
- Memverifikasi struktur folder per identitas (subj_id/0.png ... k.png) dan keberadaan berkas LICENSE.
- Mencatat ringkasan statistik dataset ke ml/reports/dataset_stats.json.
"""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path
from typing import Dict, List, Optional

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg"}


def extract_digiface_subset(
    archive_path: str | Path,
    target_dir: str | Path,
    max_identities: Optional[int] = None,
) -> Dict[str, int]:
    """Ekstrak arsip ZIP DigiFace-1M secara streaming ke target_dir.

    Args:
        archive_path: Path ke berkas .zip DigiFace-1M.
        target_dir: Direktori tujuan (mis. ``ml/data/raw/digiface``).
        max_identities: Batas maksimum folder identitas yang diekstrak (None = semua).

    Returns:
        Dict berisi jumlah identitas dan jumlah berkas gambar yang diekstrak.
    """
    zip_path = Path(archive_path)
    if not zip_path.exists():
        raise FileNotFoundError(f"Arsip tidak ditemukan: {zip_path}")

    out_dir = Path(target_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    selected_subjects: set[str] = set()
    extracted_images = 0

    with zipfile.ZipFile(zip_path, "r") as zf:
        members = sorted(zf.namelist())

        for member in members:
            if member.endswith("/"):
                continue

            parts = Path(member).parts
            base_lower = parts[-1].lower()

            # Selalu ekstrak berkas LICENSE bila ada di dalam arsip
            if "license" in base_lower:
                dest_license = out_dir / parts[-1]
                with zf.open(member) as src, open(dest_license, "wb") as dst:
                    dst.write(src.read())
                continue

            suffix = Path(member).suffix.lower()
            if suffix not in IMAGE_EXTENSIONS or len(parts) < 2:
                continue

            subj_id = parts[-2]
            img_name = parts[-1]

            if subj_id not in selected_subjects:
                if max_identities is not None and len(selected_subjects) >= max_identities:
                    continue
                selected_subjects.add(subj_id)

            subj_dir = out_dir / subj_id
            subj_dir.mkdir(parents=True, exist_ok=True)
            dest_file = subj_dir / img_name

            if not dest_file.exists():
                with zf.open(member) as src, open(dest_file, "wb") as dst:
                    while True:
                        chunk = src.read(65536)
                        if not chunk:
                            break
                        dst.write(chunk)
            extracted_images += 1

    return {
        "extracted_identities": len(selected_subjects),
        "extracted_images": extracted_images,
    }


def inspect_digiface_directory(
    raw_dir: str | Path,
    stats_output: Optional[str | Path] = None,
) -> Dict[str, object]:
    """Periksa struktur dataset DigiFace-1M pada raw_dir tanpa memuat gambar ke RAM."""
    root = Path(raw_dir)
    if not root.exists():
        raise FileNotFoundError(
            f"Direktori dataset tidak ditemukan: {root}. "
            "Letakkan subset DigiFace-1M di ml/data/raw/digiface/<id_subjek>/*.png."
        )

    subj_dirs: List[Path] = sorted(
        [d for d in root.iterdir() if d.is_dir()],
        key=lambda p: p.name,
    )

    counts_per_subject: List[int] = []
    valid_subjects = 0

    for subj_dir in subj_dirs:
        n_imgs = sum(
            1
            for f in subj_dir.iterdir()
            if f.is_file() and f.suffix.lower() in IMAGE_EXTENSIONS
        )
        if n_imgs > 0:
            valid_subjects += 1
            counts_per_subject.append(n_imgs)

    license_files = [
        p.name
        for p in [root, root.parent]
        if p.exists()
        for f in p.iterdir()
        if f.is_file() and "license" in f.name.lower()
    ]

    total_images = int(sum(counts_per_subject))
    min_imgs = int(min(counts_per_subject)) if counts_per_subject else 0
    max_imgs = int(max(counts_per_subject)) if counts_per_subject else 0
    avg_imgs = round(total_images / valid_subjects, 2) if valid_subjects > 0 else 0.0

    summary: Dict[str, object] = {
        "dataset": "DigiFace-1M",
        "raw_dir": root.as_posix(),
        "total_identities": valid_subjects,
        "total_images": total_images,
        "min_images_per_identity": min_imgs,
        "max_images_per_identity": max_imgs,
        "avg_images_per_identity": avg_imgs,
        "license_files_found": license_files,
        "citation": (
            "Bae et al., 'DigiFace-1M: 1 Million Synthetic Faces for Face Recognition Validation', "
            "IEEE/CVF WACV 2023."
        ),
    }

    if stats_output is not None:
        out_path = Path(stats_output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(summary, f, indent=2)

    return summary


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Penyiapan dan validasi struktur subset DigiFace-1M (T-103)."
    )
    parser.add_argument(
        "--raw-dir",
        type=str,
        default="data/raw/digiface",
        help="Folder subset DigiFace-1M per identitas.",
    )
    parser.add_argument(
        "--archive",
        type=str,
        default=None,
        help="Opsional: path arsip .zip DigiFace-1M untuk diekstrak secara streaming.",
    )
    parser.add_argument(
        "--max-identities",
        type=int,
        default=None,
        help="Batas jumlah identitas saat mengekstrak arsip .zip.",
    )
    parser.add_argument(
        "--stats-out",
        type=str,
        default="reports/dataset_stats.json",
        help="Path keluaran JSON statistik dataset.",
    )
    args = parser.parse_args()

    if args.archive:
        ext_info = extract_digiface_subset(
            archive_path=args.archive,
            target_dir=args.raw_dir,
            max_identities=args.max_identities,
        )
        print(
            f"[prepare_digiface] Ekstraksi selesai: "
            f"{ext_info['extracted_identities']} identitas, "
            f"{ext_info['extracted_images']} gambar."
        )

    summary = inspect_digiface_directory(args.raw_dir, stats_output=args.stats_out)
    print(
        f"[prepare_digiface] Validasi sukses: {summary['total_identities']} identitas, "
        f"{summary['total_images']} gambar (rata-rata {summary['avg_images_per_identity']}/identitas)."
    )
    print(f"[prepare_digiface] Statistik disimpan ke: {args.stats_out}")


if __name__ == "__main__":
    main()
