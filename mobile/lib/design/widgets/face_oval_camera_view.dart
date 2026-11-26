import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/error/error_messages.dart';
import '../../core/error/failures.dart';
import '../../core/ml/preprocess.dart';
import '../tokens.dart';
import 'primary_button.dart';

/// Hasil pengambilan satu foto dari kamera.
class CapturedPhotoData {
  final Uint8List bytes;
  final String filePath;

  const CapturedPhotoData({
    required this.bytes,
    required this.filePath,
  });
}

/// Abstraksi pengendali kamera depan agar widget kamera reusable dapat diuji tanpa perangkat fisik.
abstract class FaceCameraControllerAdapter {
  bool get isInitialized;
  Future<void> initialize();
  Widget buildPreview();
  Future<CapturedPhotoData> takePicture();
  Future<void> dispose();
}

/// Implementasi kamera depan perangkat asli memakai `package:camera`.
class DeviceFrontCameraAdapter implements FaceCameraControllerAdapter {
  final ResolutionPreset resolutionPreset;
  CameraController? _controller;

  DeviceFrontCameraAdapter({
    this.resolutionPreset = ResolutionPreset.medium,
  });

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw DeviceFailure(
        code: 'CAMERA_UNAVAILABLE',
        message: ErrorMessages.fromCode('CAMERA_UNAVAILABLE'),
      );
    }

    final selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      selectedCamera,
      resolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {
      // Beberapa kamera depan tidak mendukung pengaturan flash; abaikan dengan aman.
    }
    _controller = controller;
  }

  @override
  Widget buildPreview() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return CameraPreview(ctrl);
  }

  @override
  Future<CapturedPhotoData> takePicture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      throw DeviceFailure(
        code: 'CAMERA_UNAVAILABLE',
        message: ErrorMessages.fromCode('CAMERA_UNAVAILABLE'),
      );
    }

    final xFile = await ctrl.takePicture();
    final bytes = await xFile.readAsBytes();
    return CapturedPhotoData(bytes: bytes, filePath: xFile.path);
  }

  @override
  Future<void> dispose() async {
    final ctrl = _controller;
    _controller = null;
    await ctrl?.dispose();
  }
}

/// Pelukis overlay oval panduan yang rasio & posisinya diambil satu sumber dari `PreprocessConfig` (`preprocess.json`).
class FaceOvalOverlayPainter extends CustomPainter {
  final PreprocessConfig preprocessConfig;
  final Color borderColor;
  final double borderWidth;

  const FaceOvalOverlayPainter({
    required this.preprocessConfig,
    this.borderColor = Tk.primary,
    this.borderWidth = 3.0,
  });

  Rect computeOvalRect(Size size) {
    final cx = preprocessConfig.ovalCenterXRatio * size.width;
    final cy = preprocessConfig.ovalCenterYRatio * size.height;
    final ovalW = preprocessConfig.ovalWidthRatio * size.width;
    final ovalH = preprocessConfig.ovalHeightRatio * size.height;
    return Rect.fromCenter(center: Offset(cx, cy), width: ovalW, height: ovalH);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = computeOvalRect(size);

    final fullPath = Path()..addRect(Offset.zero & size);
    final ovalPath = Path()..addOval(ovalRect);
    final scrimPath = Path.combine(PathOperation.difference, fullPath, ovalPath);

    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.56)
      ..style = PaintingStyle.fill;
    canvas.drawPath(scrimPath, scrimPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant FaceOvalOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.preprocessConfig.ovalWidthRatio !=
            preprocessConfig.ovalWidthRatio ||
        oldDelegate.preprocessConfig.ovalHeightRatio !=
            preprocessConfig.ovalHeightRatio;
  }
}

/// Komponen kamera reusable dengan bingkai oval panduan & instruksi di atas oval (DESIGN.md §9).
class FaceOvalCameraView extends StatefulWidget {
  final PreprocessConfig preprocessConfig;
  final String instructionText;
  final String captureButtonLabel;
  final ValueChanged<CapturedPhotoData> onPhotoCaptured;
  final bool isBusy;
  final bool isFrameValid;
  final FaceCameraControllerAdapter? cameraAdapter;

  const FaceOvalCameraView({
    super.key,
    required this.preprocessConfig,
    required this.onPhotoCaptured,
    this.instructionText = 'Posisikan wajah di dalam bingkai',
    this.captureButtonLabel = 'Ambil Foto',
    this.isBusy = false,
    this.isFrameValid = true,
    this.cameraAdapter,
  });

  @override
  State<FaceOvalCameraView> createState() => _FaceOvalCameraViewState();
}

class _FaceOvalCameraViewState extends State<FaceOvalCameraView>
    with WidgetsBindingObserver {
  late FaceCameraControllerAdapter _adapter;
  late bool _ownsAdapter;
  bool _initializing = true;
  bool _capturing = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsAdapter = widget.cameraAdapter == null;
    _adapter = widget.cameraAdapter ?? DeviceFrontCameraAdapter();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsAdapter) {
      _adapter.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ownsAdapter) return;
    if (state == AppLifecycleState.inactive) {
      _adapter.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _adapter = DeviceFrontCameraAdapter();
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _cameraError = null;
    });
    try {
      await _adapter.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = f.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = ErrorMessages.fromCode('CAMERA_UNAVAILABLE');
      });
    }
  }

  Future<void> _handleCapture() async {
    if (_capturing || widget.isBusy || !_adapter.isInitialized) return;
    setState(() => _capturing = true);
    try {
      final photo = await _adapter.takePicture();
      if (mounted) {
        widget.onPhotoCaptured(photo);
      }
    } on Failure catch (f) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message), backgroundColor: Tk.alpaText),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil foto dari kamera. Silakan coba lagi.'),
            backgroundColor: Tk.alpaText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Tk.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 48,
                color: Tk.alpaText,
              ),
              const SizedBox(height: Tk.spacing12),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Tk.navy, fontSize: 14),
              ),
              const SizedBox(height: Tk.spacing16),
              PrimaryButton(
                text: 'Muat Ulang Kamera',
                icon: Icons.refresh,
                onPressed: _initCamera,
              ),
            ],
          ),
        ),
      );
    }

    final canCapture =
        widget.isFrameValid && !widget.isBusy && !_capturing && _adapter.isInitialized;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Tk.radiusCard),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _adapter.buildPreview(),
                IgnorePointer(
                  child: CustomPaint(
                    painter: FaceOvalOverlayPainter(
                      preprocessConfig: widget.preprocessConfig,
                      borderColor: widget.isFrameValid ? Tk.primary : Colors.amber,
                    ),
                  ),
                ),
                // Instruksi singkat di atas oval (DESIGN.md §9)
                Positioned(
                  top: Tk.spacing16,
                  left: Tk.spacing16,
                  right: Tk.spacing16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tk.spacing16,
                        vertical: Tk.spacing8,
                      ),
                      decoration: BoxDecoration(
                        color: Tk.navy.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(Tk.radiusChip),
                      ),
                      child: Text(
                        widget.instructionText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Tk.onPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tk.spacing16),
        PrimaryButton(
          text: widget.captureButtonLabel,
          icon: Icons.camera_alt,
          isLoading: _capturing || widget.isBusy,
          onPressed: canCapture ? _handleCapture : null,
        ),
      ],
    );
  }
}
