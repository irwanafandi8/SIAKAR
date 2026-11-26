import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/face_enrollment_entities.dart';
import '../../domain/usecases/face_enrollment_usecases.dart';
import 'face_enrollment_state.dart';

class FaceEnrollmentCubit extends Cubit<FaceEnrollmentState> {
  final GetFaceEnrollmentStatusUseCase getStatusUseCase;
  final ExtractFaceSampleUseCase extractSampleUseCase;
  final SubmitFaceEnrollmentUseCase submitEnrollmentUseCase;

  FaceEnrollmentCubit({
    required this.getStatusUseCase,
    required this.extractSampleUseCase,
    required this.submitEnrollmentUseCase,
  }) : super(const FaceEnrollmentInitial());

  /// Periksa status awal wajah dari GET /api/v1/face/status.
  Future<void> loadInitialStatus() async {
    emit(const FaceEnrollmentLoading());
    try {
      final status = await getStatusUseCase();
      if (status.enrolled) {
        emit(FaceEnrollmentAlreadyRegistered(enrolledAt: status.enrolledAt));
      } else {
        emit(const FaceEnrollmentCapturing(isReplace: false));
      }
    } on Failure catch (f) {
      emit(FaceEnrollmentFailure(f));
    } catch (e) {
      emit(
        FaceEnrollmentFailure(
          ServerFailure(
            message: e.toString(),
            code: 'SERVER_ERROR',
          ),
        ),
      );
    }
  }

  /// Masuk ke alur pembaruan wajah (`replace = true`) saat wajah sudah terdaftar.
  void startReplaceFlow() {
    emit(const FaceEnrollmentCapturing(isReplace: true));
  }

  /// Validasi wajah di dalam oval + ekstrak embedding 128-d di perangkat untuk 1 foto.
  Future<void> captureSample({
    required Uint8List photoBytes,
    String? filePath,
  }) async {
    final current = state;
    if (current is! FaceEnrollmentCapturing || !current.canCaptureMore) {
      return;
    }

    emit(
      current.copyWith(
        isProcessingSample: true,
        clearFeedbackError: true,
      ),
    );

    try {
      final sample = await extractSampleUseCase(
        photoBytes: photoBytes,
        poseLabel: current.currentPoseShortLabel,
        filePath: filePath,
      );

      final updatedSamples = List<CapturedFaceSample>.unmodifiable([
        ...current.samples,
        sample,
      ]);

      emit(
        current.copyWith(
          samples: updatedSamples,
          isProcessingSample: false,
          clearFeedbackError: true,
        ),
      );
    } on Failure catch (f) {
      emit(
        current.copyWith(
          isProcessingSample: false,
          feedbackError: f,
        ),
      );
    } catch (_) {
      emit(
        current.copyWith(
          isProcessingSample: false,
          feedbackError: const ServerFailure(
            code: 'INVALID_EMBEDDING',
            message: 'Gagal memproses foto wajah di perangkat. Silakan ambil ulang.',
          ),
        ),
      );
    }
  }

  /// Hapus foto terakhir bila pengguna ingin mengulang sudut pengambilan terakhir.
  void removeLastSample() {
    final current = state;
    if (current is! FaceEnrollmentCapturing ||
        current.samples.isEmpty ||
        current.isProcessingSample ||
        current.isSubmitting) {
      return;
    }

    final updated = List<CapturedFaceSample>.unmodifiable(
      current.samples.sublist(0, current.samples.length - 1),
    );
    emit(current.copyWith(samples: updated, clearFeedbackError: true));
  }

  /// Ulangi seluruh pengambilan sampel dari awal.
  void resetSamples() {
    final current = state;
    if (current is! FaceEnrollmentCapturing ||
        current.isProcessingSample ||
        current.isSubmitting) {
      return;
    }

    emit(
      FaceEnrollmentCapturing(
        isReplace: current.isReplace,
        samples: const [],
      ),
    );
  }

  /// Kirim 3–5 embedding + 1 foto referensi ke POST /api/v1/face/enroll.
  Future<void> submitEnrollment() async {
    final current = state;
    if (current is! FaceEnrollmentCapturing || !current.canSubmit) {
      return;
    }

    emit(
      current.copyWith(
        isSubmitting: true,
        clearFeedbackError: true,
      ),
    );

    try {
      await submitEnrollmentUseCase(
        samples: current.samples,
        replace: current.isReplace,
      );

      emit(
        FaceEnrollmentSuccess(
          wasReplace: current.isReplace,
          sampleCount: current.samples.length,
        ),
      );
    } on Failure catch (f) {
      emit(
        current.copyWith(
          isSubmitting: false,
          feedbackError: f,
        ),
      );
    } catch (_) {
      emit(
        current.copyWith(
          isSubmitting: false,
          feedbackError: const ServerFailure(
            code: 'SERVER_ERROR',
            message: 'Gagal mengirim data registrasi wajah ke server.',
          ),
        ),
      );
    }
  }
}
