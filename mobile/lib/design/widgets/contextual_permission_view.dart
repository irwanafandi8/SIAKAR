import 'package:flutter/material.dart';
import '../../core/device/permission_service.dart';
import '../tokens.dart';
import 'primary_button.dart';

/// Jenis izin perangkat untuk tampilan permintaan kontekstual (DESIGN.md §9).
enum ContextualPermissionType {
  camera,
  location,
}

/// Kartu reusable untuk menampilkan penjelasan kontekstual sebelum meminta izin,
/// serta panduan pemulihan saat izin ditolak atau ditolak permanen.
class PermissionStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool isWarning;

  const PermissionStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isWarning ? Tk.terlambatText : Tk.primary;
    final badgeBg = isWarning ? Tk.terlambatBg : Tk.hadirBg;

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
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: accentColor),
                ),
                const SizedBox(height: Tk.spacing16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                const SizedBox(height: Tk.spacing8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Tk.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: Tk.spacing24),
                PrimaryButton(
                  text: primaryActionLabel,
                  onPressed: onPrimaryAction,
                ),
                if (secondaryActionLabel != null &&
                    onSecondaryAction != null) ...[
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
                      onPressed: onSecondaryAction,
                      child: Text(secondaryActionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gerbang izin kontekstual (M4 / T-222):
/// 1. Jika izin sudah diberikan -> langsung tampilkan `child`.
/// 2. Jika belum diminta -> tampilkan penjelasan satu kalimat terlebih dahulu, baru panggil dialog OS.
/// 3. Jika ditolak (`denied`) -> tampilkan alasan & tombol minta ulang.
/// 4. Jika ditolak permanen (`permanentlyDenied`) -> arahkan ke Pengaturan Aplikasi.
class ContextualPermissionGate extends StatefulWidget {
  final ContextualPermissionType permissionType;
  final DevicePermissionService permissionService;
  final Widget child;
  final VoidCallback? onCancel;

  const ContextualPermissionGate({
    super.key,
    required this.permissionType,
    required this.permissionService,
    required this.child,
    this.onCancel,
  });

  @override
  State<ContextualPermissionGate> createState() =>
      _ContextualPermissionGateState();
}

class _ContextualPermissionGateState extends State<ContextualPermissionGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _hasPromptedThisSession = false;
  AppPermissionStatus _status = AppPermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Saat pengguna kembali dari Pengaturan Aplikasi, periksa ulang status izin
    if (state == AppLifecycleState.resumed) {
      _checkCurrentStatus();
    }
  }

  Future<void> _checkCurrentStatus() async {
    final status = widget.permissionType == ContextualPermissionType.camera
        ? await widget.permissionService.checkCameraPermission()
        : await widget.permissionService.checkLocationPermission();

    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _checking = true);
    final status = widget.permissionType == ContextualPermissionType.camera
        ? await widget.permissionService.requestCameraPermission()
        : await widget.permissionService.requestLocationPermission();

    if (!mounted) return;
    setState(() {
      _hasPromptedThisSession = true;
      _status = status;
      _checking = false;
    });
  }

  Future<void> _openSettings() async {
    await widget.permissionService.openSystemAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_status == AppPermissionStatus.granted) {
      return widget.child;
    }

    final isCamera = widget.permissionType == ContextualPermissionType.camera;
    final icon = isCamera ? Icons.camera_alt_outlined : Icons.location_on_outlined;

    if (_status == AppPermissionStatus.permanentlyDenied ||
        _status == AppPermissionStatus.restricted) {
      return PermissionStateCard(
        icon: Icons.settings_suggest_outlined,
        isWarning: true,
        title: isCamera
            ? 'Akses Kamera Diblokir Permanen'
            : 'Akses Lokasi Diblokir Permanen',
        description: isCamera
            ? 'Izin kamera telah ditolak secara permanen. Silakan buka Pengaturan Aplikasi dan aktifkan izin Kamera untuk melanjutkan verifikasi wajah.'
            : 'Izin lokasi telah ditolak secara permanen. Silakan buka Pengaturan Aplikasi dan aktifkan izin Lokasi untuk memverifikasi jarak kantor.',
        primaryActionLabel: 'Buka Pengaturan Aplikasi',
        onPrimaryAction: _openSettings,
        secondaryActionLabel: 'Periksa Ulang Izin',
        onSecondaryAction: _checkCurrentStatus,
      );
    }

    if (_hasPromptedThisSession && _status == AppPermissionStatus.denied) {
      return PermissionStateCard(
        icon: icon,
        isWarning: true,
        title: isCamera ? 'Izin Kamera Ditolak' : 'Izin Lokasi Ditolak',
        description: isCamera
            ? 'Tanpa izin kamera, aplikasi tidak dapat mengambil foto wajah di dalam bingkai oval.'
            : 'Tanpa izin lokasi GPS, aplikasi tidak dapat memvalidasi posisi kehadiran Anda di area kantor.',
        primaryActionLabel: 'Minta Izin Kembali',
        onPrimaryAction: _requestPermission,
        secondaryActionLabel: widget.onCancel != null ? 'Kembali' : null,
        onSecondaryAction: widget.onCancel,
      );
    }

    // Penjelasan kontekstual satu kalimat SEBELUM memunculkan dialog izin sistem (DESIGN.md §9)
    return PermissionStateCard(
      icon: icon,
      title: isCamera ? 'Izin Akses Kamera Diperlukan' : 'Izin Lokasi GPS Diperlukan',
      description: isCamera
          ? 'Aplikasi memerlukan kamera depan untuk memindai wajah Anda di dalam bingkai oval secara langsung di perangkat.'
          : 'Aplikasi memerlukan lokasi GPS akurat untuk memastikan Anda berada di dalam radius kantor saat melakukan absensi.',
      primaryActionLabel: 'Lanjutkan & Izinkan',
      onPrimaryAction: _requestPermission,
      secondaryActionLabel: widget.onCancel != null ? 'Batal' : null,
      onSecondaryAction: widget.onCancel,
    );
  }
}
