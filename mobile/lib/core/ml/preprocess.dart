import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Konfigurasi kontrak praproses sesuai ML_SPEC §4 dan preprocess.json.
class PreprocessConfig {
  final int inputSize;
  final double ovalCenterXRatio;
  final double ovalCenterYRatio;
  final double ovalWidthRatio;
  final double ovalHeightRatio;
  final String cropBoxRounding;
  final String channelOrder;
  final String interpolation;
  final String coordinateTransformationMode;
  final String borderMode;
  final bool antiAliasing;
  final String uint8Rounding;
  final double normalizationMean;
  final double normalizationStd;
  final String outputDtype;

  const PreprocessConfig({
    this.inputSize = 112,
    this.ovalCenterXRatio = 0.5,
    this.ovalCenterYRatio = 0.5,
    this.ovalWidthRatio = 0.70,
    this.ovalHeightRatio = 0.85,
    this.cropBoxRounding = 'floor',
    this.channelOrder = 'RGB',
    this.interpolation = 'bilinear',
    this.coordinateTransformationMode = 'half_pixel',
    this.borderMode = 'clamp_to_edge',
    this.antiAliasing = false,
    this.uint8Rounding = 'floor_half_up',
    this.normalizationMean = 127.5,
    this.normalizationStd = 127.5,
    this.outputDtype = 'float32',
  });

  factory PreprocessConfig.fromMap(Map<String, dynamic> map) {
    return PreprocessConfig(
      inputSize: (map['input_size'] as num?)?.toInt() ?? 112,
      ovalCenterXRatio:
          (map['oval_center_x_ratio'] as num?)?.toDouble() ?? 0.5,
      ovalCenterYRatio:
          (map['oval_center_y_ratio'] as num?)?.toDouble() ?? 0.5,
      ovalWidthRatio: (map['oval_width_ratio'] as num?)?.toDouble() ?? 0.70,
      ovalHeightRatio: (map['oval_height_ratio'] as num?)?.toDouble() ?? 0.85,
      cropBoxRounding: (map['crop_box_rounding'] as String?) ?? 'floor',
      channelOrder: (map['channel_order'] as String?) ?? 'RGB',
      interpolation: (map['interpolation'] as String?) ?? 'bilinear',
      coordinateTransformationMode:
          (map['coordinate_transformation_mode'] as String?) ?? 'half_pixel',
      borderMode: (map['border_mode'] as String?) ?? 'clamp_to_edge',
      antiAliasing: (map['anti_aliasing'] as bool?) ?? false,
      uint8Rounding: (map['uint8_rounding'] as String?) ?? 'floor_half_up',
      normalizationMean:
          (map['normalization_mean'] as num?)?.toDouble() ?? 127.5,
      normalizationStd:
          (map['normalization_std'] as num?)?.toDouble() ?? 127.5,
      outputDtype: (map['output_dtype'] as String?) ?? 'float32',
    );
  }

  Map<String, dynamic> toMap() => {
        'input_size': inputSize,
        'oval_center_x_ratio': ovalCenterXRatio,
        'oval_center_y_ratio': ovalCenterYRatio,
        'oval_width_ratio': ovalWidthRatio,
        'oval_height_ratio': ovalHeightRatio,
        'crop_box_rounding': cropBoxRounding,
        'channel_order': channelOrder,
        'interpolation': interpolation,
        'coordinate_transformation_mode': coordinateTransformationMode,
        'border_mode': borderMode,
        'anti_aliasing': antiAliasing,
        'uint8_rounding': uint8Rounding,
        'normalization_mean': normalizationMean,
        'normalization_std': normalizationStd,
        'output_dtype': outputDtype,
      };
}

/// Kotak hasil perhitungan crop oval (piksel).
class OvalCropRect {
  final int x1;
  final int y1;
  final int x2;
  final int y2;

