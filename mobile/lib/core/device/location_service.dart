import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../error/error_messages.dart';
import '../error/failures.dart';
import 'permission_service.dart';

/// Data koordinat GPS yang diperoleh dari perangkat.
class LocationCoordinates extends Equatable {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isMocked;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters = 0.0,
    this.isMocked = false,
  });

  @override
  List<Object?> get props => [latitude, longitude, accuracyMeters, isMocked];
}

/// Kontrak layanan pengambilan posisi GPS perangkat (M4 / T-222).
abstract class LocationService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationCoordinates> getCurrentPosition();
  Future<bool> openLocationSettings();
}

/// Implementasi `LocationService` menggunakan `geolocator`.
class GeolocatorLocationService implements LocationService {
  final DevicePermissionService permissionService;
  final Duration timeLimit;

  const GeolocatorLocationService({
    required this.permissionService,
    this.timeLimit = const Duration(seconds: 15),
  });

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  @override
  Future<LocationCoordinates> getCurrentPosition() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw DeviceFailure(
        code: 'LOCATION_SERVICE_DISABLED',
        message: ErrorMessages.fromCode('LOCATION_SERVICE_DISABLED'),
      );
    }

    var permStatus = await permissionService.checkLocationPermission();
    if (permStatus == AppPermissionStatus.denied) {
      permStatus = await permissionService.requestLocationPermission();
    }

    if (permStatus == AppPermissionStatus.permanentlyDenied) {
      throw PermissionFailure(
        code: 'LOCATION_PERMISSION_PERMANENTLY_DENIED',
        message:
            ErrorMessages.fromCode('LOCATION_PERMISSION_PERMANENTLY_DENIED'),
        isPermanentlyDenied: true,
      );
    }

    if (permStatus != AppPermissionStatus.granted) {
      throw PermissionFailure(
        code: 'LOCATION_PERMISSION_DENIED',
        message: ErrorMessages.fromCode('LOCATION_PERMISSION_DENIED'),
        isPermanentlyDenied: false,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      );

      if (position.isMocked) {
        throw DeviceFailure(
          code: 'MOCK_LOCATION_DETECTED',
          message: ErrorMessages.fromCode('MOCK_LOCATION_DETECTED'),
        );
      }

      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        isMocked: position.isMocked,
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw const DeviceFailure(
        code: 'LOCATION_ERROR',
        message: 'Gagal mendapatkan koordinat GPS perangkat. Pastikan sinyal GPS aktif.',
      );
    }
  }
}
