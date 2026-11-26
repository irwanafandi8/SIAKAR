import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siakar_mobile/app/di/injection.dart';
import 'package:siakar_mobile/core/error/failures.dart';
import 'package:siakar_mobile/core/ml/detector_service.dart';
import 'package:siakar_mobile/core/ml/embedding_service.dart';
import 'package:siakar_mobile/core/ml/face_oval_validator.dart';
import 'package:siakar_mobile/core/ml/liveness_service.dart';
import 'package:siakar_mobile/core/ml/preprocess.dart';
import 'package:siakar_mobile/features/attendance/domain/entities/attendance_entities.dart';
import 'package:siakar_mobile/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:siakar_mobile/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:siakar_mobile/features/attendance/presentation/cubit/attendance_capture_cubit.dart';
import 'package:siakar_mobile/features/attendance/presentation/cubit/attendance_capture_state.dart';
import 'package:siakar_mobile/features/face_enrollment/data/datasources/ml_face_sample_extractor.dart';
import 'package:siakar_mobile/features/face_enrollment/domain/entities/face_enrollment_entities.dart';
import 'package:siakar_mobile/features/face_enrollment/domain/repositories/face_enrollment_repository.dart';
import 'package:siakar_mobile/features/face_enrollment/domain/usecases/face_enrollment_usecases.dart';
import 'package:siakar_mobile/features/face_enrollment/presentation/cubit/face_enrollment_cubit.dart';
import 'package:siakar_mobile/features/face_enrollment/presentation/cubit/face_enrollment_state.dart';

class _ScriptedDetectorService implements DetectorService {
  final List<FaceDetectionBox> scriptedBoxes;
  int detectCalls = 0;

  _ScriptedDetectorService(this.scriptedBoxes);

  @override
  double get threshold => 0.52;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Float32List preprocessForDetector(img.Image rawImage) =>
      Float32List(1 * 64 * 64 * 3);

  @override
  Future<FaceDetectionBox> detect(img.Image rawImage) async {
    final box = scriptedBoxes[detectCalls % scriptedBoxes.length];
    detectCalls++;
    return box;
  }

  @override
  Future<FaceDetectionBox> detectFromBytes(Uint8List imageBytes) async {
    final decoded = img.decodeImage(imageBytes)!;
    return detect(decoded);
  }

  @override
  Future<FaceDetectionBox> runOnPreprocessedTensor(
    Float32List inputNHWC64,
  ) async {
    return scriptedBoxes.first;
  }

  @override
  void dispose() {}
}

class _SpyEmbeddingService implements EmbeddingService {
  int extractCalls = 0;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

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
  void dispose() {}
}

class _StubEnrollmentRepo implements FaceEnrollmentRepository {
  @override
  Future<FaceStatusEntity> getFaceStatus() async =>
      const FaceStatusEntity(enrolled: false);

  @override
  Future<FaceEnrollResult> enrollFace({
    required List<List<double>> embeddings,
    required Uint8List referencePhotoBytes,
    String referenceFileName = 'face_reference.jpg',
    required bool replace,
  }) async =>
      const FaceEnrollResult(enrolled: true);
}

class _StubTodayRepo implements AttendanceRepository {
  @override
  Future<TodayAttendanceInfo> getTodayInfo() async => const TodayAttendanceInfo(
        tanggal: '2026-11-26',
        hasSchedule: true,
        isHoliday: false,
        locations: [],
      );

  @override
  Future<AttendanceHistory> getHistory({String? month}) =>
      throw UnimplementedError();
}

class _StubLocationProvider implements AttendanceLocationProvider {
  @override
  Future<AttendanceGpsPosition> getCurrentPosition() async =>
      const AttendanceGpsPosition(latitude: -6.3277, longitude: 108.3200);

  @override
  Future<bool> openLocationSettings() async => true;
}

class _SpyActionRepo implements AttendanceActionRepository {
  int submitCalls = 0;
  bool? receivedLivenessPassed;

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
    submitCalls++;
    receivedLivenessPassed = livenessPassed;
    return AttendanceSubmissionResult(
      mode: mode,
      status: 'hadir',
      similarity: 0.85,
      distanceMeter: 10.0,
      attendance: const AttendanceRecord(
        idAbsensi: 1,
        tanggal: '2026-11-26',
        jamMasuk: '07:55:00',
        status: 'hadir',
      ),
    );
  }
}

