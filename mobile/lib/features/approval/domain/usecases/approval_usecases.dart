import '../../../leave/domain/entities/leave_entities.dart';
import '../entities/team_recap_entity.dart';
import '../repositories/approval_repository.dart';

class GetApprovalsUseCase {
  final ApprovalRepository repository;

  const GetApprovalsUseCase(this.repository);

  Future<List<LeaveRequestEntity>> call({String? status}) {
    return repository.getApprovals(status: status);
  }
}

class ApproveLeaveUseCase {
  final ApprovalRepository repository;

  const ApproveLeaveUseCase(this.repository);

  Future<LeaveRequestEntity> call(int idIzin) {
    return repository.approveLeave(idIzin);
  }
}

class RejectLeaveUseCase {
  final ApprovalRepository repository;

  const RejectLeaveUseCase(this.repository);

  Future<LeaveRequestEntity> call(int idIzin) {
    return repository.rejectLeave(idIzin);
  }
}

class GetTeamRecapUseCase {
  final ApprovalRepository repository;

  const GetTeamRecapUseCase(this.repository);

  Future<List<SubordinateRecapItem>> call({
    required String from,
    required String to,
  }) {
    return repository.getTeamRecap(from: from, to: to);
  }
}
