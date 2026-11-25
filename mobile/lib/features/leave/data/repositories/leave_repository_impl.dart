import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/leave_entities.dart';
import '../../domain/repositories/leave_repository.dart';
import '../datasources/leave_remote_datasource.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  final LeaveRemoteDataSource remoteDataSource;

  const LeaveRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<LeaveRequestEntity>> getMyLeaves({String? status}) async {
    try {
      return await remoteDataSource.getMyLeaves(status: status);
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal memuat daftar izin.',
        code: 'SERVER_ERROR',
      );
    }
  }

  @override
  Future<LeaveRequestEntity> submitLeave({
    required String jenis,
    required String tanggalMulai,
    required String tanggalSelesai,
    required String alasan,
    String? attachmentPath,
  }) async {
    try {
      return await remoteDataSource.submitLeave(
        jenis: jenis,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        alasan: alasan,
        attachmentPath: attachmentPath,
      );
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal mengirim pengajuan izin.',
        code: 'SERVER_ERROR',
      );
    }
  }
}
