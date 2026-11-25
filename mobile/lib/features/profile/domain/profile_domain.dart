import 'package:equatable/equatable.dart';
import '../../../core/error/failures.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/domain/repositories/auth_repository.dart';

class FaceEnrollmentStatus extends Equatable {
  final bool enrolled;
  final String? enrolledAt;

  const FaceEnrollmentStatus({
    required this.enrolled,
    this.enrolledAt,
  });

  @override
  List<Object?> get props => [enrolled, enrolledAt];
}

class ProfileData extends Equatable {
  final User user;
  final FaceEnrollmentStatus faceStatus;

  const ProfileData({
    required this.user,
    required this.faceStatus,
  });

  @override
  List<Object?> get props => [user, faceStatus];
}

abstract class ProfileRepository {
  Future<FaceEnrollmentStatus> getFaceStatus();
}

class GetProfileInfoUseCase {
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  const GetProfileInfoUseCase({
    required this.authRepository,
    required this.profileRepository,
  });

  Future<ProfileData> call() async {
    final user = await authRepository.getCurrentUser();
    if (user == null) {
      throw const AuthFailure(
        message: 'Sesi login telah berakhir. Silakan masuk kembali.',
        code: 'UNAUTHENTICATED',
      );
    }
    final faceStatus = await profileRepository.getFaceStatus();
    return ProfileData(user: user, faceStatus: faceStatus);
  }
}

class LogoutUseCase {
  final AuthRepository authRepository;

  const LogoutUseCase(this.authRepository);

  Future<void> call() {
    return authRepository.logout();
  }
}
