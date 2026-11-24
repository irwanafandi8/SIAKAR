"""
embedding_cnn.py — Arsitektur CNN Embedding dari nol untuk SIAKAR.

Sesuai ML_SPEC.md §3.1, §4, §5 & DECISIONS.md D-20..D-22:
- Tanpa bobot pretrained apa pun (seluruh bobot diinisialisasi dari nol).
- Input kontrak: float32 [B, input_size, input_size, 3] RGB dalam [-1, 1] sesuai preprocess.json.
- Hanya memakai lapisan standar yang aman dikonversi ke TFLite (Conv2D, BatchNormalization,
  ReLU, GlobalAveragePooling2D, Dense, dan tf.math.l2_normalize).
- Keluaran backbone: float32 [B, embedding_dim] ter-normalisasi L2 (norma = 1.0).
- Kepala pelatihan:
  - 'softmax': Dense(num_classes, activation='softmax')
  - 'cosface': CosineLogitsLayer + CosFaceSparseCategoricalCrossentropy (ditulis sendiri untuk ablasi §6.3)
  Kepala pelatihan dilepas saat ekspor TFLite lewat extract_embedding_backbone().
"""

from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional, Sequence, Tuple

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

HeadType = Literal["softmax", "cosface"]

DEFAULT_STAGES: Tuple[Dict[str, int], ...] = (
    {"filters": 32, "num_blocks": 1, "stride": 2},
    {"filters": 64, "num_blocks": 2, "stride": 2},
    {"filters": 128, "num_blocks": 2, "stride": 2},
    {"filters": 256, "num_blocks": 2, "stride": 2},
)


@keras.utils.register_keras_serializable(package="siakar_ml")
class L2NormalizeLayer(layers.Layer):
    """Lapisan L2-normalization menggunakan tf.math.l2_normalize (kompatibel penuh TFLite builtin)."""

    def __init__(self, axis: int = -1, epsilon: float = 1e-12, **kwargs: Any) -> None:
        super().__init__(**kwargs)
        self.axis = axis
        self.epsilon = epsilon

    def call(self, inputs: tf.Tensor) -> tf.Tensor:
        return tf.math.l2_normalize(inputs, axis=self.axis, epsilon=self.epsilon)

    def get_config(self) -> Dict[str, Any]:
        config = super().get_config()
        config.update({"axis": self.axis, "epsilon": self.epsilon})
        return config


@keras.utils.register_keras_serializable(package="siakar_ml")
class CosineLogitsLayer(layers.Layer):
    """Kepala klasifikasi berbasis cos(theta) antar embedding L2-normalized dan bobot kelas L2-normalized."""

    def __init__(self, num_classes: int, seed: int = 42, **kwargs: Any) -> None:
        super().__init__(**kwargs)
        self.num_classes = int(num_classes)
        self.seed = int(seed)
        self.kernel: Optional[tf.Variable] = None

    def build(self, input_shape: tf.TensorShape) -> None:
        in_dim = int(input_shape[-1])
        self.kernel = self.add_weight(
            name="class_prototypes",
            shape=(in_dim, self.num_classes),
            initializer=keras.initializers.GlorotUniform(seed=self.seed),
            trainable=True,
        )
        super().build(input_shape)

    def call(self, inputs: tf.Tensor) -> tf.Tensor:
        norm_w = tf.math.l2_normalize(self.kernel, axis=0, epsilon=1e-12)
        cos_theta = tf.matmul(inputs, norm_w)
        return tf.clip_by_value(cos_theta, -1.0, 1.0)

    def get_config(self) -> Dict[str, Any]:
        config = super().get_config()
        config.update({"num_classes": self.num_classes, "seed": self.seed})
        return config


@keras.utils.register_keras_serializable(package="siakar_ml")
class CosFaceLoss(keras.losses.Loss):
    """Implementasi sendiri Large Margin Cosine Loss (CosFace) untuk ablasi ML_SPEC.md §3.1 & §6.3."""

    def __init__(
        self,
        num_classes: int,
        scale: float = 30.0,
        margin: float = 0.20,
        name: str = "cosface_loss",
        **kwargs: Any,
    ) -> None:
        super().__init__(name=name, **kwargs)
        self.num_classes = int(num_classes)
        self.scale = float(scale)
        self.margin = float(margin)

    def call(self, y_true: tf.Tensor, y_pred: tf.Tensor) -> tf.Tensor:
        labels = tf.cast(tf.reshape(y_true, [-1]), tf.int32)
        one_hot = tf.one_hot(labels, depth=self.num_classes, dtype=y_pred.dtype)
        adjusted_cos = y_pred - one_hot * self.margin
        scaled_logits = adjusted_cos * self.scale
        return tf.nn.sparse_softmax_cross_entropy_with_logits(labels=labels, logits=scaled_logits)

    def get_config(self) -> Dict[str, Any]:
        config = super().get_config()
        config.update(
            {
                "num_classes": self.num_classes,
                "scale": self.scale,
                "margin": self.margin,
            }
        )
        return config


