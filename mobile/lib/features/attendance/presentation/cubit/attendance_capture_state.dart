import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/ml/liveness_service.dart';
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

/// GPS telah siap; menampilkan kamera + oval panduan + tahapan Liveness L1.
class AttendanceCaptureReady extends AttendanceCaptureState {
  final AttendanceGpsPosition position;
  final List<OfficeLocation> offices;
  final NearestOfficePreview? nearestOffice;
  final LivenessChallengeSession? livenessSession;
  final bool isProcessing;
  final Failure? inlineWarning;

  const AttendanceCaptureReady({
    required super.mode,
    required this.position,
    this.offices = const [],
    this.nearestOffice,
    this.livenessSession,
    this.isProcessing = false,
    this.inlineWarning,
  });

  bool get hasBaselineChallenge => livenessSession != null;

  AttendanceCaptureReady copyWith({
    AttendanceGpsPosition? position,
    List<OfficeLocation>? offices,
    NearestOfficePreview? nearestOffice,
    LivenessChallengeSession? livenessSession,
    bool clearLivenessSession = false,
    bool? isProcessing,
    Failure? inlineWarning,
    bool clearInlineWarning = false,
  }) {
    return AttendanceCaptureReady(
      mode: mode,
      position: position ?? this.position,
      offices: offices ?? this.offices,
      nearestOffice: nearestOffice ?? this.nearestOffice,
      livenessSession: clearLivenessSession
          ? null
          : (livenessSession ?? this.livenessSession),
      isProcessing: isProcessing ?? this.isProcessing,
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
        livenessSession,
        isProcessing,
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

/// Penolakan liveness L1 di klien, penolakan bisnis server, atau kegagalan jaringan.
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
