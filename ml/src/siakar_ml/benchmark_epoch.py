"""
benchmark_epoch.py — Benchmark 1 Epoch CNN Embedding SIAKAR pada CPU Lokal (ML4 / T-107).

Sesuai ML_SPEC.md §3.1, §2.1 & SIAKAR_prompt_per_fitur.md (ML4):
- Melatih model CNN embedding dari nol selama SATU epoch (atau 1 batch dry-run untuk verifikasi cepat)
  menggunakan pipeline tf.data dari disk + prefetch.
- Mengukur waktu per step, throughput (gambar/detik), total waktu 1 epoch, dan puncak penggunaan
  memori proses (Working Set / Peak RSS di Windows & POSIX + Python heap).
- Menghitung proyeksi waktu latihan penuh dan mengusulkan kombinasi (n_identities, input_size, batch_size)
  yang realistis untuk laptop CPU RAM 8 GB (untuk dicatat ke DECISIONS.md D-46).
- Menyimpan laporan ke ml/reports/benchmark_1epoch.json dan ml/reports/benchmark_1epoch.md.
"""

from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import json
import math
import sys
import time
import tracemalloc
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import tensorflow as tf
from tensorflow import keras
import yaml

from siakar_ml.data.dataset_loader import create_classification_dataset
from siakar_ml.models.embedding_cnn import build_training_model, extract_embedding_backbone
from siakar_ml.preprocess import load_preprocess_config


class _ProcessMemoryCounters(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("PageFaultCount", wintypes.DWORD),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
    ]


def get_process_memory_mb() -> Dict[str, float]:
    """Ambil Working Set (RSS) saat ini dan Peak Working Set proses dalam satuan MiB tanpa dependensi luar."""
    if sys.platform == "win32":
        try:
            kernel32 = ctypes.windll.kernel32
            kernel32.GetCurrentProcess.argtypes = []
            kernel32.GetCurrentProcess.restype = wintypes.HANDLE

            psapi = ctypes.windll.psapi
            psapi.GetProcessMemoryInfo.argtypes = [
                wintypes.HANDLE,
                ctypes.POINTER(_ProcessMemoryCounters),
                wintypes.DWORD,
            ]
            psapi.GetProcessMemoryInfo.restype = wintypes.BOOL

            counters = _ProcessMemoryCounters()
            counters.cb = ctypes.sizeof(_ProcessMemoryCounters)
            handle = kernel32.GetCurrentProcess()
            ok = psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb)
            if ok:
                return {
                    "rss_mb": round(counters.WorkingSetSize / (1024.0 * 1024.0), 2),
                    "peak_rss_mb": round(counters.PeakWorkingSetSize / (1024.0 * 1024.0), 2),
                }
        except OSError:
            pass
    else:
        try:
            import resource

            usage = resource.getrusage(resource.RUSAGE_SELF)
            divisor = (1024.0 * 1024.0) if sys.platform == "darwin" else 1024.0
            peak_mb = round(float(usage.ru_maxrss) / divisor, 2)
            return {"rss_mb": peak_mb, "peak_rss_mb": peak_mb}
        except Exception:
            pass

    current_py, peak_py = tracemalloc.get_traced_memory()
    return {
        "rss_mb": round(current_py / (1024.0 * 1024.0), 2),
        "peak_rss_mb": round(peak_py / (1024.0 * 1024.0), 2),
    }


def run_single_train_step(
    model: keras.Model,
    optimizer: keras.optimizers.Optimizer,
    loss_fn: keras.losses.Loss,
    batch_images: tf.Tensor,
    batch_labels: tf.Tensor,
) -> Tuple[float, tf.Tensor]:
    """Satu forward + backward pass + update gradien untuk verifikasi bentuk tensor & gradien."""
    with tf.GradientTape() as tape:
        probs = model(batch_images, training=True)
        loss_val = loss_fn(batch_labels, probs)

    grads = tape.gradient(loss_val, model.trainable_variables)
    valid_grads_and_vars = [
        (g, v) for g, v in zip(grads, model.trainable_variables) if g is not None
    ]
    if not valid_grads_and_vars:
        raise RuntimeError("Tidak ada gradien terhitung pada model CNN!")
    optimizer.apply_gradients(valid_grads_and_vars)
    return float(loss_val.numpy()), probs


