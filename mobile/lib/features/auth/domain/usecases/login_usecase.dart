import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<User> call({
    required String username,
    required String password,
    required String deviceId,
  }) {
    return repository.login(
      username: username,
      password: password,
      deviceId: deviceId,
    );
  }
}
