import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/face_enrollment_entities.dart';

abstract class FaceEnrollmentState extends Equatable {
  const FaceEnrollmentState();

  @override
  List<Object?> get props => [];
}

class FaceEnrollmentInitial extends FaceEnrollmentState {
  const FaceEnrollmentInitial();
}

class FaceEnrollmentLoading extends FaceEnrollmentState {
  const FaceEnrollmentLoading();
}

/// Ditampilkan bila wajah karyawan sudah terdaftar di server; menyediakan opsi Perbarui.
class FaceEnrollmentAlreadyRegistered extends FaceEnrollmentState {
  final String? enrolledAt;

  const FaceEnrollmentAlreadyRegistered({this.enrolledAt});

  @override
  List<Object?> get props => [enrolledAt];
}

/// State aktif pengambilan 3–5 sampel wajah di kamera oval & pengiriman ke server.
class FaceEnrollmentCapturing extends FaceEnrollmentState {
  static const List<String> poseGuides = [
    'Foto 1/3: Posisikan wajah lurus ke depan di dalam bingkai',
    'Foto 2/3: Tolehkan wajah sedikit ke kiri',
    'Foto 3/3: Tolehkan wajah sedikit ke kanan',
    'Foto Opsional 4/5: Angkat dagu sedikit di dalam bingkai',
    'Foto Opsional 5/5: Ekspresi netral menghadap depan',
  ];

  final bool isReplace;
  final List<CapturedFaceSample> samples;
  final bool isProcessingSample;
  final bool isSubmitting;
  final Failure? feedbackError;

  const FaceEnrollmentCapturing({
    required this.isReplace,
    this.samples = const [],
    this.isProcessingSample = false,
    this.isSubmitting = false,
    this.feedbackError,
  });

  bool get canCaptureMore =>
      samples.length < 5 && !isProcessingSample && !isSubmitting;

  bool get canSubmit =>
      samples.length >= 3 &&
      samples.length <= 5 &&
      !isProcessingSample &&
      !isSubmitting;

  String get currentInstruction {
    if (isProcessingSample) {
      return 'Tahan sebentar, memvalidasi & mengekstrak fitur wajah...';
    }
    if (isSubmitting) {
      return 'Menyimpan data biometrik wajah ke server...';
    }
    if (samples.length >= poseGuides.length) {
      return 'Maksimal 5 foto tercapai. Tekan Simpan Registrasi Wajah.';
    }
    return poseGuides[samples.length];
  }

  String get currentPoseShortLabel {
    const labels = [
      'Depan',
      'Sedikit Kiri',
      'Sedikit Kanan',
      'Sudut Tambahan 1',
      'Sudut Tambahan 2',
    ];
    final idx = samples.length < labels.length ? samples.length : labels.length - 1;
    return labels[idx];
  }

  FaceEnrollmentCapturing copyWith({
    bool? isReplace,
    List<CapturedFaceSample>? samples,
    bool? isProcessingSample,
    bool? isSubmitting,
    Failure? feedbackError,
    bool clearFeedbackError = false,
  }) {
    return FaceEnrollmentCapturing(
      isReplace: isReplace ?? this.isReplace,
      samples: samples ?? this.samples,
      isProcessingSample: isProcessingSample ?? this.isProcessingSample,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      feedbackError:
          clearFeedbackError ? null : (feedbackError ?? this.feedbackError),
    );
  }

  @override
  List<Object?> get props => [
        isReplace,
        samples,
        isProcessingSample,
        isSubmitting,
        feedbackError,
      ];
}

class FaceEnrollmentSuccess extends FaceEnrollmentState {
  final bool wasReplace;
  final int sampleCount;

  const FaceEnrollmentSuccess({
    required this.wasReplace,
    required this.sampleCount,
  });

  @override
  List<Object?> get props => [wasReplace, sampleCount];
}

class FaceEnrollmentFailure extends FaceEnrollmentState {
  final Failure failure;

  const FaceEnrollmentFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}
