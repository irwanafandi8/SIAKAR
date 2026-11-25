import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/leave_entities.dart';
import '../../domain/usecases/leave_usecases.dart';

abstract class LeaveState extends Equatable {
  const LeaveState();

  @override
  List<Object?> get props => [];
}

class LeaveInitial extends LeaveState {}

class LeaveLoading extends LeaveState {}

class LeaveLoaded extends LeaveState {
  final List<LeaveRequestEntity> items;
  final String? activeStatusFilter;

  const LeaveLoaded({
    required this.items,
    this.activeStatusFilter,
  });

  @override
  List<Object?> get props => [items, activeStatusFilter];
}

class LeaveSubmitting extends LeaveState {}

class LeaveSubmitSuccess extends LeaveState {
  final LeaveRequestEntity created;

  const LeaveSubmitSuccess(this.created);

  @override
  List<Object?> get props => [created];
}

class LeaveFailure extends LeaveState {
  final Failure failure;

  const LeaveFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}

class LeaveCubit extends Cubit<LeaveState> {
  final GetMyLeavesUseCase getMyLeavesUseCase;
  final SubmitLeaveUseCase submitLeaveUseCase;

  LeaveCubit({
    required this.getMyLeavesUseCase,
    required this.submitLeaveUseCase,
  }) : super(LeaveInitial());

  Future<void> loadLeaves({String? status}) async {
    emit(LeaveLoading());
    try {
      final items = await getMyLeavesUseCase(status: status);
      emit(LeaveLoaded(items: items, activeStatusFilter: status));
    } on Failure catch (f) {
      emit(LeaveFailure(f));
    } catch (e) {
      emit(LeaveFailure(
        ServerFailure(message: e.toString(), code: 'SERVER_ERROR'),
      ));
    }
  }

  Future<void> submitLeave({
    required String jenis,
    required String tanggalMulai,
    required String tanggalSelesai,
    required String alasan,
    String? attachmentPath,
  }) async {
    emit(LeaveSubmitting());
    try {
      final created = await submitLeaveUseCase(
        jenis: jenis,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        alasan: alasan,
        attachmentPath: attachmentPath,
      );
      emit(LeaveSubmitSuccess(created));
    } on Failure catch (f) {
      emit(LeaveFailure(f));
    } catch (e) {
      emit(LeaveFailure(
        ServerFailure(message: e.toString(), code: 'SERVER_ERROR'),
      ));
    }
  }
}
