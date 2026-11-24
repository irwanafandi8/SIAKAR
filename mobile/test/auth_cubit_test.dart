import 'package:flutter_test/flutter_test.dart';
import 'package:siakar_mobile/features/auth/domain/entities/user.dart';
import 'package:siakar_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:siakar_mobile/features/auth/domain/usecases/login_usecase.dart';
import 'package:siakar_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:siakar_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:siakar_mobile/core/error/failures.dart';

class MockAuthRepository implements AuthRepository {
  bool shouldFail = false;

  @override
  Future<User> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    if (shouldFail) {
      throw const AuthFailure(
        message: 'Username atau kata sandi tidak sesuai.',
        code: 'INVALID_CREDENTIALS',
      );
    }
    return const User(
      idPengguna: 1,
      idKaryawan: 10,
      nama: 'Budi Santoso',
      nik: 'KRY-001',
      role: 'karyawan',
      faceEnrolled: true,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User?> getCurrentUser() async {
    return null;
  }
}

void main() {
  late MockAuthRepository mockRepository;
  late LoginUseCase loginUseCase;
  late AuthCubit cubit;

  setUp(() {
    mockRepository = MockAuthRepository();
    loginUseCase = LoginUseCase(mockRepository);
    cubit = AuthCubit(
      loginUseCase: loginUseCase,
      authRepository: mockRepository,
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state should be AuthInitial', () {
    expect(cubit.state, equals(AuthInitial()));
  });

  test('login success emits [AuthLoading, Authenticated]', () async {
    mockRepository.shouldFail = false;

    final expectedStates = [
      AuthLoading(),
      const Authenticated(User(
        idPengguna: 1,
        idKaryawan: 10,
        nama: 'Budi Santoso',
        nik: 'KRY-001',
        role: 'karyawan',
        faceEnrolled: true,
      )),
    ];

    expectLater(cubit.stream, emitsInOrder(expectedStates));

    await cubit.login(
      username: 'karyawan',
      password: 'password123',
      deviceId: 'dev_01',
    );
  });

  test('login failure emits [AuthLoading, AuthFailureState]', () async {
    mockRepository.shouldFail = true;

    final expectedStates = [
      AuthLoading(),
      const AuthFailureState(
        message: 'Username atau kata sandi tidak sesuai.',
        code: 'INVALID_CREDENTIALS',
      ),
    ];

    expectLater(cubit.stream, emitsInOrder(expectedStates));

    await cubit.login(
      username: 'wrong',
      password: 'wrong',
      deviceId: 'dev_01',
    );
  });
}
