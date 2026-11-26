import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siakar_mobile/app/di/injection.dart';
import 'package:siakar_mobile/core/device/location_service.dart';
import 'package:siakar_mobile/core/device/permission_service.dart';
import 'package:siakar_mobile/core/error/failures.dart';
import 'package:siakar_mobile/core/ml/embedding_service.dart';
import 'package:siakar_mobile/core/ml/face_oval_validator.dart';
import 'package:siakar_mobile/core/ml/preprocess.dart';
import 'package:siakar_mobile/core/utils/geo_utils.dart';
import 'package:siakar_mobile/design/app_theme.dart';
import 'package:siakar_mobile/design/widgets/contextual_permission_view.dart';
import 'package:siakar_mobile/design/widgets/face_oval_camera_view.dart';
import 'package:siakar_mobile/features/face_enrollment/data/datasources/ml_face_sample_extractor.dart';
import 'package:siakar_mobile/features/face_enrollment/domain/entities/face_enrollment_entities.dart';
import 'package:siakar_mobile/features/face_enrollment/domain/repositories/face_enrollment_repository.dart';
import 'package:siakar_mobile/features/face_enrollment/domain/usecases/face_enrollment_usecases.dart';
import 'package:siakar_mobile/features/face_enrollment/presentation/cubit/face_enrollment_cubit.dart';
import 'package:siakar_mobile/features/face_enrollment/presentation/cubit/face_enrollment_state.dart';
import 'package:siakar_mobile/features/face_enrollment/presentation/pages/face_enrollment_page.dart';

class FakePermissionService implements DevicePermissionService {
  AppPermissionStatus cameraStatus;
  AppPermissionStatus nextRequestCameraStatus;
  AppPermissionStatus locationStatus;
  AppPermissionStatus nextRequestLocationStatus;
  bool openedSettings = false;

  FakePermissionService({
    this.cameraStatus = AppPermissionStatus.denied,
    this.nextRequestCameraStatus = AppPermissionStatus.granted,
    this.locationStatus = AppPermissionStatus.denied,
    this.nextRequestLocationStatus = AppPermissionStatus.granted,
  });

  @override
  Future<AppPermissionStatus> checkCameraPermission() async => cameraStatus;

  @override
  Future<AppPermissionStatus> requestCameraPermission() async {
    cameraStatus = nextRequestCameraStatus;
    return cameraStatus;
  }

  @override
  Future<AppPermissionStatus> checkLocationPermission() async => locationStatus;

  @override
  Future<AppPermissionStatus> requestLocationPermission() async {
    locationStatus = nextRequestLocationStatus;
    return locationStatus;
  }

  @override
  Future<bool> openSystemAppSettings() async {
    openedSettings = true;
    return true;
  }
}

class FakeEmbeddingService implements EmbeddingService {
  bool initialized = false;
  int extractCalls = 0;

  @override
  bool get isInitialized => initialized;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<List<double>> extractEmbedding(img.Image rawImage) async {
    extractCalls++;
    final vec = List<double>.filled(128, 0.0);
    vec[0] = 1.0;
    return vec;
  }

  @override
  Future<List<double>> extractEmbeddingFromBytes(Uint8List imageBytes) async {
    extractCalls++;
    final vec = List<double>.filled(128, 0.0);
    vec[0] = 1.0;
    return vec;
  }

  @override
  Future<List<double>> runOnPreprocessedTensor(Float32List inputNHWC) async {
    final vec = List<double>.filled(128, 0.0);
    vec[0] = 1.0;
    return vec;
  }

  @override
  void dispose() {
    initialized = false;
  }
}

class FakeFaceEnrollmentRepository implements FaceEnrollmentRepository {
  bool initiallyEnrolled = false;
  String? enrolledAt;
  bool shouldFailStatus = false;
  bool shouldFailEnroll = false;

  List<List<double>>? submittedEmbeddings;
  Uint8List? submittedPhoto;
  bool? submittedReplace;

