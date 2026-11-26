import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/device/permission_service.dart';
import '../../../../core/ml/preprocess.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/contextual_permission_view.dart';
import '../../../../design/widgets/face_oval_camera_view.dart';
import '../../../../design/widgets/primary_button.dart';
import '../../../../design/widgets/status_badge.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../cubit/face_enrollment_cubit.dart';
import '../cubit/face_enrollment_state.dart';

class FaceEnrollmentPage extends StatefulWidget {
  final DevicePermissionService permissionService;
  final PreprocessConfig preprocessConfig;
  final FaceCameraControllerAdapter? cameraAdapter;

  const FaceEnrollmentPage({
    super.key,
    required this.permissionService,
    required this.preprocessConfig,
    this.cameraAdapter,
  });

  @override
  State<FaceEnrollmentPage> createState() => _FaceEnrollmentPageState();
}

class _FaceEnrollmentPageState extends State<FaceEnrollmentPage> {
  @override
  void initState() {
    super.initState();
    context.read<FaceEnrollmentCubit>().loadInitialStatus();
  }

  void _finishAndReturn(BuildContext context) {
    try {
      context.read<AuthCubit>().checkAuthStatus();
    } catch (_) {
      // Abaikan bila AuthCubit tidak tersedia pada lingkungan widget test terisolasi
    }
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FaceEnrollmentCubit, FaceEnrollmentState>(
      listener: (context, state) {
        if (state is FaceEnrollmentSuccess) {
          try {
            context.read<AuthCubit>().checkAuthStatus();
          } catch (_) {}
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registrasi Wajah'),
        ),
        body: SafeArea(
          child: BlocBuilder<FaceEnrollmentCubit, FaceEnrollmentState>(
            builder: (context, state) {
              if (state is FaceEnrollmentInitial ||
                  state is FaceEnrollmentLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is FaceEnrollmentFailure) {
                return _buildErrorState(context, state.failure.message);
              }

              if (state is FaceEnrollmentAlreadyRegistered) {
                return _buildAlreadyRegisteredView(context, state.enrolledAt);
              }

              if (state is FaceEnrollmentSuccess) {
                return _buildSuccessView(context, state);
              }

              if (state is FaceEnrollmentCapturing) {
                return ContextualPermissionGate(
                  permissionType: ContextualPermissionType.camera,
                  permissionService: widget.permissionService,
                  onCancel: () {
                    if (context.canPop()) context.pop(false);
                  },
                  child: _buildCaptureFlow(context, state),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tk.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Tk.alpaText),
            const SizedBox(height: Tk.spacing12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Tk.navy, fontSize: 15),
            ),
            const SizedBox(height: Tk.spacing16),
            PrimaryButton(
              text: 'Coba Lagi',
              icon: Icons.refresh,
              onPressed: () =>
                  context.read<FaceEnrollmentCubit>().loadInitialStatus(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyRegisteredView(
    BuildContext context,
    String? enrolledAt,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tk.spacing24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Tk.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Tk.hadirBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    size: 34,
                    color: Tk.hadirText,
                  ),
                ),
                const SizedBox(height: Tk.spacing16),
                const StatusBadge(status: 'disetujui'),
                const SizedBox(height: Tk.spacing12),
                const Text(
                  'Data Wajah Sudah Terdaftar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                const SizedBox(height: Tk.spacing8),
                Text(
                  enrolledAt != null
                      ? 'Terdaftar pada: $enrolledAt\n\nJika Anda memperbarui wajah, data lama hanya akan diganti setelah pendaftaran baru berhasil disimpan.'
                      : 'Data biometrik wajah Anda telah aktif. Anda dapat memperbaruinya dengan mengambil 3–5 foto baru.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Tk.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: Tk.spacing24),
                PrimaryButton(
                  text: 'Perbarui Data Wajah',
                  icon: Icons.camera_front,
                  onPressed: () =>
                      context.read<FaceEnrollmentCubit>().startReplaceFlow(),
                ),
                const SizedBox(height: Tk.spacing12),
                SizedBox(
                  width: double.infinity,
                  height: Tk.minTouchTarget,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Tk.navy,
                      side: const BorderSide(color: Tk.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Tk.radiusButton),
                      ),
                    ),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop(false);
                      } else {
                        context.go('/home');
                      }
                    },
                    child: const Text('Kembali'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureFlow(
    BuildContext context,
    FaceEnrollmentCapturing state,
  ) {
    final cubit = context.read<FaceEnrollmentCubit>();
    final count = state.samples.length;

    return Padding(
      padding: const EdgeInsets.all(Tk.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProgressCard(state),
          if (state.feedbackError != null) ...[
            const SizedBox(height: Tk.spacing8),
            Container(
              padding: const EdgeInsets.all(Tk.spacing12),
              decoration: BoxDecoration(
                color: Tk.alpaBg,
                borderRadius: BorderRadius.circular(Tk.radiusInput),
                border: Border.all(color: Tk.alpaText.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Tk.alpaText,
                    size: 20,
                  ),
                  const SizedBox(width: Tk.spacing8),
                  Expanded(
                    child: Text(
                      state.feedbackError!.message,
                      style: const TextStyle(
                        color: Tk.alpaText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Tk.spacing12),
          Expanded(
            child: FaceOvalCameraView(
              preprocessConfig: widget.preprocessConfig,
              cameraAdapter: widget.cameraAdapter,
              instructionText: state.currentInstruction,
              captureButtonLabel: count < 3
                  ? 'Ambil Foto (${count + 1}/3 Wajib)'
                  : (count < 5
                      ? 'Tambah Sudut Opsional (${count + 1}/5)'
                      : 'Batas 5 Foto Tercapai'),
              isBusy: state.isProcessingSample || state.isSubmitting,
              isFrameValid: state.canCaptureMore,
              onPhotoCaptured: (photo) {
                cubit.captureSample(
                  photoBytes: photo.bytes,
                  filePath: photo.filePath,
                );
              },
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: Tk.spacing12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: Tk.minTouchTarget,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Tk.navy,
                        side: const BorderSide(color: Tk.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tk.radiusButton),
                        ),
                      ),
                      onPressed: (state.isProcessingSample || state.isSubmitting)
                          ? null
                          : cubit.removeLastSample,
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Hapus Terakhir'),
                    ),
                  ),
                ),
                if (state.canSubmit || state.isSubmitting) ...[
                  const SizedBox(width: Tk.spacing12),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      text: 'Simpan Wajah ($count Foto)',
                      icon: Icons.check_circle_outline,
                      backgroundColor: Tk.navy,
                      isLoading: state.isSubmitting,
                      onPressed: state.canSubmit ? cubit.submitEnrollment : null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressCard(FaceEnrollmentCapturing state) {
    final count = state.samples.length;
    final progressValue = (count / 3.0).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tk.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.isReplace
                      ? 'Perbarui Wajah (3–5 Foto)'
                      : 'Pendaftaran Wajah Baru (3–5 Foto)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Tk.navy,
                  ),
                ),
                Text(
                  '$count / 5 tersimpan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: count >= 3 ? Tk.primary : Tk.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tk.spacing8),
            ClipRRect(
              borderRadius: BorderRadius.circular(Tk.radiusChip),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 8,
                backgroundColor: Tk.surfaceTint,
                valueColor: AlwaysStoppedAnimation<Color>(
                  count >= 3 ? Tk.primary : Tk.navy,
                ),
              ),
            ),
            if (state.samples.isNotEmpty) ...[
              const SizedBox(height: Tk.spacing8),
              Wrap(
                spacing: Tk.spacing8,
                runSpacing: Tk.spacing4,
                children: List.generate(state.samples.length, (i) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Tk.spacing8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Tk.hadirBg,
                      borderRadius: BorderRadius.circular(Tk.radiusChip),
                    ),
                    child: Text(
                      '#${i + 1} ${state.samples[i].poseLabel}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Tk.hadirText,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    FaceEnrollmentSuccess state,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tk.spacing24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Tk.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Tk.hadirBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 40,
                    color: Tk.primary,
                  ),
                ),
                const SizedBox(height: Tk.spacing16),
                Text(
                  state.wasReplace
                      ? 'Data Wajah Berhasil Diperbarui'
                      : 'Registrasi Wajah Berhasil',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                const SizedBox(height: Tk.spacing8),
                Text(
                  '${state.sampleCount} sampel wajah telah diekstrak di perangkat dan disimpan secara terenkripsi. Menu Absen Masuk & Pulang kini siap digunakan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Tk.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: Tk.spacing24),
                PrimaryButton(
                  text: 'Selesai & Kembali',
                  icon: Icons.arrow_back,
                  onPressed: () => _finishAndReturn(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
