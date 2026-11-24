import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase loginUseCase;
  final AuthRepository authRepository;

  AuthCubit({
    required this.loginUseCase,
    required this.authRepository,
  }) : super(AuthInitial());

  Future<void> checkAuthStatus() async {
    emit(AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (_) {
      emit(Unauthenticated());
    }
  }

  Future<void> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    emit(AuthLoading());
    try {
      final user = await loginUseCase(
        username: username,
        password: password,
        deviceId: deviceId,
      );
      emit(Authenticated(user));
    } on Failure catch (e) {
      emit(AuthFailureState(message: e.message, code: e.code));
    } catch (e) {
      emit(AuthFailureState(
        message: e.toString(),
        code: 'UNKNOWN_ERROR',
      ));
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    await authRepository.logout();
    emit(Unauthenticated());
  }
}
