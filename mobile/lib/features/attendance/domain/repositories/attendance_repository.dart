import 'dart:typed_data';
import '../entities/attendance_entities.dart';

abstract class AttendanceRepository {
  Future<TodayAttendanceInfo> getTodayInfo();
  Future<AttendanceHistory> getHistory({String? month});
}

/// Kontrak pengiriman absensi masuk/pulang ke server tanpa waktu klien & tanpa retry otomatis.
abstract class AttendanceActionRepository {
  Future<AttendanceSubmissionResult> submitAttendance({
    required AttendanceMode mode,
    required List<double> embedding,
    required double latitude,
    required double longitude,
    required bool livenessPassed,
    required Uint8List photoBytes,
    String photoFileName = 'attendance_proof.jpg',
  });
}

/// Kontrak penyedia posisi GPS murni domain untuk fitur absensi.
abstract class AttendanceLocationProvider {
  Future<AttendanceGpsPosition> getCurrentPosition();
  Future<bool> openLocationSettings();
}
