import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/face_status_model.dart';

class FaceEnrollmentRemoteDataSource {
  final ApiClient apiClient;

  const FaceEnrollmentRemoteDataSource({required this.apiClient});

  Future<FaceStatusModel> getFaceStatus() async {
    final response = await apiClient.dio.get('/face/status');
    final data = response.data['data'] as Map<String, dynamic>;
    return FaceStatusModel.fromJson(data);
  }

  Future<FaceEnrollResultModel> enrollFace({
    required List<List<double>> embeddings,
    required Uint8List referencePhotoBytes,
    String referenceFileName = 'face_reference.jpg',
    required bool replace,
  }) async {
    final formData = FormData.fromMap({
      'embeddings': jsonEncode(embeddings),
      'replace': replace ? '1' : '0',
      'photo': MultipartFile.fromBytes(
        referencePhotoBytes,
        filename: referenceFileName,
      ),
    });

    final response = await apiClient.dio.post('/face/enroll', data: formData);
    final data = response.data['data'] as Map<String, dynamic>;
    return FaceEnrollResultModel.fromJson(data);
  }
}