  @override
  Future<FaceStatusEntity> getFaceStatus() async {
    if (shouldFailStatus) {
      throw const NetworkFailure();
    }
    return FaceStatusEntity(enrolled: initiallyEnrolled, enrolledAt: enrolledAt);
  }

  @override
  Future<FaceEnrollResult> enrollFace({
    required List<List<double>> embeddings,
    required Uint8List referencePhotoBytes,
    String referenceFileName = 'face_reference.jpg',
    required bool replace,
  }) async {
    if (shouldFailEnroll) {
      throw const ServerFailure(
        message: 'Wajah sudah terdaftar.',
        code: 'FACE_ALREADY_ENROLLED',
      );
    }
    submittedEmbeddings = embeddings;
    submittedPhoto = referencePhotoBytes;
    submittedReplace = replace;
    return const FaceEnrollResult(enrolled: true);
  }
}

class FakeCameraAdapter implements FaceCameraControllerAdapter {
  final Uint8List captureBytes;
  bool _initialized = false;

  FakeCameraAdapter({required this.captureBytes});

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Widget buildPreview() {
    return const ColoredBox(
      key: Key('fake_camera_preview'),
      color: Colors.black87,
    );
  }

  @override
  Future<CapturedPhotoData> takePicture() async {
    return CapturedPhotoData(bytes: captureBytes, filePath: 'fake_capture.png');
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}

Uint8List _encodeSolidPng(int w, int h, int r, int g, int b) {
  final image = img.Image(width: w, height: h, numChannels: 3);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late PreprocessService preprocessService;
  late DefaultFaceOvalValidator ovalValidator;
  late Uint8List validFacePngBytes;

  setUpAll(() {
    preprocessService = PreprocessService.defaultConfig();
    ovalValidator = DefaultFaceOvalValidator(
      preprocessService: preprocessService,
    );
    validFacePngBytes = File('test/golden/sample_0.png').readAsBytesSync();
  });

  group('M4 (T-222) — Izin Kontekstual, GeoUtils, & Validasi Oval', () {
    test('GeoUtils menghitung jarak Haversine dengan akurat', () {
      expect(
        GeoUtils.distanceInMeters(
          lat1: -6.3277,
          lon1: 108.3200,
          lat2: -6.3277,
          lon2: 108.3200,
        ),
        closeTo(0.0, 1e-6),
      );

      final d = GeoUtils.distanceInMeters(
        lat1: -6.3277,
        lon1: 108.3200,
        lat2: -6.3267,
        lon2: 108.3200,
      );
      // Selisih 0.001 derajat lintang ≈ 111.2 meter
      expect(d, inInclusiveRange(108.0, 115.0));
    });

    test('DefaultFaceOvalValidator menolak gambar gelap, silau, atau polos tanpa wajah, dan menerima wajah valid', () {
      final darkBytes = _encodeSolidPng(128, 160, 5, 5, 5);
      final darkRes = ovalValidator.validateBytes(darkBytes);
      expect(darkRes.isValid, isFalse);
      expect(darkRes.errorCode, equals('LIGHTING_TOO_DARK'));

      final brightBytes = _encodeSolidPng(128, 160, 250, 250, 250);
      final brightRes = ovalValidator.validateBytes(brightBytes);
      expect(brightRes.isValid, isFalse);
      expect(brightRes.errorCode, equals('LIGHTING_TOO_BRIGHT'));

      final flatWallBytes = _encodeSolidPng(128, 160, 128, 128, 128);
      final flatRes = ovalValidator.validateBytes(flatWallBytes);
      expect(flatRes.isValid, isFalse);
      expect(flatRes.errorCode, equals('FACE_NOT_IN_OVAL'));

      final validRes = ovalValidator.validateBytes(validFacePngBytes);
      expect(validRes.isValid, isTrue);
    });

    testWidgets('ContextualPermissionGate menampilkan penjelasan kontekstual, ditolak, dan permanen ke Pengaturan',
        (tester) async {
      final permService = FakePermissionService(
        cameraStatus: AppPermissionStatus.denied,
        nextRequestCameraStatus: AppPermissionStatus.denied,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ContextualPermissionGate(
              permissionType: ContextualPermissionType.camera,
              permissionService: permService,
              child: const Text('Kamera Aktif'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tampil penjelasan kontekstual sebelum meminta izin
      expect(find.text('Izin Akses Kamera Diperlukan'), findsOneWidget);
      expect(find.text('Lanjutkan & Izinkan'), findsOneWidget);

      // 2. Pengguna menekan tombol tetapi menolak dialog OS -> tampil state ditolak
      await tester.tap(find.text('Lanjutkan & Izinkan'));
      await tester.pumpAndSettle();
      expect(find.text('Izin Kamera Ditolak'), findsOneWidget);
      expect(find.text('Minta Izin Kembali'), findsOneWidget);

      // 3. Jika berubah menjadi permanentlyDenied -> arahkan ke Pengaturan Aplikasi
      permService.nextRequestCameraStatus =
          AppPermissionStatus.permanentlyDenied;
      await tester.tap(find.text('Minta Izin Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Akses Kamera Diblokir Permanen'), findsOneWidget);
      expect(find.text('Buka Pengaturan Aplikasi'), findsOneWidget);

      await tester.tap(find.text('Buka Pengaturan Aplikasi'));
      await tester.pump();
      expect(permService.openedSettings, isTrue);
    });
  });

  group('M5 (T-223) — UseCases & FaceEnrollmentCubit', () {
    late FakeFaceEnrollmentRepository fakeRepo;
    late FakeEmbeddingService fakeEmbedding;
    late MlFaceSampleExtractor sampleExtractor;
    late FaceEnrollmentCubit cubit;

    setUp(() {
      fakeRepo = FakeFaceEnrollmentRepository();
      fakeEmbedding = FakeEmbeddingService();
      sampleExtractor = MlFaceSampleExtractor(
        ovalValidator: ovalValidator,
        embeddingService: fakeEmbedding,
      );
      cubit = FaceEnrollmentCubit(
        getStatusUseCase: GetFaceEnrollmentStatusUseCase(fakeRepo),
        extractSampleUseCase: ExtractFaceSampleUseCase(sampleExtractor),
        submitEnrollmentUseCase: SubmitFaceEnrollmentUseCase(fakeRepo),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('SubmitFaceEnrollmentUseCase menolak kurang dari 3 sampel', () async {
      final submitUseCase = SubmitFaceEnrollmentUseCase(fakeRepo);
      final sample = await ExtractFaceSampleUseCase(sampleExtractor).call(
        photoBytes: validFacePngBytes,
        poseLabel: 'Depan',
      );

      expect(
        () => submitUseCase(samples: [sample, sample], replace: false),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('FaceEnrollmentCubit: alur belum terdaftar -> tolak foto polos -> ambil 3 foto valid -> enroll sukses',
        () async {
      await cubit.loadInitialStatus();
      expect(cubit.state, isA<FaceEnrollmentCapturing>());
      expect((cubit.state as FaceEnrollmentCapturing).isReplace, isFalse);

      // Ambil 1 foto valid
      await cubit.captureSample(photoBytes: validFacePngBytes);
      expect((cubit.state as FaceEnrollmentCapturing).samples.length, equals(1));

      // Foto ke-2 tidak memuat wajah di oval (dinding polos) -> ditolak tanpa menghapus foto 1
      final blankWall = _encodeSolidPng(128, 160, 120, 120, 120);
      await cubit.captureSample(photoBytes: blankWall);
      final afterReject = cubit.state as FaceEnrollmentCapturing;
      expect(afterReject.samples.length, equals(1));
      expect(afterReject.feedbackError, isNotNull);
      expect(afterReject.feedbackError!.code, equals('FACE_NOT_IN_OVAL'));

      // Ambil foto ke-2 dan ke-3 yang valid -> canSubmit aktif
      await cubit.captureSample(photoBytes: validFacePngBytes);
      await cubit.captureSample(photoBytes: validFacePngBytes);
      final readyState = cubit.state as FaceEnrollmentCapturing;
      expect(readyState.samples.length, equals(3));
      expect(readyState.canSubmit, isTrue);

      // Kirim ke server
      await cubit.submitEnrollment();
      expect(cubit.state, isA<FaceEnrollmentSuccess>());
      expect(fakeRepo.submittedEmbeddings?.length, equals(3));
      expect(fakeRepo.submittedReplace, isFalse);
      expect(fakeEmbedding.extractCalls, equals(3));
    });

    test('FaceEnrollmentCubit: jika sudah terdaftar menampilkan opsi Perbarui (replace=true)',
        () async {
      fakeRepo.initiallyEnrolled = true;
      fakeRepo.enrolledAt = '2026-11-25T08:30:00+07:00';

      await cubit.loadInitialStatus();
      expect(cubit.state, isA<FaceEnrollmentAlreadyRegistered>());

      cubit.startReplaceFlow();
      expect(cubit.state, isA<FaceEnrollmentCapturing>());
      expect((cubit.state as FaceEnrollmentCapturing).isReplace, isTrue);

      await cubit.captureSample(photoBytes: validFacePngBytes);
      await cubit.captureSample(photoBytes: validFacePngBytes);
      await cubit.captureSample(photoBytes: validFacePngBytes);
      await cubit.submitEnrollment();

      expect(cubit.state, isA<FaceEnrollmentSuccess>());
      expect((cubit.state as FaceEnrollmentSuccess).wasReplace, isTrue);
      expect(fakeRepo.submittedReplace, isTrue);
    });

    testWidgets('FaceEnrollmentPage end-to-end UI: izin kamera -> ambil 3 foto di oval -> simpan sukses',
        (tester) async {
      final permService = FakePermissionService(
        cameraStatus: AppPermissionStatus.denied,
        nextRequestCameraStatus: AppPermissionStatus.granted,
      );
      final fakeCamera = FakeCameraAdapter(captureBytes: validFacePngBytes);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<FaceEnrollmentCubit>.value(
            value: cubit,
            child: FaceEnrollmentPage(
              permissionService: permService,
              preprocessConfig: preprocessService.spec,
              cameraAdapter: fakeCamera,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Layar izin kontekstual tampil lebih dulu
      expect(find.text('Izin Akses Kamera Diperlukan'), findsOneWidget);
      await tester.tap(find.text('Lanjutkan & Izinkan'));
      await tester.pumpAndSettle();

      // 2. Kamera depan + oval tampil
      expect(find.byKey(const Key('fake_camera_preview')), findsOneWidget);
      expect(find.text('Ambil Foto (1/3 Wajib)'), findsOneWidget);

      // 3. Ambil 3 foto berurutan
      await tester.tap(find.text('Ambil Foto (1/3 Wajib)'));
      await tester.pumpAndSettle();
      expect(find.text('Ambil Foto (2/3 Wajib)'), findsOneWidget);

      await tester.tap(find.text('Ambil Foto (2/3 Wajib)'));
      await tester.pumpAndSettle();
      expect(find.text('Ambil Foto (3/3 Wajib)'), findsOneWidget);

      await tester.tap(find.text('Ambil Foto (3/3 Wajib)'));
      await tester.pumpAndSettle();

      // 4. Tombol Simpan Wajah aktif setelah 3 foto valid
      expect(find.text('Simpan Wajah (3 Foto)'), findsOneWidget);
      await tester.tap(find.text('Simpan Wajah (3 Foto)'));
      await tester.pumpAndSettle();

      // 5. Konfirmasi sukses tampil
      expect(find.text('Registrasi Wajah Berhasil'), findsOneWidget);
    });

    test('DI initInjection mendaftarkan seluruh layanan M4 & M5', () async {
      await sl.reset();
      await initInjection();

      expect(sl.isRegistered<DevicePermissionService>(), isTrue);
      expect(sl.isRegistered<LocationService>(), isTrue);
      expect(sl.isRegistered<FaceInOvalValidator>(), isTrue);
      expect(sl.isRegistered<FaceEnrollmentRepository>(), isTrue);
      expect(sl.isRegistered<FaceEnrollmentCubit>(), isTrue);

      await sl.reset();
    });
  });
}
