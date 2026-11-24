"""
prepare_negatives.py — Generator & validator data negatif non-wajah untuk detektor wajah SIAKAR (T-108).

Sesuai DECISIONS.md D-40 (wajib tanpa foto wajah nyata) & D-44:
- Membangkitkan citra non-wajah sintetis beragam di ml/data/negatives/synthetic/ (pola gradien cahaya
  ruangan, kisi arsitektural, garis dinding/tirai, tekstur frekuensi multi-skala, blok geometri objek,
  dan derau optik) secara deterministik dan hemat disk.
- Memvalidasi dan menghitung seluruh citra negatif yang tersedia di ml/data/negatives/ (baik sintetis
  bawaan maupun dataset tekstur eksternal berlisensi riset seperti DTD / FractalDB).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List

import numpy as np
from PIL import Image

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg"}


def generate_procedural_nonface(idx: int, size: int = 96, seed: int = 42) -> np.ndarray:
    """Bangkitkan satu citra RGB uint8 non-wajah sintetis berdasarkan ragam pola latar."""
    rng = np.random.default_rng(seed * 100_000 + idx)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / max(size - 1, 1)
    mode = idx % 6

    if mode == 0:
        # Gradien pencahayaan dinding / langit-langit ruangan
        angle = float(rng.uniform(0, 2 * np.pi))
        proj = np.cos(angle) * xx + np.sin(angle) * yy
        base = rng.uniform(0.15, 0.85, size=(1, 1, 3)).astype(np.float32)
        slope = rng.uniform(-0.35, 0.35, size=(1, 1, 3)).astype(np.float32)
        img = base + slope * proj[:, :, None]
    elif mode == 1:
        # Pola garis arsitektural / tirai / ventilasi
        freq = float(rng.integers(4, 18))
        vertical = bool(idx % 2 == 0)
        coord = xx if vertical else yy
        stripes = 0.5 + 0.45 * np.sin(2.0 * np.pi * freq * coord + float(rng.uniform(0, np.pi)))
        tint = rng.uniform(0.3, 1.0, size=(1, 1, 3)).astype(np.float32)
        img = stripes[:, :, None] * tint
    elif mode == 2:
        # Pola papan catur / kisi ubin lantai & dinding
        cells = int(rng.integers(3, 12))
        gx = np.floor(xx * cells).astype(np.int32)
        gy = np.floor(yy * cells).astype(np.int32)
        board = ((gx + gy) % 2).astype(np.float32)
        c1 = rng.uniform(0.05, 0.45, size=(1, 1, 3)).astype(np.float32)
        c2 = rng.uniform(0.55, 0.95, size=(1, 1, 3)).astype(np.float32)
        img = board[:, :, None] * c1 + (1.0 - board[:, :, None]) * c2
    elif mode == 3:
        # Tekstur gelombang frekuensi multi-skala (meniru kain/kayu/marmer)
        f1, f2 = float(rng.uniform(2.0, 9.0)), float(rng.uniform(2.0, 9.0))
        tex = 0.5 + 0.25 * np.sin(2.0 * np.pi * f1 * xx) + 0.25 * np.cos(2.0 * np.pi * f2 * yy)
        color = rng.uniform(0.25, 0.95, size=(1, 1, 3)).astype(np.float32)
        img = tex[:, :, None] * color
    elif mode == 4:
        # Blok persegi panjang bertumpuk (meniru meja, monitor, pintu, lemari)
        img = np.broadcast_to(
            rng.uniform(0.1, 0.9, size=(1, 1, 3)).astype(np.float32),
            (size, size, 3),
        ).copy()
        for _ in range(int(rng.integers(2, 6))):
            r0, r1 = sorted(rng.integers(0, size, size=2).tolist())
            c0, c1 = sorted(rng.integers(0, size, size=2).tolist())
            img[r0:r1, c0:c1] = rng.uniform(0.0, 1.0, size=(3,)).astype(np.float32)
    else:
        # Derau optik sensor & tekstur granular halus
        img = rng.uniform(0.0, 1.0, size=(size, size, 3)).astype(np.float32)

    noise = rng.normal(0.0, 0.03, size=(size, size, 3)).astype(np.float32)
    out = np.clip((img + noise) * 255.0, 0, 255).astype(np.uint8)
    return out


def generate_synthetic_negatives(
    output_dir: str | Path,
    n_images: int = 1000,
    image_size: int = 96,
    seed: int = 42,
) -> Dict[str, object]:
    """Bangkitkan kumpulan citra negatif non-wajah ke ``output_dir/synthetic``."""
    root = Path(output_dir)
    synth_dir = root / "synthetic"
    synth_dir.mkdir(parents=True, exist_ok=True)

    created = 0
    for idx in range(n_images):
        dest = synth_dir / f"neg_{idx:05d}.png"
        if not dest.exists():
            arr = generate_procedural_nonface(idx=idx, size=image_size, seed=seed)
            Image.fromarray(arr).save(dest, format="PNG")
            created += 1

    all_negatives = list_negative_images(root)
    return {
        "negative_dir": root.as_posix(),
        "newly_created_synthetic": created,
        "total_negative_images": len(all_negatives),
    }


def list_negative_images(negative_dir: str | Path) -> List[Path]:
    """Daftar seluruh berkas gambar negatif secara rekursif dengan urutan deterministik."""
    root = Path(negative_dir)
    if not root.exists():
        return []
    files = [
        p
        for p in root.rglob("*")
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    ]
    files.sort(key=lambda p: p.as_posix())
    return files


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Bangkitkan & validasi data negatif non-wajah untuk detektor SIAKAR (T-108)."
    )
    parser.add_argument("--negative-dir", type=str, default="data/negatives")
    parser.add_argument("--n-synthetic", type=int, default=2000)
    parser.add_argument("--image-size", type=int, default=96)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--stats-out", type=str, default="reports/negative_dataset_stats.json")
    args = parser.parse_args()

    info = generate_synthetic_negatives(
        output_dir=args.negative_dir,
        n_images=args.n_synthetic,
        image_size=args.image_size,
        seed=args.seed,
    )

    stats_path = Path(args.stats_out)
    stats_path.parent.mkdir(parents=True, exist_ok=True)
    stats_path.write_text(json.dumps(info, indent=2), encoding="utf-8")

    print(
        f"[prepare_negatives] Selesai: total {info['total_negative_images']} citra non-wajah di "
        f"{info['negative_dir']} (baru dibuat: {info['newly_created_synthetic']})."
    )


if __name__ == "__main__":
    main()
