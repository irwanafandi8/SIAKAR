import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // 1. External & Core
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(secureStorage: sl<FlutterSecureStorage>()),
  );

  // 2. Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      apiClient: sl<ApiClient>(),
      secureStorage: sl<FlutterSecureStorage>(),
    ),
  );

  // 3. UseCase
  sl.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(sl<AuthRepository>()),
  );

  // 4. Cubit
  sl.registerFactory<AuthCubit>(
    () => AuthCubit(
      loginUseCase: sl<LoginUseCase>(),
      authRepository: sl<AuthRepository>(),
    ),
  );
}
