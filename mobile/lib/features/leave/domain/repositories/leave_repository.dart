import '../entities/leave_entities.dart';

abstract class LeaveRepository {
  Future<List<LeaveRequestEntity>> getMyLeaves({String? status});

  Future<LeaveRequestEntity> submitLeave({
    required String jenis,
    required String tanggalMulai,
    required String tanggalSelesai,
    required String alasan,
    String? attachmentPath,
  });
}
