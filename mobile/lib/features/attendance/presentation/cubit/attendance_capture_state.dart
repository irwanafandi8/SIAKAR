import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/attendance_entities.dart';

abstract class AttendanceCaptureState extends Equatable {
  final AttendanceMode mode;

  const AttendanceCaptureState({required this.mode});

  @override
  List<Object?> get props => [mode];
}

class AttendanceCaptureInitial extends AttendanceCaptureState {
  const AttendanceCaptureInitial({super.mode = AttendanceMode.checkIn});
}

/// Sedang mengambil titik koordinat GPS & daftar lokasi kantor hari ini.
class AttendanceCaptureLocating extends AttendanceCaptureState {
  const AttendanceCaptureLocating({required super.mode});
}

/// Gagal memperoleh lokasi GPS (GPS mati, Mock GPS terdeteksi, sinyal gagal, atau izin ditolak).
class AttendanceCaptureLocationFailed extends AttendanceCaptureState {
  final Failure failure;

  const AttendanceCaptureLocationFailed({
    required super.mode,
    required this.failure,
  });

  bool get isGpsServiceDisabled => failure.code == 'LOCATION_SERVICE_DISABLED';
  bool get isMockGps => failure.code == 'MOCK_LOCATION_DETECTED';

  @override
  List<Object?> get props => [mode, failure];
}

/// GPS telah siap; menampilkan kamera + oval panduan untuk mengambil bukti wajah.
class AttendanceCaptureReady extends AttendanceCaptureState {
  final AttendanceGpsPosition position;
  final List<OfficeLocation> offices;
  final NearestOfficePreview? nearestOffice;
  final bool isSubmitting;
  final Failure? inlineWarning;

  const AttendanceCaptureReady({
    required super.mode,
    required this.position,
    this.offices = const [],
    this.nearestOffice,
    this.isSubmitting = false,
    this.inlineWarning,
  });

  AttendanceCaptureReady copyWith({
    AttendanceGpsPosition? position,
    List<OfficeLocation>? offices,
    NearestOfficePreview? nearestOffice,
    bool? isSubmitting,
    Failure? inlineWarning,
    bool clearInlineWarning = false,
  }) {
    return AttendanceCaptureReady(
      mode: mode,
      position: position ?? this.position,
      offices: offices ?? this.offices,
      nearestOffice: nearestOffice ?? this.nearestOffice,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      inlineWarning:
          clearInlineWarning ? null : (inlineWarning ?? this.inlineWarning),
    );
  }

  @override
  List<Object?> get props => [
        mode,
        position,
        offices,
        nearestOffice,
        isSubmitting,
        inlineWarning,
      ];
}

/// Absensi berhasil diverifikasi dan disimpan oleh server (201).
class AttendanceCaptureSuccess extends AttendanceCaptureState {
  final AttendanceSubmissionResult result;

  AttendanceCaptureSuccess({required this.result}) : super(mode: result.mode);

  @override
  List<Object?> get props => [mode, result];
}

/// Penolakan bisnis dari server atau kegagalan jaringan saat pengiriman absensi.
/// Klien menampilkan pesan Bahasa Indonesia yang sesuai tanpa retry otomatis.
class AttendanceCaptureRejected extends AttendanceCaptureState {
  final Failure failure;
  final AttendanceGpsPosition lastPosition;
  final List<OfficeLocation> offices;
  final NearestOfficePreview? nearestOffice;

  const AttendanceCaptureRejected({
    required super.mode,
    required this.failure,
    required this.lastPosition,
    this.offices = const [],
    this.nearestOffice,
  });

  @override
  List<Object?> get props => [
        mode,
        failure,
        lastPosition,
        offices,
        nearestOffice,
      ];
}
