import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/usecases/attendance_usecases.dart';

abstract class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistorySuccess extends HistoryState {
  final AttendanceHistory history;

  const HistorySuccess(this.history);

  @override
  List<Object?> get props => [history];
}

class HistoryFailure extends HistoryState {
  final Failure failure;

  const HistoryFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}

class HistoryCubit extends Cubit<HistoryState> {
  final GetAttendanceHistoryUseCase getAttendanceHistoryUseCase;

  HistoryCubit({required this.getAttendanceHistoryUseCase})
      : super(HistoryInitial());

  Future<void> loadHistory({String? month}) async {
    emit(HistoryLoading());
    try {
      final history = await getAttendanceHistoryUseCase(month: month);
      emit(HistorySuccess(history));
    } on Failure catch (f) {
      emit(HistoryFailure(f));
    } catch (e) {
      emit(HistoryFailure(
        ServerFailure(message: e.toString(), code: 'SERVER_ERROR'),
      ));
    }
  }
}
