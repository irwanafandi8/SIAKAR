import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../../../core/ml/liveness_service.dart';

/// Entitas status registrasi wajah karyawan dari GET /api/v1/face/status.
class FaceStatusEntity extends Equatable {
  final bool enrolled;
  final String? enrolledAt;

  const FaceStatusEntity({
    required this.enrolled,
    this.enrolledAt,
  });

  @override
  List<Object?> get props => [enrolled, enrolledAt];
}

/// Satu sampel tangkapan wajah yang telah divalidasi di area oval & diekstrak embedding-nya.
class CapturedFaceSample extends Equatable {
  final String poseLabel;
  final List<double> embedding;
  final Uint8List photoBytes;
  final String? filePath;
  final FaceDetectionBox? detectionBox;

  const CapturedFaceSample({
    required this.poseLabel,
    required this.embedding,
    required this.photoBytes,
    this.filePath,
    this.detectionBox,
  });

  @override
  List<Object?> get props => [
        poseLabel,
        embedding,
        photoBytes.length,
        filePath,
        detectionBox,
      ];
}

/// Hasil pendaftaran wajah ke POST /api/v1/face/enroll.
class FaceEnrollResult extends Equatable {
  final bool enrolled;

  const FaceEnrollResult({required this.enrolled});

  @override
  List<Object?> get props => [enrolled];
}
