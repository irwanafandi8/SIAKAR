import 'package:dio/dio.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../domain/profile_domain.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient apiClient;

  const ProfileRepositoryImpl({required this.apiClient});

  @override
  Future<FaceEnrollmentStatus> getFaceStatus() async {
    try {
      final response = await apiClient.dio.get('/face/status');
      final data = response.data['data'] as Map<String, dynamic>;
      return FaceEnrollmentStatus(
        enrolled: data['enrolled'] == true,
        enrolledAt: data['enrolled_at']?.toString(),
      );
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal memuat status wajah.',
        code: 'SERVER_ERROR',
      );
    }
  }
}
