import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/error/failures.dart';
import 'domain/profile_domain.dart';

export 'domain/profile_domain.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final ProfileData data;

  const ProfileLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class ProfileLoggedOut extends ProfileState {}

class ProfileFailure extends ProfileState {
  final Failure failure;

  const ProfileFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}

class ProfileCubit extends Cubit<ProfileState> {
  final GetProfileInfoUseCase getProfileInfoUseCase;
  final LogoutUseCase logoutUseCase;

  ProfileCubit({
    required this.getProfileInfoUseCase,
    required this.logoutUseCase,
  }) : super(ProfileInitial());

  Future<void> loadProfile() async {
    emit(ProfileLoading());
    try {
      final data = await getProfileInfoUseCase();
      emit(ProfileLoaded(data));
    } on Failure catch (f) {
      emit(ProfileFailure(f));
    } catch (e) {
      emit(ProfileFailure(
        ServerFailure(message: e.toString(), code: 'SERVER_ERROR'),
      ));
    }
  }

  Future<void> logout() async {
    emit(ProfileLoading());
    await logoutUseCase();
    emit(ProfileLoggedOut());
  }
}
