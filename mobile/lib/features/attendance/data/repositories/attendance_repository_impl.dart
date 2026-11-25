import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_datasource.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
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
}
