import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../../../core/error/error_messages.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/ml/embedding_service.dart';
import '../../../../core/ml/face_oval_validator.dart';
import '../../domain/entities/face_enrollment_entities.dart';
import '../../domain/repositories/face_enrollment_repository.dart';

/// Implementasi ekstraktor sampel wajah di perangkat (M3 + M5):
/// 1. Dekode & validasi kualitas wajah di dalam oval panduan (`FaceInOvalValidator`).
/// 2. Ekstrak embedding 128-d L2-normalized (`EmbeddingService` / TFLite).
/// 3. Pastikan ukuran berkas foto referensi <= 1.8 MB (batas API 2 MB di API.md §3.2).
class MlFaceSampleExtractor implements FaceSampleExtractor {
  static const int _maxPhotoBytes = 1800 * 1024;

  final FaceInOvalValidator ovalValidator;
  final EmbeddingService embeddingService;

  const MlFaceSampleExtractor({
    required this.ovalValidator,
    required this.embeddingService,
  });

  @override
  Future<CapturedFaceSample> extractSample({
    required Uint8List photoBytes,
    required String poseLabel,
    String? filePath,
  }) async {
    final decoded = ovalValidator.decodeAndValidateOrThrow(photoBytes);

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
