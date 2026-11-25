import 'package:dio/dio.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../leave/data/models/leave_request_model.dart';
import '../../leave/domain/entities/leave_entities.dart';
import '../domain/entities/team_recap_entity.dart';
import '../domain/repositories/approval_repository.dart';

class SubordinateRecapModel extends SubordinateRecapItem {
  const SubordinateRecapModel({
    required super.idKaryawan,
    required super.nama,
    required super.hadir,
    required super.terlambat,
    required super.izin,
    required super.sakit,
    required super.cuti,
    required super.alpa,
  });

  factory SubordinateRecapModel.fromJson(Map<String, dynamic> json) {
    return SubordinateRecapModel(
      idKaryawan: (json['id_karyawan'] as num).toInt(),
      nama: json['nama']?.toString() ?? '',
      hadir: (json['hadir'] as num?)?.toInt() ?? 0,
      terlambat: (json['terlambat'] as num?)?.toInt() ?? 0,
      izin: (json['izin'] as num?)?.toInt() ?? 0,
      sakit: (json['sakit'] as num?)?.toInt() ?? 0,
      cuti: (json['cuti'] as num?)?.toInt() ?? 0,
      alpa: (json['alpa'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApprovalRemoteDataSource {
  final ApiClient apiClient;

  const ApprovalRemoteDataSource({required this.apiClient});

  Future<List<LeaveRequestModel>> getApprovals({String? status}) async {
    final response = await apiClient.dio.get(
      '/approvals',
      queryParameters: (status != null && status.isNotEmpty) ? {'status': status} : null,
    );
    final raw = response.data['data'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(LeaveRequestModel.fromJson)
        .toList();
  }

  Future<LeaveRequestModel> approveLeave(int idIzin) async {
    final response = await apiClient.dio.post('/approvals/$idIzin/approve');
    final data = response.data['data'] as Map<String, dynamic>;
    return LeaveRequestModel.fromJson(data);
  }

  Future<LeaveRequestModel> rejectLeave(int idIzin) async {
    final response = await apiClient.dio.post('/approvals/$idIzin/reject');
    final data = response.data['data'] as Map<String, dynamic>;
    return LeaveRequestModel.fromJson(data);
  }

  Future<List<SubordinateRecapModel>> getTeamRecap({
    required String from,
    required String to,
  }) async {
    final response = await apiClient.dio.get(
      '/team/recap',
      queryParameters: {'from': from, 'to': to},
    );
    final data = response.data['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(SubordinateRecapModel.fromJson)
        .toList();
  }
}

class ApprovalRepositoryImpl implements ApprovalRepository {
  final ApprovalRemoteDataSource remoteDataSource;

  const ApprovalRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<LeaveRequestEntity>> getApprovals({String? status}) async {
    try {
      return await remoteDataSource.getApprovals(status: status);
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal memuat daftar pengajuan bawahan.',
        code: 'SERVER_ERROR',
      );
    }
  }

  @override
  Future<LeaveRequestEntity> approveLeave(int idIzin) async {
    try {
      return await remoteDataSource.approveLeave(idIzin);
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal menyetujui pengajuan izin.',
        code: 'SERVER_ERROR',
      );
    }
  }

  @override
  Future<LeaveRequestEntity> rejectLeave(int idIzin) async {
    try {
      return await remoteDataSource.rejectLeave(idIzin);
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal menolak pengajuan izin.',
        code: 'SERVER_ERROR',
      );
    }
  }

  @override
  Future<List<SubordinateRecapItem>> getTeamRecap({
    required String from,
    required String to,
  }) async {
    try {
      return await remoteDataSource.getTeamRecap(from: from, to: to);
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal memuat rekap tim.',
        code: 'SERVER_ERROR',
      );
    }
  }
}
