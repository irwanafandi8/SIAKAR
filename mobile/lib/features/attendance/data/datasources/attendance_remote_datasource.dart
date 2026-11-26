import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/attendance_entities.dart';
import '../models/attendance_models.dart';

class AttendanceRemoteDataSource {
  final ApiClient apiClient;

  const AttendanceRemoteDataSource({required this.apiClient});

  Future<TodayAttendanceInfoModel> getTodayInfo() async {
    final response = await apiClient.dio.get('/attendance/today');
    final data = response.data['data'] as Map<String, dynamic>;
    return TodayAttendanceInfoModel.fromJson(data);
  }

  Future<AttendanceHistoryModel> getHistory({String? month}) async {
    final response = await apiClient.dio.get(
      '/attendance/history',
      queryParameters: (month != null && month.isNotEmpty) ? {'month': month} : null,
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return AttendanceHistoryModel.fromJson(data);
  }

  /// Kirim POST /attendance/check-in atau POST /attendance/check-out (multipart/form-data).
  /// Dilarang mengirim waktu klien dan dilarang melakukan retry otomatis (API.md §3.3 & §5).
  Future<AttendanceSubmissionResultModel> submitAttendance({
    required AttendanceMode mode,
    required List<double> embedding,
    required double latitude,
    required double longitude,
    required bool livenessPassed,
    required Uint8List photoBytes,
    String photoFileName = 'attendance_proof.jpg',
  }) async {
    final endpoint = mode == AttendanceMode.checkOut
        ? '/attendance/check-out'
        : '/attendance/check-in';

    final formData = FormData.fromMap({
      'embedding': jsonEncode(embedding),
      'latitude': latitude,
      'longitude': longitude,
      'liveness_passed': livenessPassed ? '1' : '0',
      'photo': MultipartFile.fromBytes(
        photoBytes,
        filename: photoFileName,
      ),
    });

    final response = await apiClient.dio.post(endpoint, data: formData);
    final data = response.data['data'] as Map<String, dynamic>;
    return AttendanceSubmissionResultModel.fromJson(data, mode: mode);
  }
}
