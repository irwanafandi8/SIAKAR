import '../../../leave/domain/entities/leave_entities.dart';
import '../entities/team_recap_entity.dart';

abstract class ApprovalRepository {
  Future<List<LeaveRequestEntity>> getApprovals({String? status});
  Future<LeaveRequestEntity> approveLeave(int idIzin);
  Future<LeaveRequestEntity> rejectLeave(int idIzin);
  Future<List<SubordinateRecapItem>> getTeamRecap({
    required String from,
    required String to,
  });
}
