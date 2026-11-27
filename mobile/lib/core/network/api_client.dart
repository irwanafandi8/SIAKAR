import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../error/error_messages.dart';
import '../error/failures.dart';

class ApiClient {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  ApiClient({Dio? dio, FlutterSecureStorage? secureStorage})
      : dio = dio ?? Dio(),
        secureStorage = secureStorage ?? const FlutterSecureStorage() {
    this.dio.options = BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
      headers: {
        'Accept': 'application/json',
      },
    );

    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await this.secureStorage.read(key: AppConfig.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final deviceId =
              await this.secureStorage.read(key: AppConfig.deviceIdKey);
          if (deviceId != null && deviceId.isNotEmpty) {
            options.headers['X-Device-Id'] = deviceId;
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          final mappedFailure = _mapDioException(error);
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: mappedFailure,
              response: error.response,
              type: error.type,
            ),
          );
        },
      ),
    );
  }

  Failure _mapDioException(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkFailure();
    }

    final response = error.response;
    if (response != null && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final code = data['code']?.toString() ?? 'SERVER_ERROR';
      final message = ErrorMessages.fromCode(code, data['message']?.toString());

      if (code == 'VALIDATION_ERROR') {
        Map<String, List<String>>? validationErrors;
        if (data['errors'] is Map) {
          validationErrors = (data['errors'] as Map).map(
            (key, value) => MapEntry(
              key.toString(),
              (value as List).map((e) => e.toString()).toList(),
            ),
          );
        }
        return ValidationFailure(message: message, errors: validationErrors);
      }

      if (code == 'FACE_MISMATCH') {
        final extra = data['data'] as Map<String, dynamic>?;
        final sim = extra?['similarity'] != null ? (extra!['similarity'] as num).toDouble() : null;
        return FaceMismatchFailure(message: message, similarity: sim);
      }

      if (code == 'OUT_OF_RADIUS') {
        final extra = data['data'] as Map<String, dynamic>?;
        final dist = extra?['distance_meter'] != null ? (extra!['distance_meter'] as num).toDouble() : null;
        return OutOfRadiusFailure(message: message, distanceMeter: dist);
      }

      if (code == 'UNAUTHENTICATED' || code == 'INVALID_CREDENTIALS' || code == 'DEVICE_MISMATCH') {
        return AuthFailure(message: message, code: code);
      }

      return ServerFailure(message: message, code: code);
    }

    return ServerFailure(
      message: error.message ?? 'Terjadi kesalahan pada server.',
      code: 'SERVER_ERROR',
    );
  }
}
