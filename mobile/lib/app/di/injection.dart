import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import '../../core/device/location_service.dart';
import '../../core/device/permission_service.dart';
import '../../core/ml/detector_service.dart';
import '../../core/ml/embedding_service.dart';
import '../../core/ml/face_oval_validator.dart';
import '../../core/ml/liveness_service.dart';
import '../../core/ml/preprocess.dart';
import '../../core/network/api_client.dart';
import '../../features/face_enrollment/data/datasources/face_enrollment_remote_datasource.dart';
import '../../features/face_enrollment/data/datasources/ml_face_sample_extractor.dart';
import '../../features/face_enrollment/data/repositories/face_enrollment_repository_impl.dart';
import '../../features/face_enrollment/domain/repositories/face_enrollment_repository.dart';
import '../../features/face_enrollment/domain/usecases/face_enrollment_usecases.dart';
import '../../features/face_enrollment/presentation/cubit/face_enrollment_cubit.dart';
import '../../features/approval/data/approval_data.dart';
import '../../features/approval/domain/repositories/approval_repository.dart';
import '../../features/approval/domain/usecases/approval_usecases.dart';
import '../../features/approval/presentation/cubit/approval_cubits.dart';
import '../../features/attendance/data/datasources/attendance_remote_datasource.dart';
import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/domain/usecases/attendance_usecases.dart';
import '../../features/attendance/presentation/cubit/attendance_capture_cubit.dart';
import '../../features/attendance/presentation/cubit/history_cubit.dart';
import '../../features/attendance/presentation/cubit/today_attendance_cubit.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/leave/data/datasources/leave_remote_datasource.dart';
import '../../features/leave/data/repositories/leave_repository_impl.dart';
import '../../features/leave/domain/repositories/leave_repository.dart';
import '../../features/leave/domain/usecases/leave_usecases.dart';
import '../../features/leave/presentation/cubit/leave_cubit.dart';
import '../../features/profile/data/profile_repository_impl.dart';
import '../../features/profile/profile_feature.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // 1. External & Core
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(secureStorage: sl<FlutterSecureStorage>()),
  );

  // 1b. ML Core (Praproses + TFLite Embedding)
  PreprocessService preprocessService;
  try {
    preprocessService = await PreprocessService.fromAsset();
  } catch (_) {
    preprocessService = PreprocessService.defaultConfig();
  }
  sl.registerSingleton<PreprocessService>(preprocessService);

  sl.registerLazySingleton<EmbeddingService>(
    () => TfliteEmbeddingService(
      preprocessService: sl<PreprocessService>(),
    ),
  );

  sl.registerLazySingleton<DetectorService>(
    () => TfliteDetectorService(
      preprocessService: sl<PreprocessService>(),
    ),
  );

  sl.registerLazySingleton<LivenessService>(
    () => ChallengeResponseLivenessService(),
  );

  sl.registerLazySingleton<FaceInOvalValidator>(
    () => DefaultFaceOvalValidator(
      preprocessService: sl<PreprocessService>(),
      detectorService: sl<DetectorService>(),
    ),
  );

  // 1c. Device Services (Izin Kontekstual & GPS M4)
  sl.registerLazySingleton<DevicePermissionService>(
    () => const PermissionHandlerService(),
  );
  sl.registerLazySingleton<LocationService>(
    () => GeolocatorLocationService(
      permissionService: sl<DevicePermissionService>(),
    ),
  );

  // 2. DataSources
  sl.registerLazySingleton<FaceEnrollmentRemoteDataSource>(
    () => FaceEnrollmentRemoteDataSource(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<FaceSampleExtractor>(
    () => MlFaceSampleExtractor(
      ovalValidator: sl<FaceInOvalValidator>(),
      embeddingService: sl<EmbeddingService>(),
    ),
  );
  sl.registerLazySingleton<AttendanceRemoteDataSource>(
    () => AttendanceRemoteDataSource(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<LeaveRemoteDataSource>(
    () => LeaveRemoteDataSource(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<ApprovalRemoteDataSource>(
    () => ApprovalRemoteDataSource(apiClient: sl<ApiClient>()),
  );

  // 3. Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      apiClient: sl<ApiClient>(),
      secureStorage: sl<FlutterSecureStorage>(),
    ),
  );
  sl.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(
      remoteDataSource: sl<AttendanceRemoteDataSource>(),
    ),
  );
  sl.registerLazySingleton<AttendanceActionRepository>(
    () => AttendanceRepositoryImpl(
      remoteDataSource: sl<AttendanceRemoteDataSource>(),
    ),
  );
  sl.registerLazySingleton<AttendanceLocationProvider>(
    () => GeolocatorAttendanceLocationProvider(
      locationService: sl<LocationService>(),
    ),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<LeaveRepository>(
    () => LeaveRepositoryImpl(remoteDataSource: sl<LeaveRemoteDataSource>()),
  );
  sl.registerLazySingleton<ApprovalRepository>(
    () => ApprovalRepositoryImpl(
      remoteDataSource: sl<ApprovalRemoteDataSource>(),
    ),
  );
  sl.registerLazySingleton<FaceEnrollmentRepository>(
    () => FaceEnrollmentRepositoryImpl(
      remoteDataSource: sl<FaceEnrollmentRemoteDataSource>(),
    ),
  );

  // 4. UseCases
  sl.registerLazySingleton<GetFaceEnrollmentStatusUseCase>(
    () => GetFaceEnrollmentStatusUseCase(sl<FaceEnrollmentRepository>()),
  );
  sl.registerLazySingleton<ExtractFaceSampleUseCase>(
    () => ExtractFaceSampleUseCase(sl<FaceSampleExtractor>()),
  );
  sl.registerLazySingleton<SubmitFaceEnrollmentUseCase>(
    () => SubmitFaceEnrollmentUseCase(sl<FaceEnrollmentRepository>()),
  );
  sl.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton<GetTodayAttendanceUseCase>(
    () => GetTodayAttendanceUseCase(sl<AttendanceRepository>()),
  );
  sl.registerLazySingleton<GetAttendanceHistoryUseCase>(
    () => GetAttendanceHistoryUseCase(sl<AttendanceRepository>()),
  );
  sl.registerLazySingleton<AcquireAttendanceLocationUseCase>(
    () => AcquireAttendanceLocationUseCase(sl<AttendanceLocationProvider>()),
  );
  sl.registerLazySingleton<OpenLocationSettingsUseCase>(
    () => OpenLocationSettingsUseCase(sl<AttendanceLocationProvider>()),
  );
  sl.registerLazySingleton<StartLivenessChallengeUseCase>(
    () => StartLivenessChallengeUseCase(
      sampleExtractor: sl<FaceSampleExtractor>(),
      livenessService: sl<LivenessService>(),
    ),
  );
  sl.registerLazySingleton<SubmitAttendanceUseCase>(
    () => SubmitAttendanceUseCase(
      sampleExtractor: sl<FaceSampleExtractor>(),
      livenessService: sl<LivenessService>(),
      actionRepository: sl<AttendanceActionRepository>(),
    ),
  );
  sl.registerLazySingleton<GetProfileInfoUseCase>(
    () => GetProfileInfoUseCase(
      authRepository: sl<AuthRepository>(),
      profileRepository: sl<ProfileRepository>(),
    ),
  );
  sl.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton<GetMyLeavesUseCase>(
    () => GetMyLeavesUseCase(sl<LeaveRepository>()),
  );
  sl.registerLazySingleton<SubmitLeaveUseCase>(
    () => SubmitLeaveUseCase(sl<LeaveRepository>()),
  );
  sl.registerLazySingleton<GetApprovalsUseCase>(
    () => GetApprovalsUseCase(sl<ApprovalRepository>()),
  );
  sl.registerLazySingleton<ApproveLeaveUseCase>(
    () => ApproveLeaveUseCase(sl<ApprovalRepository>()),
  );
  sl.registerLazySingleton<RejectLeaveUseCase>(
    () => RejectLeaveUseCase(sl<ApprovalRepository>()),
  );
  sl.registerLazySingleton<GetTeamRecapUseCase>(
    () => GetTeamRecapUseCase(sl<ApprovalRepository>()),
  );

  // 5. Cubits
  sl.registerFactory<AuthCubit>(
    () => AuthCubit(
      loginUseCase: sl<LoginUseCase>(),
      authRepository: sl<AuthRepository>(),
    ),
  );
  sl.registerFactory<TodayAttendanceCubit>(
    () => TodayAttendanceCubit(
      getTodayAttendanceUseCase: sl<GetTodayAttendanceUseCase>(),
    ),
  );
  sl.registerFactory<HistoryCubit>(
    () => HistoryCubit(
      getAttendanceHistoryUseCase: sl<GetAttendanceHistoryUseCase>(),
    ),
  );
  sl.registerFactory<AttendanceCaptureCubit>(
    () => AttendanceCaptureCubit(
      getTodayAttendanceUseCase: sl<GetTodayAttendanceUseCase>(),
      acquireLocationUseCase: sl<AcquireAttendanceLocationUseCase>(),
      startLivenessChallengeUseCase: sl<StartLivenessChallengeUseCase>(),
      submitAttendanceUseCase: sl<SubmitAttendanceUseCase>(),
      openLocationSettingsUseCase: sl<OpenLocationSettingsUseCase>(),
    ),
  );
  sl.registerFactory<ProfileCubit>(
    () => ProfileCubit(
      getProfileInfoUseCase: sl<GetProfileInfoUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
    ),
  );
  sl.registerFactory<LeaveCubit>(
    () => LeaveCubit(
      getMyLeavesUseCase: sl<GetMyLeavesUseCase>(),
      submitLeaveUseCase: sl<SubmitLeaveUseCase>(),
    ),
  );
  sl.registerFactory<ApprovalCubit>(
    () => ApprovalCubit(
      getApprovalsUseCase: sl<GetApprovalsUseCase>(),
      approveLeaveUseCase: sl<ApproveLeaveUseCase>(),
      rejectLeaveUseCase: sl<RejectLeaveUseCase>(),
    ),
  );
  sl.registerFactory<TeamRecapCubit>(
    () => TeamRecapCubit(
      getTeamRecapUseCase: sl<GetTeamRecapUseCase>(),
    ),
  );
  sl.registerFactory<FaceEnrollmentCubit>(
    () => FaceEnrollmentCubit(
      getStatusUseCase: sl<GetFaceEnrollmentStatusUseCase>(),
      extractSampleUseCase: sl<ExtractFaceSampleUseCase>(),
      submitEnrollmentUseCase: sl<SubmitFaceEnrollmentUseCase>(),
    ),
  );
}
