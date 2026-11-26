import '../../domain/entities/face_enrollment_entities.dart';

class FaceStatusModel extends FaceStatusEntity {
  const FaceStatusModel({
    required super.enrolled,
    super.enrolledAt,
  });

  factory FaceStatusModel.fromJson(Map<String, dynamic> json) {
    return FaceStatusModel(
      enrolled: json['enrolled'] == true,
      enrolledAt: json['enrolled_at']?.toString(),
    );
  }
}

class FaceEnrollResultModel extends FaceEnrollResult {
  const FaceEnrollResultModel({required super.enrolled});

  factory FaceEnrollResultModel.fromJson(Map<String, dynamic> json) {
    return FaceEnrollResultModel(
      enrolled: json['enrolled'] == true,
    );
  }
}
