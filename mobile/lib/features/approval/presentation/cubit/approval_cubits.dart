import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../leave/domain/entities/leave_entities.dart';
import '../../domain/entities/team_recap_entity.dart';
import '../../domain/usecases/approval_usecases.dart';

abstract class ApprovalState extends Equatable {
  const ApprovalState();

  @override
  List<Object?> get props => [];
}

class ApprovalInitial extends ApprovalState {}

class ApprovalLoading extends ApprovalState {}

class ApprovalLoaded extends ApprovalState {
  final List<LeaveRequestEntity> items;
  final String activeStatus;
  final String? actionMessage;

  const ApprovalLoaded({
    required this.items,
    required this.activeStatus,
    this.actionMessage,
  });

  @override
  List<Object?> get props => [items, activeStatus, actionMessage];
}

class ApprovalFailure extends ApprovalState {
  final Failure failure;

  const ApprovalFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}

class ApprovalCubit extends Cubit<ApprovalState> {
  final GetApprovalsUseCase getApprovalsUseCase;
  final ApproveLeaveUseCase approveLeaveUseCase;
  final RejectLeaveUseCase rejectLeaveUseCase;

  ApprovalCubit({
    required this.getApprovalsUseCase,
    required this.approveLeaveUseCase,
    required this.rejectLeaveUseCase,
  }) : super(ApprovalInitial());

  Future<void> loadApprovals({String status = 'menunggu'}) async {
    emit(ApprovalLoading());
    try {
      final items = await getApprovalsUseCase(status: status);
      emit(ApprovalLoaded(items: items, activeStatus: status));
    } on Failure catch (f) {
      emit(ApprovalFailure(f));
    } catch (e) {
      emit(ApprovalFailure(
        ServerFailure(message: e.toString(), code: 'SERVER_ERROR'),
      ));
    }
  }

  Future<void> decide({
    required int idIzin,
    required bool approve,
    String currentStatus = 'menunggu',
  }) async {
    emit(ApprovalLoading());
    try {
      if (approve) {
        await approveLeaveUseCase(idIzin);
      } else {
        await rejectLeaveUseCase(idIzin);
      }
      final refreshed = await getApprovalsUseCase(status: currentStatus);
      emit(ApprovalLoaded(
        items: refreshed,
        activeStatus: currentStatus,
        actionMessage: approve
            ? 'Pengajuan izin berhasil disetujui.'
            : 'Pengajuan izin berhasil ditolak.',
      ));
    } on Failure catch (f) {
      emit(ApprovalFailure(f));
    } catch (e) {
      emit(ApprovalFailure(
        ServerFailure(message: e.toString(), code: 'SERVER_ERROR'),
      ));
    }
  }
}

abstract class TeamRecapState extends Equatable {
  const TeamRecapState();

  @override
  List<Object?> get props => [];
}

class TeamRecapInitial extends TeamRecapState {}

class TeamRecapLoading extends TeamRecapState {}

class TeamRecapSuccess extends TeamRecapState {
  final List<SubordinateRecapItem> items;
  final String from;
  final String to;

  const TeamRecapSuccess({
    required this.items,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [items, from, to];
}

class TeamRecapFailure extends TeamRecapState {
  final Failure failure;

  const TeamRecapFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}

class TeamRecapCubit extends Cubit<TeamRecapState> {
  final GetTeamRecapUseCase getTeamRecapUseCase;

  TeamRecapCubit({required this.getTeamRecapUseCase})
      : super(TeamRecapInitial());

  Future<void> loadRecap({required String from, required String to}) async {
    emit(TeamRecapLoading());
    try {
      final items = await getTeamRecapUseCase(from: from, to: to);
      emit(TeamRecapSuccess(items: items, from: from, to: to));
    } on Failure catch (f) {
      emit(TeamRecapFailure(f));
    } catch (e) {
      emit(TeamRecapFailure(
        ServerFailure(message: e.toString(), code: 'SERVER_ERROR'),
      ));
    }
  }
}
