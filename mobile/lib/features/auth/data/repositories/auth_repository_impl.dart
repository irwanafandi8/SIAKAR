import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient apiClient;
  final FlutterSecureStorage secureStorage;

  AuthRepositoryImpl({
    required this.apiClient,
    required this.secureStorage,
  });

  @override
  Future<User> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'device_id': deviceId,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      await secureStorage.write(key: AppConfig.tokenKey, value: token);
      await secureStorage.write(key: AppConfig.deviceIdKey, value: deviceId);

      return user;
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal menghubungi server.',
        code: 'SERVER_ERROR',
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      await apiClient.dio.post('/auth/logout');
    } catch (_) {
      // Abaikan kegagalan jaringan saat logout lokal
    } finally {
      await secureStorage.delete(key: AppConfig.tokenKey);
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final token = await secureStorage.read(key: AppConfig.tokenKey);
      if (token == null || token.isEmpty) {
        return null;
      }

      final response = await apiClient.dio.get('/me');
      final data = response.data['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
