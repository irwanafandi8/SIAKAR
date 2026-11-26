import 'package:permission_handler/permission_handler.dart' as ph;

/// Status izin perangkat yang disederhanakan untuk lapisan aplikasi & UI.
enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Kontrak layanan manajemen izin perangkat (kamera & lokasi).
abstract class DevicePermissionService {
  Future<AppPermissionStatus> checkCameraPermission();
  Future<AppPermissionStatus> requestCameraPermission();

  Future<AppPermissionStatus> checkLocationPermission();
  Future<AppPermissionStatus> requestLocationPermission();

  Future<bool> openSystemAppSettings();
}

/// Implementasi `DevicePermissionService` berbasis `permission_handler`.
class PermissionHandlerService implements DevicePermissionService {
  const PermissionHandlerService();

  @override
  Future<AppPermissionStatus> checkCameraPermission() async {
    final status = await ph.Permission.camera.status;
    return _mapStatus(status);
  }

  @override
  Future<AppPermissionStatus> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    return _mapStatus(status);
  }

  @override
  Future<AppPermissionStatus> checkLocationPermission() async {
    final status = await ph.Permission.locationWhenInUse.status;
    return _mapStatus(status);
  }

  @override
  Future<AppPermissionStatus> requestLocationPermission() async {
    final status = await ph.Permission.locationWhenInUse.request();
    return _mapStatus(status);
  }

  @override
  Future<bool> openSystemAppSettings() {
    return ph.openAppSettings();
  }

  static AppPermissionStatus _mapStatus(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return AppPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return AppPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return AppPermissionStatus.restricted;
    }
    return AppPermissionStatus.denied;
  }
}
