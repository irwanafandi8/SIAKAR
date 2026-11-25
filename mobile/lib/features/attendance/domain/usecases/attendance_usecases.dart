import '../entities/attendance_entities.dart';
import '../repositories/attendance_repository.dart';

class GetTodayAttendanceUseCase {
  final AttendanceRepository repository;

  const GetTodayAttendanceUseCase(this.repository);

  Future<TodayAttendanceInfo> call() {
    return repository.getTodayInfo();
  }
}

class GetAttendanceHistoryUseCase {
  final AttendanceRepository repository;

  const GetAttendanceHistoryUseCase(this.repository);

  Future<AttendanceHistory> call({String? month}) {
    return repository.getHistory(month: month);
  }
}