def propose_hyperparameters(
    measured_img_per_sec: float,
    measured_input_size: int,
    peak_ram_mb: float,
    target_epochs: int = 30,
    max_budget_minutes: float = 120.0,
    train_ratio: float = 0.70,
    train_images_per_id: int = 54,
) -> Dict[str, Any]:
    """Hitung proyeksi waktu latihan penuh dan usulkan (n_identities, input_size, batch_size).

    Rumus estimasi:
    - Jumlah gambar latih Kelompok A ≈ round(n_identities * train_ratio) * 54
      (3 dari 4 set aksesori × 18 gambar pada DigiFace-1M).
    - Kecepatan pada ukuran input baru S diperkirakan berskala ~ (measured_input_size / S)^2
      karena biaya komputasi konvolusi 2D sebanding dengan luas spasial H × W.
    """
    candidates = [
        (1000, 112),
        (500, 112),
        (500, 96),
        (300, 96),
        (300, 64),
        (200, 64),
    ]

    safe_speed = max(measured_img_per_sec, 0.1)
    projections: List[Dict[str, Any]] = []
    chosen: Optional[Dict[str, Any]] = None

    for cand_n_id, cand_size in candidates:
        n_train_ids = max(2, int(round(cand_n_id * train_ratio)))
        n_train_imgs = n_train_ids * train_images_per_id
        area_scale = (float(measured_input_size) / float(cand_size)) ** 2
        est_speed = safe_speed * area_scale
        est_epoch_sec = n_train_imgs / est_speed
        est_total_min = (est_epoch_sec * target_epochs) / 60.0

        row = {
            "n_identities": cand_n_id,
            "n_train_identities": n_train_ids,
            "n_train_images": n_train_imgs,
            "input_size": cand_size,
            "est_images_per_sec": round(est_speed, 2),
            "est_epoch_sec": round(est_epoch_sec, 1),
            "est_total_minutes_30ep": round(est_total_min, 1),
            "fits_budget": est_total_min <= max_budget_minutes,
        }
        projections.append(row)
        if chosen is None and est_total_min <= max_budget_minutes:
            chosen = row

    if chosen is None:
        chosen = projections[-1]

    rec_batch_size = 32 if peak_ram_mb < 3500.0 else 16

    rationale = (
        f"Berdasarkan kecepatan ukur aktual {measured_img_per_sec:.2f} gambar/detik pada input "
        f"{measured_input_size}x{measured_input_size} (puncak RAM proses ~{peak_ram_mb:.1f} MB), "
        f"konfigurasi n_identities={chosen['n_identities']} ({chosen['n_train_images']} citra latih Kelompok A) "
        f"dengan input_size={chosen['input_size']} dan batch_size={rec_batch_size} membutuhkan "
        f"~{chosen['est_epoch_sec']:.1f} detik/epoch (~{chosen['est_total_minutes_30ep']:.1f} menit untuk "
        f"{target_epochs} epoch), sehingga aman dijalankan di CPU laptop RAM 8 GB."
    )

    return {
        "recommended_n_identities": chosen["n_identities"],
        "recommended_input_size": chosen["input_size"],
        "recommended_batch_size": rec_batch_size,
        "target_epochs": target_epochs,
        "max_budget_minutes": max_budget_minutes,
        "rationale": rationale,
        "projections": projections,
    }


