import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/usecases/attendance_usecases.dart';

abstract class TodayAttendanceState extends Equatable {
  const TodayAttendanceState();

  @override
  List<Object?> get props => [];
}

class TodayAttendanceInitial extends TodayAttendanceState {}

class TodayAttendanceLoading extends TodayAttendanceState {}

class TodayAttendanceSuccess extends TodayAttendanceState {
  final TodayAttendanceInfo info;

  const TodayAttendanceSuccess(this.info);

  @override
  List<Object?> get props => [info];
}

class TodayAttendanceFailure extends TodayAttendanceState {
  final Failure failure;

  const TodayAttendanceFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}

class TodayAttendanceCubit extends Cubit<TodayAttendanceState> {
  final GetTodayAttendanceUseCase getTodayAttendanceUseCase;

  TodayAttendanceCubit({required this.getTodayAttendanceUseCase})
      : super(TodayAttendanceInitial());

  Future<void> loadToday() async {
    emit(TodayAttendanceLoading());
    try {
      final info = await getTodayAttendanceUseCase();
      emit(TodayAttendanceSuccess(info));
    } on Failure catch (f) {
      emit(TodayAttendanceFailure(f));
    } catch (e) {
      emit(TodayAttendanceFailure(
        ServerFailure(message: e.toString(), code: 'SERVER_ERROR'),
      ));
    }
  }
}
