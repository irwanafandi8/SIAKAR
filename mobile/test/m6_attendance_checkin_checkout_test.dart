import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siakar_mobile/app/di/injection.dart';
import 'package:siakar_mobile/core/device/permission_service.dart';
import 'package:siakar_mobile/core/error/error_messages.dart';
import 'package:siakar_mobile/core/error/failures.dart';
import 'package:siakar_mobile/core/ml/embedding_service.dart';
import 'package:siakar_mobile/core/ml/face_oval_validator.dart';
import 'package:siakar_mobile/core/ml/preprocess.dart';
import 'package:siakar_mobile/design/app_theme.dart';
import 'package:siakar_mobile/design/widgets/face_oval_camera_view.dart';
import 'package:siakar_mobile/features/attendance/domain/entities/attendance_entities.dart';
import 'package:siakar_mobile/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:siakar_mobile/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:siakar_mobile/features/attendance/presentation/cubit/attendance_capture_cubit.dart';
import 'package:siakar_mobile/features/attendance/presentation/cubit/attendance_capture_state.dart';
import 'package:siakar_mobile/features/attendance/presentation/pages/attendance_capture_page.dart';
import 'package:siakar_mobile/features/face_enrollment/data/datasources/ml_face_sample_extractor.dart';
import 'package:siakar_mobile/features/face_enrollment/domain/repositories/face_enrollment_repository.dart';

class _FakeTodayRepo implements AttendanceRepository {
  @override
  Future<TodayAttendanceInfo> getTodayInfo() async {
    return const TodayAttendanceInfo(
      tanggal: '2026-11-26',
      hasSchedule: true,
      isHoliday: false,
      shift: ShiftInfo(
        nama: 'Reguler',
        jamMasuk: '08:00:00',
        jamPulang: '16:00:00',
        toleransiMenit: 10,
      ),
      locations: [
        OfficeLocation(
          idLokasi: 1,
          nama: 'Kantor Pusat',
          latitude: -6.3277,
          longitude: 108.3200,
          radiusMeter: 100,
        ),
        OfficeLocation(
          idLokasi: 2,
          nama: 'Kantor Cabang',
          latitude: -6.3500,
          longitude: 108.3500,
          radiusMeter: 80,
        ),
      ],
    );
  }

  @override
  Future<AttendanceHistory> getHistory({String? month}) {
    throw UnimplementedError();
  }
}

class _FakeLocationProvider implements AttendanceLocationProvider {
  Failure? failureToThrow;
  AttendanceGpsPosition positionToReturn = const AttendanceGpsPosition(
    latitude: -6.3277,
    longitude: 108.3200,
    accuracyMeters: 6.5,
  );
  bool openedSettings = false;

  @override
  Future<AttendanceGpsPosition> getCurrentPosition() async {
    if (failureToThrow != null) {
      throw failureToThrow!;
    }
    return positionToReturn;
  }

  @override
  Future<bool> openLocationSettings() async {
    openedSettings = true;
    return true;
  }
}

class _FakeActionRepository implements AttendanceActionRepository {
  Failure? failureToThrow;
  int submitCallCount = 0;
  AttendanceMode? lastMode;
  double? lastLat;
  double? lastLon;
  bool? lastLiveness;
  List<double>? lastEmbedding;

  AttendanceSubmissionResult? customSuccessResult;

  @override
  Future<AttendanceSubmissionResult> submitAttendance({
    required AttendanceMode mode,
    required List<double> embedding,
    required double latitude,
    required double longitude,
    required bool livenessPassed,
    required Uint8List photoBytes,
    String photoFileName = 'attendance_proof.jpg',
  }) async {
    submitCallCount++;
    lastMode = mode;
    lastLat = latitude;
    lastLon = longitude;
    lastLiveness = livenessPassed;
    lastEmbedding = embedding;

    if (failureToThrow != null) {
      throw failureToThrow!;
    }

    return customSuccessResult ??
        AttendanceSubmissionResult(
          mode: mode,
          status: 'hadir',
          similarity: 0.8312,
          distanceMeter: 12.4,
          attendance: AttendanceRecord(
            idAbsensi: 42,
            tanggal: '2026-11-26',
            jamMasuk: '07:58:10',
            jamPulang: mode == AttendanceMode.checkOut ? '16:04:22' : null,
            status: 'hadir',
            skorWajah: 0.8312,
            lokasi: 'Kantor Pusat',
          ),
        );
  }
}

