import '../../../../core/network/api_client.dart';
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
}
