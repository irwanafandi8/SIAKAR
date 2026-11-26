import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../../../core/error/error_messages.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/ml/embedding_service.dart';
import '../../../../core/ml/face_oval_validator.dart';
import '../../../../core/ml/liveness_service.dart';
import '../../domain/entities/face_enrollment_entities.dart';
import '../../domain/repositories/face_enrollment_repository.dart';

/// Implementasi ekstraktor sampel wajah di perangkat (M3 + M5 + M8):
/// 1. Dekode, validasi pencahayaan, & jalankan `DetectorService` TFLite (`detector.tflite`)
///    untuk memastikan ada wajah valid di dalam bingkai oval SEBELUM inferensi embedding dijalankan.
/// 2. Ekstrak embedding 128-d L2-normalized (`EmbeddingService` / `siakar_embedding.tflite`).
/// 3. Pastikan ukuran berkas foto referensi <= 1.8 MB (batas API 2 MB di API.md §3.2).
class MlFaceSampleExtractor implements FaceSampleExtractor {
  static const int _maxPhotoBytes = 1800 * 1024;

  final FaceInOvalValidator ovalValidator;
  final EmbeddingService embeddingService;

  Uint8List? _lastValidatedBytes;
  ValidatedOvalFrame? _lastValidatedFrame;

  MlFaceSampleExtractor({
    required this.ovalValidator,
    required this.embeddingService,
  });

  Future<ValidatedOvalFrame> _validateCached(Uint8List photoBytes) async {
    if (identical(photoBytes, _lastValidatedBytes) &&
        _lastValidatedFrame != null) {
      return _lastValidatedFrame!;
    }
    final validated = await ovalValidator.decodeAndDetectFaceOrThrow(photoBytes);
    _lastValidatedBytes = photoBytes;
    _lastValidatedFrame = validated;
    return validated;
  }

  /// Validasi keberadaan & kotak wajah `[face_score, cx, cy, w, h]` di area oval tanpa menjalankan embedding.
  @override
  Future<FaceDetectionBox> detectFaceInOval(Uint8List photoBytes) async {
    final validated = await _validateCached(photoBytes);
    return validated.detectionBox;
  }

  @override
  Future<CapturedFaceSample> extractSample({
    required Uint8List photoBytes,
    required String poseLabel,
    String? filePath,
  }) async {
    final validated = await _validateCached(photoBytes);
    final decoded = validated.decodedImage;

    final List<double> embedding;
    try {
      embedding = await embeddingService.extractEmbedding(decoded);
    } on Failure {
      rethrow;
    } catch (_) {
      throw ServerFailure(
        code: 'INVALID_EMBEDDING',
        message: ErrorMessages.fromCode('INVALID_EMBEDDING'),
      );
    }

    final normalizedPhotoBytes = _ensureUnderSizeLimit(photoBytes, decoded);

    return CapturedFaceSample(
      poseLabel: poseLabel,
      embedding: embedding,
      photoBytes: normalizedPhotoBytes,
      filePath: filePath,
      detectionBox: validated.detectionBox,
    );
  }

  static Uint8List _ensureUnderSizeLimit(
    Uint8List originalBytes,
    img.Image decoded,
  ) {
    if (originalBytes.lengthInBytes <= _maxPhotoBytes) {
      return originalBytes;
    }

    var working = decoded;
    if (working.width > 1080) {
      working = img.copyResize(working, width: 1080);
    }
    final compressed = img.encodeJpg(working, quality: 82);
    return Uint8List.fromList(compressed);
  }
}
