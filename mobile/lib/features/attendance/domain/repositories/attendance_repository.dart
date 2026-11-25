import '../entities/attendance_entities.dart';

abstract class AttendanceRepository {
  Future<TodayAttendanceInfo> getTodayInfo();
  Future<AttendanceHistory> getHistory({String? month});
}
