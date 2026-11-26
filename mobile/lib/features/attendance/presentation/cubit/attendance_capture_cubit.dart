import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/ml/liveness_service.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/usecases/attendance_usecases.dart';
import 'attendance_capture_state.dart';

class AttendanceCaptureCubit extends Cubit<AttendanceCaptureState> {
  static const Set<String> _inlineFrameErrorCodes = {
    'FACE_NOT_IN_OVAL',
    'LIGHTING_TOO_DARK',
    'LIGHTING_TOO_BRIGHT',
  };

  final GetTodayAttendanceUseCase getTodayAttendanceUseCase;
  final AcquireAttendanceLocationUseCase acquireLocationUseCase;
  final StartLivenessChallengeUseCase startLivenessChallengeUseCase;
  final SubmitAttendanceUseCase submitAttendanceUseCase;
  final OpenLocationSettingsUseCase openLocationSettingsUseCase;

  AttendanceCaptureCubit({
    required this.getTodayAttendanceUseCase,
    required this.acquireLocationUseCase,
    required this.startLivenessChallengeUseCase,
    required this.submitAttendanceUseCase,
    required this.openLocationSettingsUseCase,
    AttendanceMode initialMode = AttendanceMode.checkIn,
  }) : super(AttendanceCaptureInitial(mode: initialMode));

  /// Ambil koordinat GPS perangkat dan muat informasi lokasi kantor (untuk tampilan jarak saja).
  Future<void> prepareCapture([AttendanceMode? overrideMode]) async {
    final activeMode = overrideMode ?? state.mode;
    emit(AttendanceCaptureLocating(mode: activeMode));

    List<OfficeLocation> offices = const [];
    try {
      final todayInfo = await getTodayAttendanceUseCase();
      offices = todayInfo.locations;
    } catch (_) {
      // Kegagalan memuat pratinjau kantor tidak menghalangi pengiriman absensi;
      // server tetap menjadi otoritas penuh validasi geofence.
    }

    try {
      final gpsPos = await acquireLocationUseCase();
      final nearest = acquireLocationUseCase.computeNearestPreview(
        gpsPos,
        offices,
      );

      emit(
        AttendanceCaptureReady(
          mode: activeMode,
          position: gpsPos,
          offices: offices,
          nearestOffice: nearest,
        ),
      );
    } on Failure catch (f) {
      emit(AttendanceCaptureLocationFailed(mode: activeMode, failure: f));
    } catch (_) {
      emit(
        AttendanceCaptureLocationFailed(
          mode: activeMode,
          failure: const DeviceFailure(
            code: 'LOCATION_ERROR',
            message:
                'Gagal mendapatkan lokasi GPS perangkat. Pastikan GPS aktif.',
          ),
        ),
      );
    }
  }

  /// Buka halaman pengaturan lokasi/GPS perangkat.
  Future<void> openGpsSettings() async {
    await openLocationSettingsUseCase();
  }

  /// Langkah 1/2: Ambil frame wajah acuan di dalam oval -> bangkitkan tantangan Liveness L1 acak.
  Future<void> startLivenessChallenge({
    required Uint8List baselinePhotoBytes,
    LivenessChallengeType? forcedType,
  }) async {
    final current = state;
    if (current is! AttendanceCaptureReady || current.isProcessing) {
      return;
    }

    emit(
      current.copyWith(
        isProcessing: true,
        clearInlineWarning: true,
      ),
    );

    try {
      final session = await startLivenessChallengeUseCase(
        baselinePhotoBytes: baselinePhotoBytes,
        forcedType: forcedType,
      );

      emit(
        current.copyWith(
          livenessSession: session,
          isProcessing: false,
          clearInlineWarning: true,
        ),
      );
    } on Failure catch (f) {
      emit(
        current.copyWith(
          isProcessing: false,
          inlineWarning: f,
        ),
      );
    } catch (_) {
      emit(
        current.copyWith(
          isProcessing: false,
          inlineWarning: const ValidationFailure(
            code: 'FACE_NOT_IN_OVAL',
            message:
                'Gagal mendeteksi wajah pada bingkai oval. Pastikan wajah terlihat jelas.',
          ),
        ),
      );
    }
  }

  /// Ulangi tantangan Liveness L1 dari langkah 1.
  void resetLivenessChallenge() {
    final current = state;
    if (current is AttendanceCaptureReady && !current.isProcessing) {
      emit(
        current.copyWith(
          clearLivenessSession: true,
          clearInlineWarning: true,
        ),
      );
    }
  }

  /// Langkah 2/2: Evaluasi tantangan Liveness L1 -> ekstrak embedding TFLite -> kirim ke API B5.
  /// Menolak di klien bila detektor atau liveness gagal, tanpa retry otomatis.
  Future<void> completeChallengeAndSubmit({
    required Uint8List challengePhotoBytes,
  }) async {
    final current = state;
    if (current is! AttendanceCaptureReady ||
        current.isProcessing ||
        current.livenessSession == null) {
      return;
    }

    emit(
      current.copyWith(
        isProcessing: true,
        clearInlineWarning: true,
      ),
    );

    try {
      final result = await submitAttendanceUseCase(
        mode: current.mode,
        position: current.position,
        livenessSession: current.livenessSession!,
        challengePhotoBytes: challengePhotoBytes,
      );

      emit(AttendanceCaptureSuccess(result: result));
    } on Failure catch (f) {
      if (_inlineFrameErrorCodes.contains(f.code)) {
        emit(
          current.copyWith(
            isProcessing: false,
            inlineWarning: f,
          ),
        );
        return;
      }

      emit(
        AttendanceCaptureRejected(
          mode: current.mode,
          failure: f,
          lastPosition: current.position,
          offices: current.offices,
          nearestOffice: current.nearestOffice,
        ),
      );
    } catch (_) {
      emit(
        AttendanceCaptureRejected(
          mode: current.mode,
          failure: const ServerFailure(
            code: 'SERVER_ERROR',
            message:
                'Terjadi kesalahan saat memproses absensi. Silakan coba lagi.',
          ),
          lastPosition: current.position,
          offices: current.offices,
          nearestOffice: current.nearestOffice,
        ),
      );
    }
  }

  /// Penanganan satu pintu dari tombol kamera sesuai tahap aktif (Langkah 1 vs Langkah 2).
  Future<void> onCameraFrameCaptured(Uint8List photoBytes) async {
    final current = state;
    if (current is! AttendanceCaptureReady || current.isProcessing) {
      return;
    }
    if (!current.hasBaselineChallenge) {
      await startLivenessChallenge(baselinePhotoBytes: photoBytes);
    } else {
      await completeChallengeAndSubmit(challengePhotoBytes: photoBytes);
    }
  }

  /// Kembali ke tampilan kamera dengan sesi tantangan Liveness L1 baru (aksi eksplisit pengguna).
  void returnToCamera() {
    final current = state;
    if (current is AttendanceCaptureRejected) {
      emit(
        AttendanceCaptureReady(
          mode: current.mode,
          position: current.lastPosition,
          offices: current.offices,
          nearestOffice: current.nearestOffice,
        ),
      );
    }
  }
}
