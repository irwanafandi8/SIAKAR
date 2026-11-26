import 'dart:typed_data';
import '../../../../core/error/failures.dart';
import '../entities/face_enrollment_entities.dart';
import '../repositories/face_enrollment_repository.dart';

class GetFaceEnrollmentStatusUseCase {
  final FaceEnrollmentRepository repository;

  const GetFaceEnrollmentStatusUseCase(this.repository);

  Future<FaceStatusEntity> call() {
    return repository.getFaceStatus();
  }
}

class ExtractFaceSampleUseCase {
  final FaceSampleExtractor extractor;

  const ExtractFaceSampleUseCase(this.extractor);

  Future<CapturedFaceSample> call({
    required Uint8List photoBytes,
    required String poseLabel,
    String? filePath,
  }) async {
    if (photoBytes.isEmpty) {
      throw const ValidationFailure(
        code: 'FACE_NOT_IN_OVAL',
        message: 'Berkas foto kosong atau gagal diambil dari kamera.',
      );
    }

    final sample = await extractor.extractSample(
      photoBytes: photoBytes,
      poseLabel: poseLabel,
      filePath: filePath,
    );

    if (sample.embedding.length != 128 ||
        sample.embedding.any((v) => !v.isFinite)) {
      throw const ValidationFailure(
        code: 'INVALID_EMBEDDING',
        message: 'Ekstraksi wajah gagal menghasilkan vektor 128 dimensi yang valid.',
      );
    }

    return sample;
  }
}

class SubmitFaceEnrollmentUseCase {
  static const int minSamples = 3;
  static const int maxSamples = 5;

  final FaceEnrollmentRepository repository;

  const SubmitFaceEnrollmentUseCase(this.repository);

  Future<FaceEnrollResult> call({
    required List<CapturedFaceSample> samples,
    required bool replace,
  }) async {
    if (samples.length < minSamples || samples.length > maxSamples) {
      throw const ValidationFailure(
        code: 'VALIDATION_ERROR',
        message: 'Ambil minimal 3 hingga maksimal 5 foto wajah untuk registrasi.',
      );
    }

    final embeddings = samples.map((s) => s.embedding).toList(growable: false);
    final referencePhotoBytes = samples.first.photoBytes;

    return repository.enrollFace(
      embeddings: embeddings,
      referencePhotoBytes: referencePhotoBytes,
      replace: replace,
    );
  }
}