  const OvalCropRect({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  int get width => math.max(1, x2 - x1);
  int get height => math.max(1, y2 - y1);
}

/// Implementasi praproses wajah di Dart yang 100% identik secara numerik
/// dengan `ml/src/siakar_ml/preprocess.py`, `ML_SPEC.md` §4, dan `preprocess.json` (D-32).
class PreprocessService {
  static const String defaultAssetPath = 'assets/models/preprocess.json';

  final Map<String, dynamic> config;
  final PreprocessConfig spec;

  PreprocessService(Map<String, dynamic> config)
      : config = Map<String, dynamic>.unmodifiable(config),
        spec = PreprocessConfig.fromMap(config);

  factory PreprocessService.fromSpec(PreprocessConfig spec) {
    return PreprocessService(spec.toMap());
  }

  factory PreprocessService.defaultConfig() {
    return PreprocessService.fromSpec(const PreprocessConfig());
  }

  /// Muat konfigurasi dari `assets/models/preprocess.json`.
  static Future<PreprocessService> fromAsset([
    String path = defaultAssetPath,
  ]) async {
    final jsonStr = await rootBundle.loadString(path);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return PreprocessService(map);
  }

  /// Hitung koordinat kotak crop oval dengan pembulatan `floor` (ML_SPEC §4 Langkah 1).
  OvalCropRect computeOvalCropRect(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Dimensi citra harus positif ($width x $height).');
    }

    final cx = spec.ovalCenterXRatio * width;
    final cy = spec.ovalCenterYRatio * height;
    final halfW = spec.ovalWidthRatio * width / 2.0;
    final halfH = spec.ovalHeightRatio * height / 2.0;

    final x1 = math.max(0, (cx - halfW).floor());
    final y1 = math.max(0, (cy - halfH).floor());
    final x2 = math.min(width, (cx + halfW).floor());
    final y2 = math.min(height, (cy + halfH).floor());

    return OvalCropRect(x1: x1, y1: y1, x2: x2, y2: y2);
  }

  /// Langkah 1: Crop persegi dari area oval panduan.
  img.Image cropToOval(img.Image image) {
    final rect = computeOvalCropRect(image.width, image.height);
    final safeX1 = math.min(rect.x1, image.width - 1);
    final safeY1 = math.min(rect.y1, image.height - 1);
    final safeW = math.min(rect.width, image.width - safeX1);
    final safeH = math.min(rect.height, image.height - safeY1);

    return img.copyCrop(
      image,
      x: safeX1,
      y: safeY1,
      width: math.max(1, safeW),
      height: math.max(1, safeH),
    );
  }

  /// Langkah 2 & 3: Resize bilinear 2D murni (`half_pixel`, `clamp_to_edge`,
  /// `anti_aliasing = false`) + pembulatan `floor_half_up` ke uint8 `[0, 255]`.
  img.Image resize(img.Image image) {
    final targetSize = spec.inputSize;
    final inH = image.height;
    final inW = image.width;

    if (inH <= 0 || inW <= 0) {
      throw ArgumentError('Dimensi citra tidak valid ($inW x $inH).');
    }

    final out = img.Image(
      width: targetSize,
      height: targetSize,
      numChannels: 3,
    );

    final scaleY = inH / targetSize;
    final scaleX = inW / targetSize;
    final maxY = (inH - 1).toDouble();
    final maxX = (inW - 1).toDouble();

    // Prekomputasi indeks dan bobot sumbu X untuk efisiensi
    final x0List = Int32List(targetSize);
    final x1List = Int32List(targetSize);
    final wxList = Float64List(targetSize);

    for (int outX = 0; outX < targetSize; outX++) {
      final srcX = (outX + 0.5) * scaleX - 0.5;
      final sx = srcX < 0.0 ? 0.0 : (srcX > maxX ? maxX : srcX);
      final x0 = sx.floor();
      final x1 = x0 + 1 < inW ? x0 + 1 : inW - 1;
      x0List[outX] = x0;
      x1List[outX] = x1;
      wxList[outX] = sx - x0;
    }

    for (int outY = 0; outY < targetSize; outY++) {
      final srcY = (outY + 0.5) * scaleY - 0.5;
      final sy = srcY < 0.0 ? 0.0 : (srcY > maxY ? maxY : srcY);
      final y0 = sy.floor();
      final y1 = y0 + 1 < inH ? y0 + 1 : inH - 1;
      final wy = sy - y0;
      final invWy = 1.0 - wy;

      for (int outX = 0; outX < targetSize; outX++) {
        final x0 = x0List[outX];
        final x1 = x1List[outX];
        final wx = wxList[outX];
        final invWx = 1.0 - wx;

        final w00 = invWy * invWx;
        final w01 = invWy * wx;
        final w10 = wy * invWx;
        final w11 = wy * wx;

        final p00 = image.getPixel(x0, y0);
        final p01 = image.getPixel(x1, y0);
        final p10 = image.getPixel(x0, y1);
        final p11 = image.getPixel(x1, y1);

        final rVal = w00 * p00.r + w01 * p01.r + w10 * p10.r + w11 * p11.r;
        final gVal = w00 * p00.g + w01 * p01.g + w10 * p10.g + w11 * p11.g;
        final bVal = w00 * p00.b + w01 * p01.b + w10 * p10.b + w11 * p11.b;

        out.setPixelRgb(
          outX,
          outY,
          _roundFloorHalfUpToUint8(rVal),
          _roundFloorHalfUpToUint8(gVal),
          _roundFloorHalfUpToUint8(bVal),
        );
      }
    }

    return out;
  }

  /// Pembulatan eksplisit `floor_half_up`: `uint8(floor(clamp(v, 0.0, 255.0) + 0.5))`.
  static int _roundFloorHalfUpToUint8(double value) {
    final clamped = value < 0.0 ? 0.0 : (value > 255.0 ? 255.0 : value);
    return (clamped + 0.5).floor();
  }

  /// Langkah 4 & 5: Normalisasi `(float32(u8) - mean) / std` → `Float32List`
  /// berbentuk datar `[1, S, S, 3]` (NHWC, RGB, rentang `[-1.0, 1.0]`).
  Float32List normalizeToNHWC(img.Image resizedImage) {
    final targetSize = spec.inputSize;
    if (resizedImage.width != targetSize || resizedImage.height != targetSize) {
      throw ArgumentError(
        'Ukuran citra harus ${targetSize}x$targetSize, '
        'diterima ${resizedImage.width}x${resizedImage.height}.',
      );
    }

    final mean = spec.normalizationMean;
    final std = spec.normalizationStd;
    final floatList = Float32List(1 * targetSize * targetSize * 3);

    int index = 0;
    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        floatList[index++] = (pixel.r.toDouble() - mean) / std;
        floatList[index++] = (pixel.g.toDouble() - mean) / std;
        floatList[index++] = (pixel.b.toDouble() - mean) / std;
      }
    }

    return floatList;
  }

  /// Pipeline lengkap sesuai ML_SPEC §4: crop oval → resize bilinear murni → normalisasi NHWC.
  Float32List preprocess(img.Image rawImage) {
    final cropped = cropToOval(rawImage);
    final resized = resize(cropped);
    return normalizeToNHWC(resized);
  }

  /// Pipeline lengkap dari bytes PNG/JPEG mentah.
  Float32List preprocessBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Gagal mendekode bytes citra.');
    }
    return preprocess(decoded);
  }
}
