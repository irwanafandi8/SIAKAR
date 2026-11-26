import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/device/location_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_datasource.dart';

class AttendanceRepositoryImpl
    implements AttendanceRepository, AttendanceActionRepository {
  final AttendanceRemoteDataSource remoteDataSource;

  const AttendanceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<TodayAttendanceInfo> getTodayInfo() async {
    try {
      return await remoteDataSource.getTodayInfo();
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal memuat data absensi hari ini.',
        code: 'SERVER_ERROR',
      );
    }
  }

  @override
  Future<AttendanceHistory> getHistory({String? month}) async {
    try {
      return await remoteDataSource.getHistory(month: month);
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal memuat riwayat kehadiran.',
        code: 'SERVER_ERROR',
      );
    }
  }

  @override
  Future<AttendanceSubmissionResult> submitAttendance({
    required AttendanceMode mode,
    required List<double> embedding,
    required double latitude,
    required double longitude,
    required bool livenessPassed,
    required Uint8List photoBytes,
    String photoFileName = 'attendance_proof.jpg',
  }) async {
    try {
      return await remoteDataSource.submitAttendance(
        mode: mode,
        embedding: embedding,
        latitude: latitude,
        longitude: longitude,
        livenessPassed: livenessPassed,
        photoBytes: photoBytes,
        photoFileName: photoFileName,
      );
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal mengirim data absensi ke server.',
        code: 'SERVER_ERROR',
      );
    }
  }
}

/// Adaptor lapisan data yang menghubungkan `LocationService` perangkat ke kontrak domain.
class GeolocatorAttendanceLocationProvider
    implements AttendanceLocationProvider {
  final LocationService locationService;

  const GeolocatorAttendanceLocationProvider({required this.locationService});

  @override
  Future<AttendanceGpsPosition> getCurrentPosition() async {
    final pos = await locationService.getCurrentPosition();
    return AttendanceGpsPosition(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracyMeters: pos.accuracyMeters,
    );
  }

  @override
  Future<bool> openLocationSettings() {
    return locationService.openLocationSettings();
  }
}
