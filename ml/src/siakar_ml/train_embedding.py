"""
train_embedding.py — Pelatihan penuh model embedding CNN SIAKAR dari nol (ML5 / T-201..T-203).

Sesuai ML_SPEC.md §2.3, §3.1, §6.3 & DECISIONS.md D-20..D-22, D-46:
- Membaca citra dari disk menggunakan tf.data + prefetch (tanpa memuat seluruh dataset ke RAM).
- Augmentasi hanya diterapkan pada data latih (dapat dimatikan untuk ablasi --no-augmentation).
- Menyimpan checkpoint di setiap epoch (mendukung --resume otomatis maupun path eksplisit).
- Menyertakan ReduceLROnPlateau, EarlyStopping (restore_best_weights), CSVLogger, dan kurva PNG.
- Mengekstrak & menyimpan model backbone murni (tanpa kepala softmax/cosface) siap ekspor TFLite.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
import tensorflow as tf
from tensorflow import keras
import yaml

from siakar_ml.data.dataset_loader import create_classification_dataset
from siakar_ml.models.embedding_cnn import (
    CUSTOM_OBJECTS,
    HeadType,
    build_training_loss,
    build_training_model,
    extract_embedding_backbone,
)
from siakar_ml.preprocess import load_preprocess_config


class EpochStateCheckpoint(keras.callbacks.Callback):
    """Simpan model penuh di akhir tiap epoch beserta state JSON agar mudah di-resume."""

    def __init__(self, checkpoint_dir: Path, run_name: str) -> None:
        super().__init__()
        self.checkpoint_dir = checkpoint_dir
        self.run_name = run_name
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)

    def on_epoch_end(self, epoch: int, logs: Optional[Dict[str, Any]] = None) -> None:
        logs = logs or {}
        epoch_num = epoch + 1
        ckpt_file = self.checkpoint_dir / f"{self.run_name}_epoch_{epoch_num:03d}.keras"
        latest_file = self.checkpoint_dir / f"{self.run_name}_latest.keras"
        state_file = self.checkpoint_dir / f"{self.run_name}_state.json"

        self.model.save(ckpt_file)
        self.model.save(latest_file)

        state = {
            "run_name": self.run_name,
            "last_completed_epoch": epoch_num,
            "latest_checkpoint": str(latest_file),
            "metrics": {k: float(v) for k, v in logs.items() if isinstance(v, (int, float, np.floating))},
        }
        state_file.write_text(json.dumps(state, indent=2), encoding="utf-8")


def plot_training_curves(history_csv_path: Path, output_png_path: Path, run_name: str) -> Path:
    """Gambar kurva loss dan akurasi (latih vs validasi) dari berkas CSV riwayat pelatihan."""
    output_png_path.parent.mkdir(parents=True, exist_ok=True)

    epochs: List[int] = []
    train_loss: List[float] = []
    val_loss: List[float] = []
    train_acc: List[float] = []
    val_acc: List[float] = []

    if history_csv_path.exists():
        with open(history_csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                epochs.append(int(row.get("epoch", len(epochs))) + 1)
                train_loss.append(float(row.get("loss", 0.0)))
                val_loss.append(float(row.get("val_loss", 0.0)))
                train_acc.append(float(row.get("accuracy", 0.0)))
                val_acc.append(float(row.get("val_accuracy", 0.0)))

    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))
        axes[0].plot(epochs, train_loss, marker="o", label="Latih")
        if val_loss:
            axes[0].plot(epochs, val_loss, marker="s", label="Validasi")
        axes[0].set_title(f"Kurva Loss ({run_name})")
        axes[0].set_xlabel("Epoch")
        axes[0].set_ylabel("Loss")
        axes[0].grid(True, alpha=0.3)
        axes[0].legend()

        axes[1].plot(epochs, train_acc, marker="o", label="Latih")
        if val_acc:
            axes[1].plot(epochs, val_acc, marker="s", label="Validasi")
        axes[1].set_title(f"Kurva Akurasi ({run_name})")
        axes[1].set_xlabel("Epoch")
        axes[1].set_ylabel("Akurasi Top-1")
        axes[1].set_ylim(0.0, 1.02)
        axes[1].grid(True, alpha=0.3)
        axes[1].legend()

        fig.tight_layout()
        fig.savefig(output_png_path, dpi=150)
        plt.close(fig)
        return output_png_path
    except ImportError:
        from PIL import Image, ImageDraw

        img = Image.new("RGB", (800, 360), (255, 254, 242))
        draw = ImageDraw.Draw(img)
        draw.rectangle([40, 40, 760, 320], outline=(30, 30, 73), width=2)
        draw.text(
            (50, 16),
            f"Kurva Pelatihan ({run_name}) - Epochs={len(epochs)}",
            fill=(30, 30, 73),
        )
        if train_acc:
            draw.text(
                (60, 60),
                f"Loss akhir: {train_loss[-1]:.4f} | Val Loss: {val_loss[-1]:.4f}",
                fill=(51, 143, 74),
            )
            draw.text(
                (60, 90),
                f"Acc akhir : {train_acc[-1]:.4f} | Val Acc : {val_acc[-1]:.4f}",
                fill=(30, 30, 73),
            )
        img.save(output_png_path, format="PNG")
        return output_png_path


def train_embedding_pipeline(
    split_path: str | Path,
    preprocess_config_path: str | Path,
    checkpoint_dir: str | Path,
    reports_dir: str | Path,
    training_model_out: str | Path,
    backbone_model_out: str | Path,
    run_name: str = "main_cnn",
    input_size: Optional[int] = None,
    embedding_dim: int = 128,
    stages: Optional[List[Dict[str, Any]]] = None,
    head_type: HeadType = "softmax",
    cosface_scale: float = 30.0,
    cosface_margin: float = 0.20,
    use_augmentation: bool = True,
    batch_size: int = 32,
    epochs: int = 30,
    learning_rate: float = 1e-3,
    min_learning_rate: float = 1e-6,
    early_stopping_patience: int = 8,
    reduce_lr_patience: int = 4,
    reduce_lr_factor: float = 0.5,
    seed: int = 42,
    resume_from: Optional[str | Path] = None,
    max_steps_per_epoch: Optional[int] = None,
    max_val_steps: Optional[int] = None,
    base_dir: str | Path = ".",
) -> Dict[str, Any]:
    """Jalankan pelatihan model embedding CNN lengkap dengan checkpointing & early stopping."""
    tf.random.set_seed(seed)
    np.random.seed(seed)

    preprocess_cfg = load_preprocess_config(str(preprocess_config_path))
    resolved_input_size = int(input_size or preprocess_cfg["input_size"])

    with open(split_path, "r", encoding="utf-8") as f:
        split_data = json.load(f)

    cls_train = split_data["classification"]["train"]
    cls_val = split_data["classification"]["test"]
    num_classes = len(split_data["train_identities"])

    train_ds = create_classification_dataset(
        samples=cls_train,
        preprocess_cfg=preprocess_cfg,
        batch_size=batch_size,
        training=use_augmentation,
        seed=seed,
        base_dir=base_dir,
        input_size_override=resolved_input_size,
    )
    val_ds = create_classification_dataset(
        samples=cls_val,
        preprocess_cfg=preprocess_cfg,
        batch_size=batch_size,
        training=False,
        seed=seed,
        base_dir=base_dir,
        input_size_override=resolved_input_size,
    )

    if max_steps_per_epoch is not None:
        train_ds = train_ds.take(max_steps_per_epoch)
    if max_val_steps is not None:
        val_ds = val_ds.take(max_val_steps)

    ckpt_dir = Path(checkpoint_dir)
    ckpt_dir.mkdir(parents=True, exist_ok=True)
    rep_dir = Path(reports_dir)
    rep_dir.mkdir(parents=True, exist_ok=True)

    initial_epoch = 0
    loss_fn = build_training_loss(
        head_type=head_type,
        num_classes=num_classes,
        cosface_scale=cosface_scale,
        cosface_margin=cosface_margin,
    )

    if resume_from is not None:
        resume_path = Path(resume_from)
        state_file = ckpt_dir / f"{run_name}_state.json"
        if resume_path.is_dir():
            if state_file.exists():
                state_info = json.loads(state_file.read_text(encoding="utf-8"))
                initial_epoch = int(state_info.get("last_completed_epoch", 0))
                resume_path = Path(state_info["latest_checkpoint"])
            else:
                raise FileNotFoundError(f"State resume tidak ditemukan di {state_file}")
        elif state_file.exists():
            state_info = json.loads(state_file.read_text(encoding="utf-8"))
            if Path(state_info.get("latest_checkpoint", "")) == resume_path:
                initial_epoch = int(state_info.get("last_completed_epoch", 0))

        model = keras.models.load_model(resume_path, custom_objects=CUSTOM_OBJECTS)
    else:
        model = build_training_model(
            num_classes=num_classes,
            input_size=resolved_input_size,
            embedding_dim=embedding_dim,
            stages=stages,
            head_type=head_type,
            seed=seed,
        )
        optimizer = keras.optimizers.Adam(learning_rate=learning_rate)
        model.compile(
            optimizer=optimizer,
            loss=loss_fn,
            metrics=[keras.metrics.SparseCategoricalAccuracy(name="accuracy")],
        )

    best_ckpt_path = ckpt_dir / f"{run_name}_best.keras"
    history_csv_path = rep_dir / f"training_history_{run_name}.csv"
    curves_png_path = rep_dir / f"training_curves_{run_name}.png"

    callbacks: List[keras.callbacks.Callback] = [
        EpochStateCheckpoint(checkpoint_dir=ckpt_dir, run_name=run_name),
        keras.callbacks.ModelCheckpoint(
            filepath=str(best_ckpt_path),
            monitor="val_loss",
            save_best_only=True,
            verbose=0,
        ),
        keras.callbacks.CSVLogger(
            filename=str(history_csv_path),
            append=initial_epoch > 0,
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=reduce_lr_factor,
            patience=reduce_lr_patience,
            min_lr=min_learning_rate,
            verbose=1,
        ),
        keras.callbacks.EarlyStopping(
            monitor="val_loss",
            patience=early_stopping_patience,
            restore_best_weights=True,
            verbose=1,
        ),
    ]

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs,
        initial_epoch=initial_epoch,
        callbacks=callbacks,
        verbose=1,
    )

    train_out_path = Path(training_model_out)
    train_out_path.parent.mkdir(parents=True, exist_ok=True)
    model.save(train_out_path)

    backbone = extract_embedding_backbone(model)
    backbone_out_path = Path(backbone_model_out)
    backbone_out_path.parent.mkdir(parents=True, exist_ok=True)
    backbone.save(backbone_out_path)

    plot_training_curves(history_csv_path, curves_png_path, run_name=run_name)

    return {
        "run_name": run_name,
        "epochs_ran": len(history.history.get("loss", [])),
        "initial_epoch": initial_epoch,
        "training_model_path": str(train_out_path),
        "backbone_model_path": str(backbone_out_path),
        "best_checkpoint_path": str(best_ckpt_path),
        "history_csv_path": str(history_csv_path),
        "curves_png_path": str(curves_png_path),
        "final_metrics": {k: float(v[-1]) for k, v in history.history.items() if v},
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Latih model embedding CNN SIAKAR dari nol (ML5).")
    parser.add_argument("--config", type=str, default="configs/embedding.yaml")
    parser.add_argument("--run-name", type=str, default=None, help="Nama run (mis. main_cnn, abl_no_aug, abl_dim64)")
    parser.add_argument("--resume", type=str, default=None, help="Path file .keras atau folder checkpoint untuk resume")
    parser.add_argument("--epochs", type=int, default=None, help="Override jumlah maksimum epoch")
    parser.add_argument("--batch-size", type=int, default=None, help="Override batch size")
    parser.add_argument("--embedding-dim", type=int, default=None, help="Override dimensi embedding (mis. 64 atau 128)")
    parser.add_argument("--input-size", type=int, default=None, help="Override input size")
    parser.add_argument("--head-type", choices=["softmax", "cosface"], default=None, help="Kepala klasifikasi")
    parser.add_argument("--no-augmentation", action="store_true", help="Matikan augmentasi latih (untuk ablasi)")
    parser.add_argument("--output-model", type=str, default=None, help="Override path simpan model latihan (.keras)")
    parser.add_argument("--output-backbone", type=str, default=None, help="Override path simpan model backbone (.keras)")
    parser.add_argument("--max-steps-per-epoch", type=int, default=None, help="Batasi step/epoch (untuk uji cepat)")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    with open(args.config, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f) or {}

    model_cfg = cfg.get("model", {})
    data_cfg = cfg.get("data", {})
    train_cfg = cfg.get("training", {})

    run_name = args.run_name or str(train_cfg.get("run_name", "main_cnn"))
    use_aug = False if args.no_augmentation else bool(train_cfg.get("use_augmentation", True))
    emb_dim = int(args.embedding_dim or model_cfg.get("embedding_dim", 128))
    head_type: HeadType = args.head_type or model_cfg.get("head_type", "softmax")
    epochs = int(args.epochs or train_cfg.get("epochs", 30))
    batch_size = int(args.batch_size or train_cfg.get("batch_size", 32))
    input_size = args.input_size or model_cfg.get("input_size")

    default_train_out = train_cfg.get("training_model_path", "artifacts/embedding_training.keras")
    default_back_out = train_cfg.get("backbone_model_path", "artifacts/embedding_backbone.keras")
    if run_name != "main_cnn" and args.output_model is None:
        default_train_out = f"artifacts/{run_name}_training.keras"
    if run_name != "main_cnn" and args.output_backbone is None:
        default_back_out = f"artifacts/{run_name}_backbone.keras"

    result = train_embedding_pipeline(
        split_path=cfg.get("split_output", "data/splits/split.json"),
        preprocess_config_path=cfg.get("preprocess_config", "artifacts/preprocess.json"),
        checkpoint_dir=train_cfg.get("checkpoint_dir", "artifacts/checkpoints/embedding"),
        reports_dir=cfg.get("reports_dir", "reports"),
        training_model_out=args.output_model or default_train_out,
        backbone_model_out=args.output_backbone or default_back_out,
        run_name=run_name,
        input_size=int(input_size) if input_size is not None else None,
        embedding_dim=emb_dim,
        stages=model_cfg.get("stages"),
        head_type=head_type,
        cosface_scale=float(model_cfg.get("cosface_scale", 30.0)),
        cosface_margin=float(model_cfg.get("cosface_margin", 0.20)),
        use_augmentation=use_aug,
        batch_size=batch_size,
        epochs=epochs,
        learning_rate=float(train_cfg.get("learning_rate", 1e-3)),
        min_learning_rate=float(train_cfg.get("min_learning_rate", 1e-6)),
        early_stopping_patience=int(train_cfg.get("early_stopping_patience", 8)),
        reduce_lr_patience=int(train_cfg.get("reduce_lr_patience", 4)),
        reduce_lr_factor=float(train_cfg.get("reduce_lr_factor", 0.5)),
        seed=int(data_cfg.get("seed", 42)),
        resume_from=args.resume,
        max_steps_per_epoch=args.max_steps_per_epoch,
        base_dir=Path.cwd(),
    )

    print("=" * 68)
    print(f"[train_embedding] Run '{run_name}' selesai ({result['epochs_ran']} epoch dijalankan).")
    print(f"  - Model latihan  : {result['training_model_path']}")
    print(f"  - Model backbone : {result['backbone_model_path']}")
    print(f"  - Riwayat CSV    : {result['history_csv_path']}")
    print(f"  - Kurva PNG      : {result['curves_png_path']}")
    print("=" * 68)


if __name__ == "__main__":
    main()
