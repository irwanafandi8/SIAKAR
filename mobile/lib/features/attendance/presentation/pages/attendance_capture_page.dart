import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/device/permission_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/ml/preprocess.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/contextual_permission_view.dart';
import '../../../../design/widgets/face_oval_camera_view.dart';
import '../../../../design/widgets/primary_button.dart';
import '../../../../design/widgets/status_badge.dart';
import '../../domain/entities/attendance_entities.dart';
import '../cubit/attendance_capture_cubit.dart';
import '../cubit/attendance_capture_state.dart';

/// Halaman pengambilan GPS, kamera oval, verifikasi wajah TFLite, dan hasil absensi (M6 / T-301).
class AttendanceCapturePage extends StatelessWidget {
  final AttendanceMode mode;
  final DevicePermissionService permissionService;
  final PreprocessConfig preprocessConfig;
  final FaceCameraControllerAdapter? cameraAdapter;

  const AttendanceCapturePage({
    super.key,
    required this.mode,
    required this.permissionService,
    required this.preprocessConfig,
    this.cameraAdapter,
  });

  void _closePage(BuildContext context, {required bool didSucceed}) {
    if (context.canPop()) {
      context.pop(didSucceed);
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(mode.title),
      ),
      body: SafeArea(
        child: ContextualPermissionGate(
          permissionType: ContextualPermissionType.location,
          permissionService: permissionService,
          onCancel: () => _closePage(context, didSucceed: false),
          child: ContextualPermissionGate(
            permissionType: ContextualPermissionType.camera,
            permissionService: permissionService,
            onCancel: () => _closePage(context, didSucceed: false),
            child: _AttendanceCaptureBody(
              mode: mode,
              preprocessConfig: preprocessConfig,
              cameraAdapter: cameraAdapter,
              onDone: (didSucceed) =>
                  _closePage(context, didSucceed: didSucceed),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceCaptureBody extends StatefulWidget {
  final AttendanceMode mode;
  final PreprocessConfig preprocessConfig;
  final FaceCameraControllerAdapter? cameraAdapter;
  final ValueChanged<bool> onDone;

  const _AttendanceCaptureBody({
    required this.mode,
    required this.preprocessConfig,
    this.cameraAdapter,
    required this.onDone,
  });

  @override
  State<_AttendanceCaptureBody> createState() => _AttendanceCaptureBodyState();
}

class _AttendanceCaptureBodyState extends State<_AttendanceCaptureBody> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<AttendanceCaptureCubit>();
    if (cubit.state is AttendanceCaptureInitial) {
      cubit.prepareCapture(widget.mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCaptureCubit, AttendanceCaptureState>(
      builder: (context, state) {
        if (state is AttendanceCaptureInitial ||
            state is AttendanceCaptureLocating) {
          return _buildLocatingView();
        }

        if (state is AttendanceCaptureLocationFailed) {
          return _buildLocationFailedView(context, state);
        }

        if (state is AttendanceCaptureReady) {
          return _buildCameraCaptureView(context, state);
        }

        if (state is AttendanceCaptureSuccess) {
          return AttendanceResultView.success(
            result: state.result,
            onBackToHome: () => widget.onDone(true),
          );
        }

        if (state is AttendanceCaptureRejected) {
          return AttendanceResultView.rejected(
            mode: state.mode,
            failure: state.failure,
            onRetakePhoto: () =>
                context.read<AttendanceCaptureCubit>().returnToCamera(),
            onRefreshGpsAndRetry: () => context
                .read<AttendanceCaptureCubit>()
                .prepareCapture(widget.mode),
            onBackToHome: () => widget.onDone(false),
            onEnrollFace: state.failure.code == 'FACE_NOT_ENROLLED'
                ? () => context.pushReplacement('/face/enroll')
                : null,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLocatingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tk.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Tk.spacing16),
            Text(
              'Mengambil koordinat GPS untuk ${widget.mode.title}...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Tk.navy,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Tk.spacing8),
            const Text(
              'Pastikan Anda berada di area terbuka atau dekat jendela agar sinyal GPS akurat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Tk.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationFailedView(
    BuildContext context,
    AttendanceCaptureLocationFailed state,
  ) {
    final cubit = context.read<AttendanceCaptureCubit>();
    final icon = state.isMockGps
        ? Icons.gpp_bad_outlined
        : Icons.location_disabled_outlined;

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
                    color: Tk.alpaBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: Tk.alpaText),
                ),
                const SizedBox(height: Tk.spacing16),
                Text(
                  state.isMockGps
                      ? 'Lokasi Palsu Terdeteksi'
                      : 'Lokasi GPS Tidak Tersedia',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                const SizedBox(height: Tk.spacing8),
                Text(
                  state.failure.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Tk.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: Tk.spacing24),
                if (state.isGpsServiceDisabled) ...[
                  PrimaryButton(
                    text: 'Aktifkan GPS di Pengaturan',
                    icon: Icons.settings,
                    onPressed: cubit.openGpsSettings,
                  ),
                  const SizedBox(height: Tk.spacing12),
                ],
                PrimaryButton(
                  text: 'Periksa Ulang GPS',
                  icon: Icons.my_location,
                  backgroundColor:
                      state.isGpsServiceDisabled ? Tk.navy : Tk.primary,
                  onPressed: () => cubit.prepareCapture(widget.mode),
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
                    onPressed: () => widget.onDone(false),
                    child: const Text('Kembali ke Beranda'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCaptureView(
    BuildContext context,
    AttendanceCaptureReady state,
  ) {
    final cubit = context.read<AttendanceCaptureCubit>();
    final preview = state.nearestOffice;

    return Padding(
      padding: const EdgeInsets.all(Tk.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGpsInfoCard(context, state, preview),
          if (state.inlineWarning != null) ...[
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
                      state.inlineWarning!.message,
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
              instructionText: state.isSubmitting
                  ? 'Memverifikasi wajah & lokasi di server...'
                  : 'Posisikan wajah di dalam bingkai oval',
              captureButtonLabel: state.mode == AttendanceMode.checkOut
                  ? 'Konfirmasi Absen Pulang'
                  : 'Konfirmasi Absen Masuk',
              isBusy: state.isSubmitting,
              isFrameValid: !state.isSubmitting,
              onPhotoCaptured: (photo) {
                cubit.captureAndSubmit(photoBytes: photo.bytes);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsInfoCard(
    BuildContext context,
    AttendanceCaptureReady state,
    NearestOfficePreview? preview,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tk.spacing12,
          vertical: Tk.spacing8,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Tk.surfaceTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: Tk.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: Tk.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview != null
                        ? '${preview.office.nama} (±${preview.distanceMeters.toStringAsFixed(0)} m)'
                        : 'GPS Aktif (${state.position.latitude.toStringAsFixed(5)}, ${state.position.longitude.toStringAsFixed(5)})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Tk.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview != null
                        ? 'Radius kantor ${preview.office.radiusMeter} m · Akurasi GPS ±${state.position.accuracyMeters.toStringAsFixed(0)} m'
                        : 'Akurasi GPS ±${state.position.accuracyMeters.toStringAsFixed(0)} m · Diverifikasi server',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Tk.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Perbarui Titik GPS',
              constraints: const BoxConstraints(
                minWidth: Tk.minTouchTarget,
                minHeight: Tk.minTouchTarget,
              ),
              onPressed: state.isSubmitting
                  ? null
                  : () => context
                      .read<AttendanceCaptureCubit>()
                      .prepareCapture(widget.mode),
              icon: const Icon(Icons.refresh, size: 20, color: Tk.navy),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tampilan hasil konfirmasi sukses maupun penolakan server (DESIGN.md §8.1 `/attendance/result`).
class AttendanceResultView extends StatelessWidget {
  final bool isSuccess;
  final AttendanceSubmissionResult? result;
  final AttendanceMode mode;
  final Failure? failure;
  final VoidCallback onBackToHome;
  final VoidCallback? onRetakePhoto;
  final VoidCallback? onRefreshGpsAndRetry;
  final VoidCallback? onEnrollFace;

  AttendanceResultView.success({
    super.key,
    required AttendanceSubmissionResult this.result,
    required this.onBackToHome,
  })  : isSuccess = true,
        mode = result.mode,
        failure = null,
        onRetakePhoto = null,
        onRefreshGpsAndRetry = null,
        onEnrollFace = null;

  const AttendanceResultView.rejected({
    super.key,
    required this.mode,
    required Failure this.failure,
    required this.onBackToHome,
    this.onRetakePhoto,
    this.onRefreshGpsAndRetry,
    this.onEnrollFace,
  })  : isSuccess = false,
        result = null;

  @override
  Widget build(BuildContext context) {
    if (isSuccess && result != null) {
      return _buildSuccessCard(result!);
    }
    return _buildRejectedCard(failure!);
  }

  Widget _buildSuccessCard(AttendanceSubmissionResult res) {
    final att = res.attendance;
    final recordedTime = res.mode == AttendanceMode.checkOut
        ? (att.jamPulang ?? '--:--:--')
        : (att.jamMasuk ?? '--:--:--');

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
                StatusBadge(status: res.status),
                const SizedBox(height: Tk.spacing12),
                Text(
                  '${res.mode.title} Berhasil',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                const SizedBox(height: Tk.spacing4),
                Text(
                  'Tanggal Server: ${att.tanggal}',
                  style: const TextStyle(fontSize: 13, color: Tk.textMuted),
                ),
                const Divider(height: Tk.spacing24, color: Tk.outline),
                _detailRow(
                  res.mode == AttendanceMode.checkOut
                      ? 'Jam Pulang (WIB)'
                      : 'Jam Masuk (WIB)',
                  recordedTime,
                ),
                if (att.lokasi != null && att.lokasi!.isNotEmpty)
                  _detailRow('Lokasi Kantor', att.lokasi!),
                if (res.distanceMeter != null)
                  _detailRow(
                    'Jarak ke Kantor',
                    '${res.distanceMeter!.toStringAsFixed(1)} meter',
                  ),
                if (res.similarity != null)
                  _detailRow(
                    'Skor Kecocokan Wajah',
                    res.similarity!.toStringAsFixed(4),
                  ),
                const SizedBox(height: Tk.spacing24),
                PrimaryButton(
                  text: 'Selesai & Kembali ke Beranda',
                  icon: Icons.home_outlined,
                  onPressed: onBackToHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedCard(Failure err) {
    double? serverDistance;
    double? serverSimilarity;
    if (err is OutOfRadiusFailure) {
      serverDistance = err.distanceMeter;
    } else if (err is FaceMismatchFailure) {
      serverSimilarity = err.similarity;
    }

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
                    color: Tk.alpaBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    size: 40,
                    color: Tk.alpaText,
                  ),
                ),
                const SizedBox(height: Tk.spacing16),
                const StatusBadge(status: 'ditolak'),
                const SizedBox(height: Tk.spacing12),
                Text(
                  '${mode.title} Ditolak',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                const SizedBox(height: Tk.spacing8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Tk.spacing12),
                  decoration: BoxDecoration(
                    color: Tk.alpaBg,
                    borderRadius: BorderRadius.circular(Tk.radiusInput),
                  ),
                  child: Text(
                    err.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Tk.alpaText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                if (serverDistance != null || serverSimilarity != null) ...[
                  const Divider(height: Tk.spacing24, color: Tk.outline),
                  if (serverDistance != null)
                    _detailRow(
                      'Jarak Terukur Server',
                      '${serverDistance.toStringAsFixed(1)} meter',
                    ),
                  if (serverSimilarity != null)
                    _detailRow(
                      'Skor Kemiripan Wajah',
                      serverSimilarity.toStringAsFixed(4),
                    ),
                ],
                const SizedBox(height: Tk.spacing24),
                if (onEnrollFace != null) ...[
                  PrimaryButton(
                    text: 'Buka Registrasi Wajah',
                    icon: Icons.face_retouching_natural,
                    onPressed: onEnrollFace,
                  ),
                  const SizedBox(height: Tk.spacing12),
                ] else if (err is OutOfRadiusFailure &&
                    onRefreshGpsAndRetry != null) ...[
                  PrimaryButton(
                    text: 'Perbarui GPS & Coba Lagi',
                    icon: Icons.my_location,
                    onPressed: onRefreshGpsAndRetry,
                  ),
                  const SizedBox(height: Tk.spacing12),
                ] else if (onRetakePhoto != null) ...[
                  PrimaryButton(
                    text: 'Ambil Ulang Foto Wajah',
                    icon: Icons.camera_alt_outlined,
                    onPressed: onRetakePhoto,
                  ),
                  const SizedBox(height: Tk.spacing12),
                ],
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
                    onPressed: onBackToHome,
                    child: const Text('Kembali ke Beranda'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Tk.textMuted, fontSize: 13),
          ),
          const SizedBox(width: Tk.spacing8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Tk.navy,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
