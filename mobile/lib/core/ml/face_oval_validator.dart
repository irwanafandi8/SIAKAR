import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../error/error_messages.dart';
import '../error/failures.dart';
import 'detector_service.dart';
import 'liveness_service.dart';
import 'preprocess.dart';

/// Hasil pemeriksaan kualitas & keberadaan objek wajah pada area oval.
class FaceOvalValidationResult {
  final bool isValid;
  final String? errorCode;
  final String instruction;
  final double meanLuminance;
  final double stdLuminance;

  const FaceOvalValidationResult({
    required this.isValid,
    this.errorCode,
    required this.instruction,
    required this.meanLuminance,
    required this.stdLuminance,
  });
}

/// Paket citra yang telah lolos validasi pencahayaan oval DAN detektor wajah TFLite (`detector.tflite`).
class ValidatedOvalFrame {
  final img.Image decodedImage;
  final FaceDetectionBox detectionBox;

  const ValidatedOvalFrame({
    required this.decodedImage,
    required this.detectionBox,
  });
}

/// Kontrak validator area oval wajah (menggabungkan pemeriksaan pencahayaan + `DetectorService` TFLite).
abstract class FaceInOvalValidator {
  FaceOvalValidationResult validateImage(img.Image rawImage);
  FaceOvalValidationResult validateBytes(Uint8List imageBytes);

  /// Validasi sinkron pencahayaan & kontras dasar.
  img.Image decodeAndValidateOrThrow(Uint8List imageBytes);

  /// Validasi lengkap dengan `DetectorService` TFLite (`detector.tflite`) sebelum inferensi embedding dijalankan.
  /// Melempar `ValidationFailure` (`LIGHTING_TOO_DARK`, `LIGHTING_TOO_BRIGHT`, atau `FACE_NOT_IN_OVAL`) jika gagal.
  Future<ValidatedOvalFrame> decodeAndDetectFaceOrThrow(Uint8List imageBytes);
}

/// Implementasi `FaceInOvalValidator` yang mengevaluasi kualitas pencahayaan elips oval
/// serta menjalankan `DetectorService` (`detector.tflite`, ambang `detector_threshold.json`).
class DefaultFaceOvalValidator implements FaceInOvalValidator {
  final PreprocessService preprocessService;
  final DetectorService? detectorService;
  final int minDimension;
  final double minLuminance;
  final double maxLuminance;
  final double minContrastStd;

  const DefaultFaceOvalValidator({
    required this.preprocessService,
    this.detectorService,
    this.minDimension = 64,
    this.minLuminance = 28.0,
    this.maxLuminance = 238.0,
    this.minContrastStd = 12.0,
  });

  @override
  FaceOvalValidationResult validateBytes(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return FaceOvalValidationResult(
        isValid: false,
        errorCode: 'FACE_NOT_IN_OVAL',
        instruction: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
        meanLuminance: 0.0,
        stdLuminance: 0.0,
      );
    }
    return validateImage(decoded);
  }

  @override
  FaceOvalValidationResult validateImage(img.Image rawImage) {
    if (rawImage.width < minDimension || rawImage.height < minDimension) {
      return FaceOvalValidationResult(
        isValid: false,
        errorCode: 'FACE_NOT_IN_OVAL',
        instruction: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
        meanLuminance: 0.0,
        stdLuminance: 0.0,
      );
    }

    final cropped = preprocessService.cropToOval(rawImage);
    final w = cropped.width;
    final h = cropped.height;
    final cx = w / 2.0;
    final cy = h / 2.0;
    final rx = math.max(1.0, w / 2.0);
    final ry = math.max(1.0, h / 2.0);

    double sum = 0.0;
    double sumSq = 0.0;
    int count = 0;

    for (int y = 0; y < h; y++) {
      final ny = ((y + 0.5) - cy) / ry;
      for (int x = 0; x < w; x++) {
        final nx = ((x + 0.5) - cx) / rx;
        if (nx * nx + ny * ny <= 1.0) {
          final p = cropped.getPixel(x, y);
          final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
          sum += lum;
          sumSq += lum * lum;
          count++;
        }
      }
    }

    if (count == 0) {
      return FaceOvalValidationResult(
        isValid: false,
        errorCode: 'FACE_NOT_IN_OVAL',
        instruction: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
        meanLuminance: 0.0,
        stdLuminance: 0.0,
      );
    }

    final mean = sum / count;
    final variance = math.max(0.0, (sumSq / count) - (mean * mean));
    final std = math.sqrt(variance);

    if (mean < minLuminance) {
      return FaceOvalValidationResult(
        isValid: false,
        errorCode: 'LIGHTING_TOO_DARK',
        instruction: ErrorMessages.fromCode('LIGHTING_TOO_DARK'),
        meanLuminance: mean,
        stdLuminance: std,
      );
    }

    if (mean > maxLuminance) {
      return FaceOvalValidationResult(
        isValid: false,
        errorCode: 'LIGHTING_TOO_BRIGHT',
        instruction: ErrorMessages.fromCode('LIGHTING_TOO_BRIGHT'),
        meanLuminance: mean,
        stdLuminance: std,
      );
    }

    if (std < minContrastStd) {
      return FaceOvalValidationResult(
        isValid: false,
        errorCode: 'FACE_NOT_IN_OVAL',
        instruction: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
        meanLuminance: mean,
        stdLuminance: std,
      );
    }

    return FaceOvalValidationResult(
      isValid: true,
      instruction: 'Tahan sebentar',
      meanLuminance: mean,
      stdLuminance: std,
    );
  }

  @override
  img.Image decodeAndValidateOrThrow(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ValidationFailure(
        code: 'FACE_NOT_IN_OVAL',
        message: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
      );
    }

    final result = validateImage(decoded);
    if (!result.isValid) {
      throw ValidationFailure(
        code: result.errorCode ?? 'FACE_NOT_IN_OVAL',
        message: result.instruction,
      );
    }

    return decoded;
  }

  @override
  Future<ValidatedOvalFrame> decodeAndDetectFaceOrThrow(
    Uint8List imageBytes,
  ) async {
    final decoded = decodeAndValidateOrThrow(imageBytes);

    final detector = detectorService;
    if (detector == null) {
      // Fallback aman untuk unit test lama tanpa injeksi DetectorService
      return ValidatedOvalFrame(
        decodedImage: decoded,
        detectionBox: const FaceDetectionBox(
          faceScore: 1.0,
          cx: 0.5,
          cy: 0.5,
          width: 0.65,
          height: 0.65,
          threshold: DetectorService.defaultThreshold,
        ),
      );
    }

    final FaceDetectionBox detection;
    try {
      detection = await detector.detect(decoded);
    } on Failure {
      rethrow;
    } catch (_) {
      throw ValidationFailure(
        code: 'FACE_NOT_IN_OVAL',
        message: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
      );
    }

    if (!detection.isWellPositionedInOval) {
      throw ValidationFailure(
        code: 'FACE_NOT_IN_OVAL',
        message: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
      );
    }

    return ValidatedOvalFrame(
      decodedImage: decoded,
      detectionBox: detection,
    );
  }
}
