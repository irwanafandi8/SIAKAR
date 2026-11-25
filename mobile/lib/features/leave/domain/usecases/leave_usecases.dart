import '../entities/leave_entities.dart';
import '../repositories/leave_repository.dart';

class GetMyLeavesUseCase {
  final LeaveRepository repository;

  const GetMyLeavesUseCase(this.repository);

  Future<List<LeaveRequestEntity>> call({String? status}) {
    return repository.getMyLeaves(status: status);
  }
}

class SubmitLeaveUseCase {
  final LeaveRepository repository;

  const SubmitLeaveUseCase(this.repository);

  Future<LeaveRequestEntity> call({
    required String jenis,
    required String tanggalMulai,
    required String tanggalSelesai,
    required String alasan,
    String? attachmentPath,
  }) {
    return repository.submitLeave(
      jenis: jenis,
      tanggalMulai: tanggalMulai,
      tanggalSelesai: tanggalSelesai,
      alasan: alasan,
      attachmentPath: attachmentPath,
    );
  }
}