void main() {
  late Map<String, dynamic> preprocessJson;
  late Map<String, dynamic> thresholdJson;
  late Map<String, dynamic> detectorGoldenJson;
  late PreprocessService preprocessService;

  setUpAll(() {
    final preprocessFile = File('assets/models/preprocess.json');
    final thresholdFile = File('assets/models/detector_threshold.json');
    final goldenFile = File('test/golden_detector/detector_golden.json');

    expect(preprocessFile.existsSync(), isTrue);
    expect(thresholdFile.existsSync(), isTrue);
    expect(goldenFile.existsSync(), isTrue);

    preprocessJson =
        jsonDecode(preprocessFile.readAsStringSync()) as Map<String, dynamic>;
    thresholdJson =
        jsonDecode(thresholdFile.readAsStringSync()) as Map<String, dynamic>;
    detectorGoldenJson =
        jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;
    preprocessService = PreprocessService(preprocessJson);
  });

  group('M8 (T-303) — Praproses Detektor 64x64, Parsing Output [1, 5], & Golden Check', () {
    test('detector_threshold.json & detector_golden.json sinkron (threshold = 0.52)', () {
      final assetThreshold = (thresholdJson['threshold'] as num).toDouble();
      final goldenThreshold =
          (detectorGoldenJson['threshold'] as num).toDouble();
      expect(assetThreshold, closeTo(0.52, 1e-6));
      expect(assetThreshold, closeTo(goldenThreshold, 1e-6));

      final detectorFile = File('assets/models/detector.tflite');
      expect(detectorFile.existsSync(), isTrue);
      expect(detectorFile.lengthSync(), greaterThan(100 * 1024));
    });

    test('praproses detektor menghasilkan tensor [1, 64, 64, 3] RGB [-1, 1] sesuai kontrak D-32', () {
      final detectorService = TfliteDetectorService.fromFiles(
        modelFile: File('assets/models/detector.tflite'),
        thresholdFile: File('assets/models/detector_threshold.json'),
        preprocessService: preprocessService,
      );
      expect(detectorService.threshold, closeTo(0.52, 1e-6));

      final samples = (detectorGoldenJson['samples'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(samples.length, equals(4));

      for (final sample in samples) {
        final imageName = sample['image_file'] as String;
        final decoded = img.decodeImage(
          File('test/golden_detector/$imageName').readAsBytesSync(),
        );
        expect(decoded, isNotNull);

        final tensor64 = detectorService.preprocessForDetector(decoded!);
        expect(tensor64.length, equals(1 * 64 * 64 * 3));

        // Identik secara numerik dengan PreprocessService.withInputSize(64)
        final direct64 = preprocessService.withInputSize(64).preprocess(decoded);
        for (int i = 0; i < tensor64.length; i++) {
          expect(tensor64[i], equals(direct64[i]));
          expect(tensor64[i], inInclusiveRange(-1.0, 1.0));
        }
      }
    });

    test('parsing output [face_score, cx, cy, w, h] cocok 100% dengan ekspektasi golden samples', () {
      final threshold = (thresholdJson['threshold'] as num).toDouble();
      final samples = (detectorGoldenJson['samples'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      for (final sample in samples) {
        final rawOut = (sample['tflite_output'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();
        final expectedHasFace = sample['predicted_has_face'] as bool;
        final expectedBbox = (sample['bbox_cxcywh'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();

        final box = FaceDetectionBox.fromRawOutput(
          rawOut,
          threshold: threshold,
        );

        expect(box.hasFace, equals(expectedHasFace), reason: sample['id'] as String);
        expect(box.isWellPositionedInOval, equals(expectedHasFace));
        expect(box.cx, closeTo(expectedBbox[0], 1e-6));
        expect(box.cy, closeTo(expectedBbox[1], 1e-6));
        expect(box.width, closeTo(expectedBbox[2], 1e-6));
        expect(box.height, closeTo(expectedBbox[3], 1e-6));
      }
    });

    test('inferensi TFLite detector.tflite pada 4 golden samples cocok dengan referensi Python', () async {
      final detectorService = TfliteDetectorService.fromFiles(
        modelFile: File('assets/models/detector.tflite'),
        thresholdFile: File('assets/models/detector_threshold.json'),
        preprocessService: preprocessService,
      );

      bool nativeAvailable = true;
      Object? initError;
      try {
        await detectorService.initialize();
      } catch (e) {
        nativeAvailable = false;
        initError = e;
      }

      if (!nativeAvailable) {
        markTestSkipped(
          'Interpreter TFLite native tidak tersedia di host ini ($initError). '
          'Praproses 64x64 & parsing golden detektor telah diverifikasi.',
        );
        return;
      }

      try {
        final samples = (detectorGoldenJson['samples'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        for (final sample in samples) {
          final imageName = sample['image_file'] as String;
          final refOut = (sample['tflite_output'] as List<dynamic>)
              .map((e) => (e as num).toDouble())
              .toList();
          final expectedHasFace = sample['predicted_has_face'] as bool;

          final bytes = File('test/golden_detector/$imageName').readAsBytesSync();
          final box = await detectorService.detectFromBytes(bytes);

          expect(box.hasFace, equals(expectedHasFace));
          expect(box.faceScore, closeTo(refOut[0], 5e-3));
          expect(box.cx, closeTo(refOut[1], 5e-3));
          expect(box.cy, closeTo(refOut[2], 5e-3));
          expect(box.width, closeTo(refOut[3], 5e-3));
          expect(box.height, closeTo(refOut[4], 5e-3));
        }
      } finally {
        detectorService.dispose();
      }
    });
  });

  group('M8 (T-303) — Integrasi Detektor ke M5 & Liveness L1 Challenge-Response ke M6', () {
    late Uint8List posCenteredBytes;
    late Uint8List posShiftedBytes;
    late Uint8List negGridBytes;

    const boxPosCentered = FaceDetectionBox(
      faceScore: 0.999936,
      cx: 0.497133,
      cy: 0.474258,
      width: 0.64916,
      height: 0.64633,
      threshold: 0.52,
    );
    const boxPosShifted = FaceDetectionBox(
      faceScore: 0.999986,
      cx: 0.512023,
      cy: 0.51135,
      width: 0.61158,
      height: 0.619516,
      threshold: 0.52,
    );
    const boxNegGrid = FaceDetectionBox(
      faceScore: 0.00016,
      cx: 0.524737,
      cy: 0.545411,
      width: 0.644184,
      height: 0.728145,
      threshold: 0.52,
    );

    setUpAll(() {
      posCenteredBytes =
          File('test/golden_detector/pos_centered.png').readAsBytesSync();
      posShiftedBytes =
          File('test/golden_detector/pos_shifted.png').readAsBytesSync();
      negGridBytes =
          File('test/golden_detector/neg_grid.png').readAsBytesSync();
    });

    test('M5 (Registrasi Wajah) menolak frame non-wajah lewat DetectorService SEBELUM menjalankan EmbeddingService',
        () async {
      final spyEmbedding = _SpyEmbeddingService();
      final detector = _ScriptedDetectorService([boxNegGrid]);
      final extractor = MlFaceSampleExtractor(
        ovalValidator: DefaultFaceOvalValidator(
          preprocessService: preprocessService,
          detectorService: detector,
        ),
        embeddingService: spyEmbedding,
      );

      final enrollmentCubit = FaceEnrollmentCubit(
        getStatusUseCase: GetFaceEnrollmentStatusUseCase(_StubEnrollmentRepo()),
        extractSampleUseCase: ExtractFaceSampleUseCase(extractor),
        submitEnrollmentUseCase:
            SubmitFaceEnrollmentUseCase(_StubEnrollmentRepo()),
      );

      await enrollmentCubit.loadInitialStatus();
      // Meskipun neg_grid memiliki kontras tinggi (lolos uji piksel dasar),
      // DetectorService menolak karena face_score = 0.00016 < 0.52!
      await enrollmentCubit.captureSample(photoBytes: negGridBytes);

      final state = enrollmentCubit.state as FaceEnrollmentCapturing;
      expect(state.samples, isEmpty);
      expect(state.feedbackError?.code, equals('FACE_NOT_IN_OVAL'));
      expect(detector.detectCalls, equals(1));
      expect(spyEmbedding.extractCalls, equals(0));

      await enrollmentCubit.close();
    });

    test('LivenessService L1 meluluskan perubahan posisi/skala nyata & menolak frame statis / lompatan ekstrem',
        () {
      final liveness = ChallengeResponseLivenessService();

      for (final type in LivenessChallengeType.values) {
        final session = liveness.createChallengeSession(
          boxPosCentered,
          forcedType: type,
        );

        // 1. Foto statis (tidak ada perubahan bbox) -> GAGAL
        final staticEval = liveness.evaluate(
          session: session,
          challengeBox: boxPosCentered,
        );
        expect(staticEval.passed, isFalse, reason: 'Statis wajib gagal untuk $type');

        // 2. Pergeseran nyata (pos_centered -> pos_shifted) -> LULUS
        final movedEval = liveness.evaluate(
          session: session,
          challengeBox: boxPosShifted,
        );
        expect(movedEval.passed, isTrue, reason: 'Gerakan valid wajib lulus untuk $type');
      }

      // 3. Lompatan ekstrem tidak masuk akal -> GAGAL
      final session = liveness.createChallengeSession(
        boxPosCentered,
        forcedType: LivenessChallengeType.shiftHorizontal,
      );
      const extremeJumpBox = FaceDetectionBox(
        faceScore: 0.95,
        cx: 0.87,
        cy: 0.87,
        width: 0.20,
        height: 0.20,
        threshold: 0.52,
      );
      final jumpEval = liveness.evaluate(
        session: session,
        challengeBox: extremeJumpBox,
      );
      expect(jumpEval.passed, isFalse);
    });

    test('M6 + M8 End-to-End: Liveness gagal menolak absensi di klien (tanpa embedding/API); Liveness lulus mengirim liveness_passed=true',
        () async {
      final spyEmbedding = _SpyEmbeddingService();
      final spyActionRepo = _SpyActionRepo();
      final liveness = ChallengeResponseLivenessService();

      // Skenario A: Frame 1 & Frame 2 statis (boxPosCentered -> boxPosCentered) -> LIVENESS_FAILED di klien
      final staticDetector =
          _ScriptedDetectorService([boxPosCentered, boxPosCentered]);
      final staticExtractor = MlFaceSampleExtractor(
        ovalValidator: DefaultFaceOvalValidator(
          preprocessService: preprocessService,
          detectorService: staticDetector,
        ),
        embeddingService: spyEmbedding,
      );

      final failCubit = AttendanceCaptureCubit(
        getTodayAttendanceUseCase: GetTodayAttendanceUseCase(_StubTodayRepo()),
        acquireLocationUseCase:
            AcquireAttendanceLocationUseCase(_StubLocationProvider()),
        startLivenessChallengeUseCase: StartLivenessChallengeUseCase(
          sampleExtractor: staticExtractor,
          livenessService: liveness,
        ),
        submitAttendanceUseCase: SubmitAttendanceUseCase(
          sampleExtractor: staticExtractor,
          livenessService: liveness,
          actionRepository: spyActionRepo,
        ),
        openLocationSettingsUseCase:
            OpenLocationSettingsUseCase(_StubLocationProvider()),
      );

      await failCubit.prepareCapture(AttendanceMode.checkIn);
      await failCubit.startLivenessChallenge(
        baselinePhotoBytes: posCenteredBytes,
        forcedType: LivenessChallengeType.shiftHorizontal,
      );
      await failCubit.completeChallengeAndSubmit(
        challengePhotoBytes: posShiftedBytes,
      );

      expect(failCubit.state, isA<AttendanceCaptureRejected>());
      final rejected = failCubit.state as AttendanceCaptureRejected;
      expect(rejected.failure, isA<ValidationFailure>());
      expect(rejected.failure.code, equals('LIVENESS_FAILED'));
      expect(spyEmbedding.extractCalls, equals(0));
      expect(spyActionRepo.submitCalls, equals(0));
      await failCubit.close();

      // Skenario B: Frame 1 -> Frame 2 bergerak sesuai tantangan -> LULUS & kirim liveness_passed=true
      final liveDetector =
          _ScriptedDetectorService([boxPosCentered, boxPosShifted]);
      final liveExtractor = MlFaceSampleExtractor(
        ovalValidator: DefaultFaceOvalValidator(
          preprocessService: preprocessService,
          detectorService: liveDetector,
        ),
        embeddingService: spyEmbedding,
      );

      final passCubit = AttendanceCaptureCubit(
        getTodayAttendanceUseCase: GetTodayAttendanceUseCase(_StubTodayRepo()),
        acquireLocationUseCase:
            AcquireAttendanceLocationUseCase(_StubLocationProvider()),
        startLivenessChallengeUseCase: StartLivenessChallengeUseCase(
          sampleExtractor: liveExtractor,
          livenessService: liveness,
        ),
        submitAttendanceUseCase: SubmitAttendanceUseCase(
          sampleExtractor: liveExtractor,
          livenessService: liveness,
          actionRepository: spyActionRepo,
        ),
        openLocationSettingsUseCase:
            OpenLocationSettingsUseCase(_StubLocationProvider()),
      );

      await passCubit.prepareCapture(AttendanceMode.checkIn);
      await passCubit.startLivenessChallenge(
        baselinePhotoBytes: posCenteredBytes,
        forcedType: LivenessChallengeType.shiftHorizontal,
      );
      await passCubit.completeChallengeAndSubmit(
        challengePhotoBytes: posShiftedBytes,
      );

      expect(passCubit.state, isA<AttendanceCaptureSuccess>());
      expect(spyEmbedding.extractCalls, equals(1));
      expect(spyActionRepo.submitCalls, equals(1));
      expect(spyActionRepo.receivedLivenessPassed, isTrue);
      await passCubit.close();
    });

    test('DI initInjection mendaftarkan DetectorService, LivenessService, dan StartLivenessChallengeUseCase',
        () async {
      await sl.reset();
      await initInjection();

      expect(sl.isRegistered<DetectorService>(), isTrue);
      expect(sl.isRegistered<LivenessService>(), isTrue);
      expect(sl.isRegistered<StartLivenessChallengeUseCase>(), isTrue);

      await sl.reset();
    });
  });
}