def run_benchmark(
    dataset: tf.data.Dataset,
    num_classes: int,
    input_size: int = 112,
    embedding_dim: int = 128,
    stages: Optional[List[Dict[str, Any]]] = None,
    learning_rate: float = 1e-3,
    seed: int = 42,
    max_steps: Optional[int] = None,
    reports_dir: Optional[str | Path] = None,
) -> Dict[str, Any]:
    """Jalankan benchmark 1 epoch (atau dibatasi ``max_steps``) dan rekam waktu & memori."""
    tf.random.set_seed(seed)
    np.random.seed(seed)

    tracemalloc.start()
    mem_before = get_process_memory_mb()

    model = build_training_model(
        num_classes=num_classes,
        input_size=input_size,
        embedding_dim=embedding_dim,
        stages=stages,
        seed=seed,
    )
    backbone = extract_embedding_backbone(model)

    total_params = int(model.count_params())
    backbone_params = int(backbone.count_params())
    est_tflite_mb = round((backbone_params * 4) / (1024.0 * 1024.0), 3)

    optimizer = keras.optimizers.Adam(learning_rate=learning_rate)
    loss_fn = keras.losses.SparseCategoricalCrossentropy()

    @tf.function
    def _compiled_step(x_b: tf.Tensor, y_b: tf.Tensor) -> tf.Tensor:
        with tf.GradientTape() as tape:
            preds = model(x_b, training=True)
            loss = loss_fn(y_b, preds)
        grads = tape.gradient(loss, model.trainable_variables)
        optimizer.apply_gradients(zip(grads, model.trainable_variables))
        return loss

    step_times: List[float] = []
    losses: List[float] = []
    total_images = 0
    warmup_sec = 0.0
    peak_rss_mb = mem_before["peak_rss_mb"]

    epoch_start = time.perf_counter()
    for step_idx, (batch_x, batch_y) in enumerate(dataset):
        if max_steps is not None and step_idx >= max_steps:
            break

        t0 = time.perf_counter()
        loss_tensor = _compiled_step(batch_x, batch_y)
        loss_val = float(loss_tensor.numpy())
        dt = time.perf_counter() - t0

        batch_n = int(batch_x.shape[0])
        total_images += batch_n
        losses.append(loss_val)

        if step_idx == 0:
            warmup_sec = dt
        step_times.append(dt)

        mem_now = get_process_memory_mb()
        peak_rss_mb = max(peak_rss_mb, mem_now["peak_rss_mb"], mem_now["rss_mb"])

    total_wall_sec = time.perf_counter() - epoch_start
    mem_after = get_process_memory_mb()
    _, peak_py_bytes = tracemalloc.get_traced_memory()
    tracemalloc.stop()

    peak_rss_mb = max(peak_rss_mb, mem_after["peak_rss_mb"])

    # Gunakan langkah steady-state (setelah warmup kompilasi graf step 0) bila > 1 step
    if len(step_times) > 1:
        steady_sec = sum(step_times[1:])
        steady_steps = len(step_times) - 1
        avg_step_ms = (steady_sec / steady_steps) * 1000.0
        # Estimasi kecepatan murni steady-state
        avg_batch_size = total_images / len(step_times)
        images_per_sec = (avg_batch_size * steady_steps) / max(steady_sec, 1e-6)
    elif len(step_times) == 1:
        avg_step_ms = step_times[0] * 1000.0
        images_per_sec = total_images / max(step_times[0], 1e-6)
    else:
        raise ValueError("Dataset tidak menghasilkan batch satu pun saat benchmark.")

    proposal = propose_hyperparameters(
        measured_img_per_sec=images_per_sec,
        measured_input_size=input_size,
        peak_ram_mb=peak_rss_mb,
    )

    report: Dict[str, Any] = {
        "timestamp": datetime.now().isoformat(),
        "config_tested": {
            "input_size": input_size,
            "embedding_dim": embedding_dim,
            "num_classes": num_classes,
            "steps_executed": len(step_times),
            "total_images_processed": total_images,
        },
        "model_size": {
            "training_model_params": total_params,
            "backbone_params": backbone_params,
            "estimated_tflite_float32_mb": est_tflite_mb,
        },
        "timing": {
            "epoch_wall_seconds": round(total_wall_sec, 3),
            "warmup_first_step_seconds": round(warmup_sec, 3),
            "steady_avg_step_ms": round(avg_step_ms, 2),
            "steady_images_per_sec": round(images_per_sec, 2),
            "initial_loss": round(losses[0], 4),
            "final_loss": round(losses[-1], 4),
        },
        "memory": {
            "rss_before_mb": mem_before["rss_mb"],
            "rss_after_mb": mem_after["rss_mb"],
            "peak_rss_mb": round(peak_rss_mb, 2),
            "peak_python_heap_mb": round(peak_py_bytes / (1024.0 * 1024.0), 2),
        },
        "proposal": proposal,
    }

    if reports_dir is not None:
        out_dir = Path(reports_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        with open(out_dir / "benchmark_1epoch.json", "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        _write_markdown_report(report, out_dir / "benchmark_1epoch.md")

    return report


def _write_markdown_report(report: Dict[str, Any], md_path: Path) -> None:
    cfg = report["config_tested"]
    mdl = report["model_size"]
    tim = report["timing"]
    mem = report["memory"]
    prop = report["proposal"]

    lines = [
        "# Laporan Benchmark 1 Epoch CNN Embedding SIAKAR (T-107)",
        "",
        f"- **Tanggal Pengukuran**: `{report['timestamp']}`",
        f"- **Ukuran Input Diuji**: `{cfg['input_size']}x{cfg['input_size']}x3`",
        f"- **Jumlah Kelas (Kelompok A)**: `{cfg['num_classes']}`",
        f"- **Jumlah Gambar Diproses**: `{cfg['total_images_processed']}` ({cfg['steps_executed']} step)",
        f"- **Parameter Backbone**: `{mdl['backbone_params']:,}` (~`{mdl['estimated_tflite_float32_mb']} MB` float32 `.tflite`)",
        "",
        "## 1. Hasil Waktu & Memori",
        "",
        "| Metrik | Nilai |",
        "|---|---|",
        f"| Waktu total 1 epoch (wall-clock) | `{tim['epoch_wall_seconds']} detik` |",
        f"| Waktu langkah ke-1 (warmup graf) | `{tim['warmup_first_step_seconds']} detik` |",
        f"| Rata-rata waktu per batch (steady-state) | `{tim['steady_avg_step_ms']} ms` |",
        f"| Throughput steady-state | `{tim['steady_images_per_sec']} gambar/detik` |",
        f"| RAM proses sebelum latihan | `{mem['rss_before_mb']} MB` |",
        f"| Puncak RAM proses (Peak Working Set / RSS) | `{mem['peak_rss_mb']} MB` |",
        f"| Loss awal → akhir epoch 1 | `{tim['initial_loss']} → {tim['final_loss']}` |",
        "",
        "## 2. Proyeksi Waktu Latihan Penuh (30 Epoch, Kelompok A = 70% × 54 gambar)",
        "",
        "| `n_identities` | Identitas Latih (A) | Gambar Latih | `input_size` | Est. Gambar/dtk | Est. 1 Epoch (dtk) | Est. 30 Epoch (menit) |",
        "|---|---|---|---|---|---|---|",
    ]

    for p in prop["projections"]:
        lines.append(
            f"| {p['n_identities']} | {p['n_train_identities']} | {p['n_train_images']} | "
            f"{p['input_size']}x{p['input_size']} | {p['est_images_per_sec']} | "
            f"{p['est_epoch_sec']} | {p['est_total_minutes_30ep']} |"
        )

    lines.extend(
        [
            "",
            "## 3. Usulan Hyperparameter (Untuk Dicatat ke `DECISIONS.md` D-46)",
            "",
            f"- **Usulan `n_identities`**: `{prop['recommended_n_identities']}`",
            f"- **Usulan `input_size`**: `{prop['recommended_input_size']}`",
            f"- **Usulan `batch_size`**: `{prop['recommended_batch_size']}`",
            f"- **Alasan**: {prop['rationale']}",
            "",
        ]
    )

    md_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Benchmark 1 epoch CNN embedding dari nol untuk menentukan n_identities & input_size (T-107)."
    )
    parser.add_argument("--config", type=str, default="configs/embedding.yaml")
    parser.add_argument("--split", type=str, default=None, help="Path ke data/splits/split.json")
    parser.add_argument("--input-size", type=int, default=None, help="Override ukuran input (mis. 112, 96, 64)")
    parser.add_argument("--batch-size", type=int, default=None, help="Override batch size")
    parser.add_argument("--max-steps", type=int, default=None, help="Batasi jumlah batch (opsional untuk uji cepat)")
    parser.add_argument("--reports-dir", type=str, default=None, help="Folder output laporan")
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    model_cfg = cfg.get("model", {})
    data_cfg = cfg.get("data", {})
    train_cfg = cfg.get("training", {})

    preprocess_cfg_path = Path(cfg.get("preprocess_config", "artifacts/preprocess.json"))
    preprocess_cfg = load_preprocess_config(str(preprocess_cfg_path))

    input_size = int(args.input_size or model_cfg.get("input_size", preprocess_cfg["input_size"]))
    embedding_dim = int(model_cfg.get("embedding_dim", 128))
    stages = model_cfg.get("stages")
    batch_size = int(args.batch_size or train_cfg.get("batch_size", 32))
    lr = float(train_cfg.get("learning_rate", 1e-3))
    seed = int(data_cfg.get("seed", 42))
    reports_dir = Path(args.reports_dir or cfg.get("reports_dir", "reports"))

    split_path = Path(args.split or cfg.get("split_output", "data/splits/split.json"))
    if not split_path.exists():
        raise FileNotFoundError(
            f"Berkas split tidak ditemukan di {split_path}. "
            "Jalankan `python -m siakar_ml.data.split --config configs/embedding.yaml` terlebih dahulu."
        )

    with open(split_path, "r", encoding="utf-8") as f:
        split_data = json.load(f)

    cls_train_samples = split_data["classification"]["train"]
    num_classes = len(split_data["train_identities"])

    ds = create_classification_dataset(
        samples=cls_train_samples,
        preprocess_cfg=preprocess_cfg,
        batch_size=batch_size,
        training=True,
        seed=seed,
        base_dir=Path.cwd(),
        input_size_override=input_size,
    )

    print("=" * 68)
    print("SIAKAR — Benchmark 1 Epoch CNN Embedding (T-107)")
    print(f"Split         : {split_path} ({len(cls_train_samples)} gambar latih, {num_classes} identitas)")
    print(f"Input size    : [{input_size}, {input_size}, 3] | Batch size: {batch_size}")
    print("=" * 68)

    report = run_benchmark(
        dataset=ds,
        num_classes=num_classes,
        input_size=input_size,
        embedding_dim=embedding_dim,
        stages=stages,
        learning_rate=lr,
        seed=seed,
        max_steps=args.max_steps,
        reports_dir=reports_dir,
    )

    tim = report["timing"]
    mem = report["memory"]
    prop = report["proposal"]
    print(f"[benchmark_epoch] Waktu 1 epoch      : {tim['epoch_wall_seconds']} detik")
    print(f"[benchmark_epoch] Kecepatan steady   : {tim['steady_images_per_sec']} gambar/detik ({tim['steady_avg_step_ms']} ms/batch)")
    print(f"[benchmark_epoch] Puncak RAM proses  : {mem['peak_rss_mb']} MB")
    print(f"[benchmark_epoch] Usulan             : n_identities={prop['recommended_n_identities']}, input_size={prop['recommended_input_size']}, batch_size={prop['recommended_batch_size']}")
    print(f"[benchmark_epoch] Laporan disimpan   : {reports_dir / 'benchmark_1epoch.md'}")


if __name__ == "__main__":
    main()