class _FakeEmbeddingService implements EmbeddingService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<double>> extractEmbedding(img.Image rawImage) async {
    final v = List<double>.filled(128, 0.0);
    v[0] = 1.0;
    return v;
  }

  @override
  Future<List<double>> extractEmbeddingFromBytes(Uint8List imageBytes) async {
    final v = List<double>.filled(128, 0.0);
    v[0] = 1.0;
    return v;
  }

  @override
  Future<List<double>> runOnPreprocessedTensor(Float32List inputNHWC) async {
    final v = List<double>.filled(128, 0.0);
    v[0] = 1.0;
    return v;
  }

  @override
  void dispose() {}
}

class _FakePermissionService implements DevicePermissionService {
  AppPermissionStatus locationStatus;
  AppPermissionStatus cameraStatus;

  _FakePermissionService({
    this.locationStatus = AppPermissionStatus.granted,
    this.cameraStatus = AppPermissionStatus.granted,
  });

  @override
  Future<AppPermissionStatus> checkCameraPermission() async => cameraStatus;

  @override
  Future<AppPermissionStatus> requestCameraPermission() async {
    cameraStatus = AppPermissionStatus.granted;
    return cameraStatus;
  }

  @override
  Future<AppPermissionStatus> checkLocationPermission() async => locationStatus;

  @override
  Future<AppPermissionStatus> requestLocationPermission() async {
    locationStatus = AppPermissionStatus.granted;
    return locationStatus;
  }

  @override
  Future<bool> openSystemAppSettings() async => true;
}

class _FakeCameraAdapter implements FaceCameraControllerAdapter {
  final Uint8List captureBytes;
  bool _initialized = false;

  _FakeCameraAdapter({required this.captureBytes});

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black87);

  @override
  Future<CapturedPhotoData> takePicture() async {
    return CapturedPhotoData(bytes: captureBytes, filePath: 'proof.png');
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}

