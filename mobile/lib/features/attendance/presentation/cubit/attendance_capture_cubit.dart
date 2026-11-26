import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
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
  final SubmitAttendanceUseCase submitAttendanceUseCase;
  final OpenLocationSettingsUseCase openLocationSettingsUseCase;

  AttendanceCaptureCubit({
    required this.getTodayAttendanceUseCase,
    required this.acquireLocationUseCase,
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
      // Kegagalan memuat pratinjau kantor tidak boleh menghalangi pengiriman absensi;
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
            message: 'Gagal mendapatkan lokasi GPS perangkat. Pastikan GPS aktif.',
          ),
        ),
      );
    }
  }

  /// Buka halaman pengaturan lokasi/GPS perangkat.
  Future<void> openGpsSettings() async {
    await openLocationSettingsUseCase();
  }

  /// Proses tangkapan foto kamera -> validasi oval -> embedding TFLite -> kirim ke API B5.
  /// Tanpa mengirim waktu klien dan tanpa retry otomatis.
  Future<void> captureAndSubmit({
    required Uint8List photoBytes,
    bool livenessPassed = true,
  }) async {
    final current = state;
    if (current is! AttendanceCaptureReady || current.isSubmitting) {
      return;
    }

    emit(
      current.copyWith(
        isSubmitting: true,
        clearInlineWarning: true,
      ),
    );

    try {
      final result = await submitAttendanceUseCase(
        mode: current.mode,
        position: current.position,
        photoBytes: photoBytes,
        livenessPassed: livenessPassed,
      );

      emit(AttendanceCaptureSuccess(result: result));
    } on Failure catch (f) {
      if (_inlineFrameErrorCodes.contains(f.code)) {
        emit(
          current.copyWith(
            isSubmitting: false,
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
            message: 'Terjadi kesalahan saat memproses absensi. Silakan coba lagi.',
          ),
          lastPosition: current.position,
          offices: current.offices,
          nearestOffice: current.nearestOffice,
        ),
      );
    }
  }

  /// Kembali ke tampilan kamera menggunakan titik GPS terakhir (aksi eksplisit pengguna, bukan retry otomatis).
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
