import 'dart:typed_data';
import '../entities/face_enrollment_entities.dart';

/// Kontrak repositori komunikasi API registrasi wajah (GET /face/status & POST /face/enroll).
abstract class FaceEnrollmentRepository {
  Future<FaceStatusEntity> getFaceStatus();

  Future<FaceEnrollResult> enrollFace({
    required List<List<double>> embeddings,
    required Uint8List referencePhotoBytes,
    String referenceFileName = 'face_reference.jpg',
    required bool replace,
  });
}

/// Kontrak ekstraksi sampel wajah di perangkat (validasi oval + TFLite 128-d embedding).
abstract class FaceSampleExtractor {
  Future<CapturedFaceSample> extractSample({
    required Uint8List photoBytes,
    required String poseLabel,
    String? filePath,
  });
}