Uint8List _encodeBlankWallPng() {
  final image = img.Image(width: 128, height: 160, numChannels: 3);
  for (int y = 0; y < 160; y++) {
    for (int x = 0; x < 128; x++) {
      image.setPixelRgb(x, y, 128, 128, 128);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late PreprocessService preprocessService;
  late FaceSampleExtractor sampleExtractor;
  late Uint8List validFacePng;

  setUpAll(() {
    preprocessService = PreprocessService.defaultConfig();
    sampleExtractor = MlFaceSampleExtractor(
      ovalValidator: DefaultFaceOvalValidator(
        preprocessService: preprocessService,
      ),
      embeddingService: _FakeEmbeddingService(),
    );
    validFacePng = File('test/golden/sample_0.png').readAsBytesSync();
  });

  group('M6 (T-301) — AttendanceCaptureCubit & UseCases (Check-In / Check-Out & Error States)', () {
    late _FakeTodayRepo todayRepo;
    late _FakeLocationProvider locationProvider;
    late _FakeActionRepository actionRepo;
    late AttendanceCaptureCubit cubit;

    setUp(() {
      todayRepo = _FakeTodayRepo();
      locationProvider = _FakeLocationProvider();
      actionRepo = _FakeActionRepository();
      cubit = AttendanceCaptureCubit(
        getTodayAttendanceUseCase: GetTodayAttendanceUseCase(todayRepo),
        acquireLocationUseCase: AcquireAttendanceLocationUseCase(locationProvider),
        submitAttendanceUseCase: SubmitAttendanceUseCase(
          sampleExtractor: sampleExtractor,
          actionRepository: actionRepo,
        ),
        openLocationSettingsUseCase: OpenLocationSettingsUseCase(locationProvider),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('Alur Check-In sukses: ambil GPS + preview kantor terdekat -> embedding 128-d -> hasil hadir',
        () async {
      await cubit.prepareCapture(AttendanceMode.checkIn);
      expect(cubit.state, isA<AttendanceCaptureReady>());
      final ready = cubit.state as AttendanceCaptureReady;
      expect(ready.nearestOffice?.office.nama, equals('Kantor Pusat'));
      expect(ready.nearestOffice!.distanceMeters, closeTo(0.0, 1.0));

      await cubit.captureAndSubmit(photoBytes: validFacePng);
      expect(cubit.state, isA<AttendanceCaptureSuccess>());
      final success = (cubit.state as AttendanceCaptureSuccess).result;
      expect(success.mode, equals(AttendanceMode.checkIn));
      expect(success.status, equals('hadir'));
      expect(success.attendance.jamMasuk, equals('07:58:10'));
      expect(actionRepo.submitCallCount, equals(1));
      expect(actionRepo.lastEmbedding?.length, equals(128));
      expect(actionRepo.lastLiveness, isTrue);
    });

    test('Alur Check-Out sukses mengirim mode checkOut dan mencatat jam pulang server',
        () async {
      await cubit.prepareCapture(AttendanceMode.checkOut);
      await cubit.captureAndSubmit(photoBytes: validFacePng);

      expect(cubit.state, isA<AttendanceCaptureSuccess>());
      final success = (cubit.state as AttendanceCaptureSuccess).result;
      expect(success.mode, equals(AttendanceMode.checkOut));
      expect(actionRepo.lastMode, equals(AttendanceMode.checkOut));
      expect(success.attendance.jamPulang, equals('16:04:22'));
    });

    test('Klien TIDAK memblokir saat jarak jauh; server menolak OUT_OF_RADIUS tanpa retry otomatis',
        () async {
      // Posisi jauh dari kantor -> klien tetap mengizinkan kirim, server mengembalikan OUT_OF_RADIUS
      locationProvider.positionToReturn = const AttendanceGpsPosition(
        latitude: -6.4000,
        longitude: 108.4000,
      );
      actionRepo.failureToThrow = OutOfRadiusFailure(
        message: ErrorMessages.fromCode('OUT_OF_RADIUS'),
        distanceMeter: 284.6,
      );

      await cubit.prepareCapture(AttendanceMode.checkIn);
      expect(cubit.state, isA<AttendanceCaptureReady>());

      await cubit.captureAndSubmit(photoBytes: validFacePng);
      expect(cubit.state, isA<AttendanceCaptureRejected>());
      final rejected = cubit.state as AttendanceCaptureRejected;
      expect(rejected.failure, isA<OutOfRadiusFailure>());
      expect((rejected.failure as OutOfRadiusFailure).distanceMeter, closeTo(284.6, 1e-6));
      // Pastikan TIDAK ada retry otomatis
      expect(actionRepo.submitCallCount, equals(1));
    });

    test('Menangani seluruh kegagalan bisnis server & jaringan dengan pesan Indonesia yang tepat',
        () async {
      final failureCases = <Failure>[
        FaceMismatchFailure(
          message: ErrorMessages.fromCode('FACE_MISMATCH'),
          similarity: 0.1045,
        ),
        ServerFailure(
          code: 'ALREADY_CHECKED_IN',
          message: ErrorMessages.fromCode('ALREADY_CHECKED_IN'),
        ),
        ServerFailure(
          code: 'ALREADY_CHECKED_OUT',
          message: ErrorMessages.fromCode('ALREADY_CHECKED_OUT'),
        ),
        ServerFailure(
          code: 'HOLIDAY',
          message: ErrorMessages.fromCode('HOLIDAY'),
        ),
        const NetworkFailure(),
      ];

      for (final expectedFailure in failureCases) {
        actionRepo.failureToThrow = expectedFailure;
        await cubit.prepareCapture(AttendanceMode.checkIn);
        await cubit.captureAndSubmit(photoBytes: validFacePng);

        expect(cubit.state, isA<AttendanceCaptureRejected>());
        final rejected = cubit.state as AttendanceCaptureRejected;
        expect(rejected.failure.code, equals(expectedFailure.code));
        expect(rejected.failure.message, isNotEmpty);
      }
    });

    test('Menolak Mock GPS dan GPS mati pada tahap akuisisi lokasi', () async {
      locationProvider.failureToThrow = DeviceFailure(
        code: 'MOCK_LOCATION_DETECTED',
        message: ErrorMessages.fromCode('MOCK_LOCATION_DETECTED'),
      );
      await cubit.prepareCapture(AttendanceMode.checkIn);
      expect(cubit.state, isA<AttendanceCaptureLocationFailed>());
      expect((cubit.state as AttendanceCaptureLocationFailed).isMockGps, isTrue);

      locationProvider.failureToThrow = DeviceFailure(
        code: 'LOCATION_SERVICE_DISABLED',
        message: ErrorMessages.fromCode('LOCATION_SERVICE_DISABLED'),
      );
      await cubit.prepareCapture(AttendanceMode.checkIn);
      final gpsOffState = cubit.state as AttendanceCaptureLocationFailed;
      expect(gpsOffState.isGpsServiceDisabled, isTrue);

      await cubit.openGpsSettings();
      expect(locationProvider.openedSettings, isTrue);
    });

    test('Foto dinding polos (tanpa wajah di oval) memberi peringatan inline tanpa kehilangan titik GPS',
        () async {
      await cubit.prepareCapture(AttendanceMode.checkIn);
      await cubit.captureAndSubmit(photoBytes: _encodeBlankWallPng());

      expect(cubit.state, isA<AttendanceCaptureReady>());
      final ready = cubit.state as AttendanceCaptureReady;
      expect(ready.inlineWarning?.code, equals('FACE_NOT_IN_OVAL'));
      expect(actionRepo.submitCallCount, equals(0));
    });
  });

  group('M6 (T-301) — Widget Test Halaman Absensi & DI', () {
    testWidgets('AttendanceCapturePage menampilkan izin kontekstual -> kamera oval -> hasil sukses & penolakan',
        (tester) async {
      final todayRepo = _FakeTodayRepo();
      final locationProvider = _FakeLocationProvider();
      final actionRepo = _FakeActionRepository();
      final cubit = AttendanceCaptureCubit(
        getTodayAttendanceUseCase: GetTodayAttendanceUseCase(todayRepo),
        acquireLocationUseCase: AcquireAttendanceLocationUseCase(locationProvider),
        submitAttendanceUseCase: SubmitAttendanceUseCase(
          sampleExtractor: sampleExtractor,
          actionRepository: actionRepo,
        ),
        openLocationSettingsUseCase: OpenLocationSettingsUseCase(locationProvider),
      );

      final permService = _FakePermissionService(
        locationStatus: AppPermissionStatus.denied,
        cameraStatus: AppPermissionStatus.denied,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<AttendanceCaptureCubit>.value(
            value: cubit,
            child: AttendanceCapturePage(
              mode: AttendanceMode.checkIn,
              permissionService: permService,
              preprocessConfig: preprocessService.spec,
              cameraAdapter: _FakeCameraAdapter(captureBytes: validFacePng),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Izin lokasi kontekstual tampil lebih dulu
      expect(find.text('Izin Lokasi GPS Diperlukan'), findsOneWidget);
      await tester.tap(find.text('Lanjutkan & Izinkan'));
      await tester.pumpAndSettle();

      // 2. Izin kamera kontekstual tampil berikutnya
      expect(find.text('Izin Akses Kamera Diperlukan'), findsOneWidget);
      await tester.tap(find.text('Lanjutkan & Izinkan'));
      await tester.pumpAndSettle();

      // 3. Kartu GPS & tombol Konfirmasi Absen Masuk tampil
      expect(find.textContaining('Kantor Pusat'), findsOneWidget);
      expect(find.text('Konfirmasi Absen Masuk'), findsOneWidget);

      // 4. Uji skenario wajah tidak cocok terlebih dahulu -> tampil layar Ditolak beserta skor
      actionRepo.failureToThrow = FaceMismatchFailure(
        message: ErrorMessages.fromCode('FACE_MISMATCH'),
        similarity: 0.1123,
      );
      await tester.tap(find.text('Konfirmasi Absen Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Absen Masuk Ditolak'), findsOneWidget);
      expect(find.text('0.1123'), findsOneWidget);
      expect(find.text('Ambil Ulang Foto Wajah'), findsOneWidget);

      // 5. Pengguna menekan Ambil Ulang (manual) lalu berhasil Check-In
      actionRepo.failureToThrow = null;
      await tester.tap(find.text('Ambil Ulang Foto Wajah'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konfirmasi Absen Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Absen Masuk Berhasil'), findsOneWidget);
      expect(find.text('07:58:10'), findsOneWidget);
      expect(find.text('12.4 meter'), findsOneWidget);
      expect(find.text('0.8312'), findsOneWidget);

      await cubit.close();
    });

    test('DI initInjection mendaftarkan seluruh dependency M6', () async {
      await sl.reset();
      await initInjection();

      expect(sl.isRegistered<AttendanceActionRepository>(), isTrue);
      expect(sl.isRegistered<AttendanceLocationProvider>(), isTrue);
      expect(sl.isRegistered<AcquireAttendanceLocationUseCase>(), isTrue);
      expect(sl.isRegistered<SubmitAttendanceUseCase>(), isTrue);
      expect(sl.isRegistered<AttendanceCaptureCubit>(), isTrue);

      await sl.reset();
    });
  });
}
