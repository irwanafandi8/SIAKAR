import 'dart:typed_data';
import '../../../../core/error/error_messages.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/ml/liveness_service.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../face_enrollment/domain/repositories/face_enrollment_repository.dart';
import '../entities/attendance_entities.dart';
import '../repositories/attendance_repository.dart';

class GetTodayAttendanceUseCase {
  final AttendanceRepository repository;

  const GetTodayAttendanceUseCase(this.repository);

  Future<TodayAttendanceInfo> call() {
    return repository.getTodayInfo();
  }
}

class GetAttendanceHistoryUseCase {
  final AttendanceRepository repository;

  const GetAttendanceHistoryUseCase(this.repository);

  Future<AttendanceHistory> call({String? month}) {
    return repository.getHistory(month: month);
  }
}

/// Mengambil posisi GPS perangkat dan menghitung estimasi jarak terdekat ke kantor untuk tampilan UI.
/// Catatan: Klien TIDAK memblokir absensi berdasarkan jarak; keputusan resmi ada di server.
class AcquireAttendanceLocationUseCase {
  final AttendanceLocationProvider locationProvider;

  const AcquireAttendanceLocationUseCase(this.locationProvider);

  Future<AttendanceGpsPosition> call() {
    return locationProvider.getCurrentPosition();
  }

  NearestOfficePreview? computeNearestPreview(
    AttendanceGpsPosition position,
    List<OfficeLocation> offices,
  ) {
    if (offices.isEmpty) return null;

    OfficeLocation nearest = offices.first;
    double minDistance = GeoUtils.distanceInMeters(
      lat1: position.latitude,
      lon1: position.longitude,
      lat2: nearest.latitude,
      lon2: nearest.longitude,
    );

    for (int i = 1; i < offices.length; i++) {
      final candidate = offices[i];
      final dist = GeoUtils.distanceInMeters(
        lat1: position.latitude,
        lon1: position.longitude,
        lat2: candidate.latitude,
        lon2: candidate.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = candidate;
      }
    }

    return NearestOfficePreview(
      office: nearest,
      distanceMeters: minDistance,
    );
  }
}

/// Langkah 1 Liveness L1 (M8 / T-303):
/// Validasi wajah acuan di dalam oval memakai `DetectorService`, lalu bangkitkan tantangan aksi acak.
class StartLivenessChallengeUseCase {
  final FaceSampleExtractor sampleExtractor;
  final LivenessService livenessService;

  const StartLivenessChallengeUseCase({
    required this.sampleExtractor,
    required this.livenessService,
  });

  Future<LivenessChallengeSession> call({
    required Uint8List baselinePhotoBytes,
    LivenessChallengeType? forcedType,
  }) async {
    if (baselinePhotoBytes.isEmpty) {
      throw ValidationFailure(
        code: 'FACE_NOT_IN_OVAL',
        message: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
      );
    }

    final baselineBox =
        await sampleExtractor.detectFaceInOval(baselinePhotoBytes);
    return livenessService.createChallengeSession(
      baselineBox,
      forcedType: forcedType,
    );
  }
}

/// Langkah 2 Liveness L1 + Pengiriman Absensi (M6 + M8):
/// 1. Jalankan detektor wajah pada frame respons tantangan (tolak `FACE_NOT_IN_OVAL` sebelum embedding).
/// 2. Evaluasi tantangan Liveness L1 antar-frame (tolak `LIVENESS_FAILED` di klien sebelum embedding/API).
/// 3. Ekstrak embedding 128-d L2-normalized di perangkat.
/// 4. Kirim ke API B5 dengan `liveness_passed` murni dari hasil evaluasi Liveness L1.
class SubmitAttendanceUseCase {
  final FaceSampleExtractor sampleExtractor;
  final LivenessService livenessService;
  final AttendanceActionRepository actionRepository;

  const SubmitAttendanceUseCase({
    required this.sampleExtractor,
    required this.livenessService,
    required this.actionRepository,
  });

  Future<AttendanceSubmissionResult> call({
    required AttendanceMode mode,
    required AttendanceGpsPosition position,
    required LivenessChallengeSession livenessSession,
    required Uint8List challengePhotoBytes,
  }) async {
    if (challengePhotoBytes.isEmpty) {
      throw const ValidationFailure(
        code: 'FACE_NOT_IN_OVAL',
        message: 'Foto bukti kehadiran kosong atau gagal diambil.',
      );
    }

    // 1. Detektor TFLite wajib lolos terlebih dahulu sebelum liveness & sebelum embedding
    final challengeBox =
        await sampleExtractor.detectFaceInOval(challengePhotoBytes);

    // 2. Evaluasi Liveness L1 (perubahan posisi/skala bbox antar-frame)
    final livenessEval = livenessService.evaluate(
      session: livenessSession,
      challengeBox: challengeBox,
    );

    if (!livenessEval.passed) {
      throw ValidationFailure(
        code: 'LIVENESS_FAILED',
        message: livenessEval.reason,
      );
    }

    // 3. Ekstrak vektor embedding 128-d di perangkat
    final extracted = await sampleExtractor.extractSample(
      photoBytes: challengePhotoBytes,
      poseLabel: mode.title,
    );

    if (extracted.embedding.length != 128 ||
        extracted.embedding.any((v) => !v.isFinite)) {
      throw const ValidationFailure(
        code: 'INVALID_EMBEDDING',
        message:
            'Ekstraksi fitur wajah tidak menghasilkan vektor 128 dimensi yang valid.',
      );
    }

    // 4. Kirim ke server dengan nilai `livenessEval.passed` asli (bukan hardcoded)
    return actionRepository.submitAttendance(
      mode: mode,
      embedding: extracted.embedding,
      latitude: position.latitude,
      longitude: position.longitude,
      livenessPassed: livenessEval.passed,
      photoBytes: extracted.photoBytes,
    );
  }
}

class OpenLocationSettingsUseCase {
  final AttendanceLocationProvider locationProvider;

  const OpenLocationSettingsUseCase(this.locationProvider);

  Future<bool> call() {
    return locationProvider.openLocationSettings();
  }
}