def _conv_bn_relu(
    x: tf.Tensor,
    filters: int,
    stride: int,
    seed: int,
    name_prefix: str,
) -> tf.Tensor:
    initializer = keras.initializers.HeNormal(seed=seed)
    x = layers.Conv2D(
        filters=filters,
        kernel_size=3,
        strides=stride,
        padding="same",
        use_bias=False,
        kernel_initializer=initializer,
        name=f"{name_prefix}_conv",
    )(x)
    x = layers.BatchNormalization(name=f"{name_prefix}_bn")(x)
    x = layers.ReLU(name=f"{name_prefix}_relu")(x)
    return x


def build_embedding_backbone(
    input_size: int = 112,
    embedding_dim: int = 128,
    stages: Optional[Sequence[Dict[str, Any]]] = None,
    seed: int = 42,
) -> keras.Model:
    """Bangun model backbone CNN dari nol yang menghasilkan vektor embedding L2-normalized."""
    if input_size < 32:
        raise ValueError(f"input_size terlalu kecil ({input_size}); minimal 32 piksel.")
    if embedding_dim < 16:
        raise ValueError(f"embedding_dim terlalu kecil ({embedding_dim}).")

    stage_specs: List[Dict[str, Any]] = list(stages) if stages is not None else list(DEFAULT_STAGES)

    inputs = keras.Input(shape=(input_size, input_size, 3), dtype=tf.float32, name="face_input")
    x = inputs

    for stage_idx, spec in enumerate(stage_specs):
        filters = int(spec["filters"])
        stride = int(spec.get("stride", 2))
        num_blocks = int(spec.get("num_blocks", 1 if stage_idx == 0 else 2))

        for block_idx in range(num_blocks):
            block_stride = stride if block_idx == 0 else 1
            prefix = "stem" if (stage_idx == 0 and num_blocks == 1) else f"stage{stage_idx}_block{block_idx}"
            x = _conv_bn_relu(
                x,
                filters=filters,
                stride=block_stride,
                seed=seed + stage_idx * 10 + block_idx,
                name_prefix=prefix,
            )

    x = layers.GlobalAveragePooling2D(name="global_avg_pool")(x)
    x = layers.Dense(
        embedding_dim,
        use_bias=False,
        kernel_initializer=keras.initializers.GlorotUniform(seed=seed + 99),
        name="embedding_dense",
    )(x)
    embeddings = L2NormalizeLayer(axis=-1, name="l2_embedding")(x)

    return keras.Model(inputs=inputs, outputs=embeddings, name="siakar_embedding_backbone")


def build_training_model(
    num_classes: int,
    input_size: int = 112,
    embedding_dim: int = 128,
    stages: Optional[Sequence[Dict[str, Any]]] = None,
    head_type: HeadType = "softmax",
    seed: int = 42,
) -> keras.Model:
    """Bangun model pelatihan dari nol (backbone embedding + kepala klasifikasi)."""
    if num_classes < 2:
        raise ValueError(f"num_classes harus >= 2 (diberikan: {num_classes}).")

    backbone = build_embedding_backbone(
        input_size=input_size,
        embedding_dim=embedding_dim,
        stages=stages,
        seed=seed,
    )

    if head_type == "softmax":
        outputs = layers.Dense(
            num_classes,
            activation="softmax",
            kernel_initializer=keras.initializers.GlorotUniform(seed=seed + 199),
            name="classification_head",
        )(backbone.output)
    elif head_type == "cosface":
        outputs = CosineLogitsLayer(
            num_classes=num_classes,
            seed=seed + 199,
            name="classification_head",
        )(backbone.output)
    else:
        raise ValueError(f"head_type tidak dikenal: {head_type}. Gunakan 'softmax' atau 'cosface'.")

    return keras.Model(
        inputs=backbone.input,
        outputs=outputs,
        name="siakar_training_model",
    )


def build_training_loss(
    head_type: HeadType,
    num_classes: int,
    cosface_scale: float = 30.0,
    cosface_margin: float = 0.20,
) -> keras.losses.Loss:
    """Buat fungsi loss sesuai jenis kepala klasifikasi ('softmax' atau 'cosface')."""
    if head_type == "softmax":
        return keras.losses.SparseCategoricalCrossentropy()
    if head_type == "cosface":
        return CosFaceLoss(num_classes=num_classes, scale=cosface_scale, margin=cosface_margin)
    raise ValueError(f"head_type tidak dikenal: {head_type}")


def extract_embedding_backbone(model_or_backbone: keras.Model) -> keras.Model:
    """Ambil sub-model backbone ``[None, H, W, 3] -> [None, embedding_dim]`` tanpa kepala klasifikasi."""
    if model_or_backbone.name == "siakar_embedding_backbone":
        return model_or_backbone
    layer_names = {layer.name for layer in model_or_backbone.layers}
    if "l2_embedding" in layer_names:
        embedding_output = model_or_backbone.get_layer("l2_embedding").output
        return keras.Model(
            inputs=model_or_backbone.input,
            outputs=embedding_output,
            name="siakar_embedding_backbone",
        )
    return model_or_backbone


CUSTOM_OBJECTS: Dict[str, Any] = {
    "L2NormalizeLayer": L2NormalizeLayer,
    "CosineLogitsLayer": CosineLogitsLayer,
    "CosFaceLoss": CosFaceLoss,
}
