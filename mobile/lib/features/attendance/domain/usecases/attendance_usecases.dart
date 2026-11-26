import 'dart:typed_data';
import '../../../../core/error/failures.dart';
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

/// Validasi wajah di dalam oval -> ekstrak embedding 128-d di perangkat -> kirim ke API B5.
class SubmitAttendanceUseCase {
  final FaceSampleExtractor sampleExtractor;
  final AttendanceActionRepository actionRepository;

  const SubmitAttendanceUseCase({
    required this.sampleExtractor,
    required this.actionRepository,
  });

  Future<AttendanceSubmissionResult> call({
    required AttendanceMode mode,
    required AttendanceGpsPosition position,
    required Uint8List photoBytes,
    bool livenessPassed = true,
  }) async {
    if (photoBytes.isEmpty) {
      throw const ValidationFailure(
        code: 'FACE_NOT_IN_OVAL',
        message: 'Foto bukti kehadiran kosong atau gagal diambil.',
      );
    }

    final extracted = await sampleExtractor.extractSample(
      photoBytes: photoBytes,
      poseLabel: mode.title,
    );

    if (extracted.embedding.length != 128 ||
        extracted.embedding.any((v) => !v.isFinite)) {
      throw const ValidationFailure(
        code: 'INVALID_EMBEDDING',
        message: 'Ekstraksi fitur wajah tidak menghasilkan vektor 128 dimensi yang valid.',
      );
    }

    return actionRepository.submitAttendance(
      mode: mode,
      embedding: extracted.embedding,
      latitude: position.latitude,
      longitude: position.longitude,
      livenessPassed: livenessPassed,
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
