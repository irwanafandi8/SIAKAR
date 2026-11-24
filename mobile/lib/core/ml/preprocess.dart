import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Implementasi praproses wajah di Dart yang persis mengikuti ML_SPEC §4 dan preprocess.json.
class PreprocessService {
  final Map<String, dynamic> config;

  PreprocessService(this.config);

  /// Muat konfigurasi dari assets/models/preprocess.json
  static Future<PreprocessService> fromAsset([String path = 'assets/models/preprocess.json']) async {
    final jsonStr = await rootBundle.loadString(path);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return PreprocessService(map);
  }

  /// Crop persegi dari area oval panduan
  img.Image cropToOval(img.Image image) {
    final w = image.width;
    final h = image.height;

    final cx = (config['oval_center_x_ratio'] as num).toDouble() * w;
    final cy = (config['oval_center_y_ratio'] as num).toDouble() * h;
    final halfW = (config['oval_width_ratio'] as num).toDouble() * w / 2.0;
    final halfH = (config['oval_height_ratio'] as num).toDouble() * h / 2.0;

    final x1 = (cx - halfW).clamp(0, w - 1).toInt();
    final y1 = (cy - halfH).clamp(0, h - 1).toInt();
    final x2 = (cx + halfW).clamp(0, w).toInt();
    final y2 = (cy + halfH).clamp(0, h).toInt();

    final cropW = (x2 - x1).clamp(1, w);
    final cropH = (y2 - y1).clamp(1, h);

    return img.copyCrop(image, x: x1, y: y1, width: cropW, height: cropH);
  }

  /// Resize ke input_size (default 112x112) dengan bilinear interpolation
  img.Image resize(img.Image image) {
    final int targetSize = config['input_size'] ?? 112;
    return img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Normalisasi (x - 127.5) / 127.5 -> Float32List shape [1, 112, 112, 3] (NHWC)
  Float32List normalizeToNHWC(img.Image resizedImage) {
    final int targetSize = config['input_size'] ?? 112;
    final floatList = Float32List(1 * targetSize * targetSize * 3);

    int index = 0;
    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final pixel = resizedImage.getPixel(x, y);

        // Nilai RGB 0-255 dinormalisasi ke [-1, 1]
        final r = (pixel.r - 127.5) / 127.5;
        final g = (pixel.g - 127.5) / 127.5;
        final b = (pixel.b - 127.5) / 127.5;

        floatList[index++] = r.toDouble();
        floatList[index++] = g.toDouble();
        floatList[index++] = b.toDouble();
      }
    }

    return floatList;
  }

  /// Pipeline lengkap: crop -> resize -> normalize
  Float32List preprocess(img.Image rawImage) {
    final cropped = cropToOval(rawImage);
    final resized = resize(cropped);
    return normalizeToNHWC(resized);
  }
}
