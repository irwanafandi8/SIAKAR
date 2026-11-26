import 'dart:math' as math;

/// Utilitas perhitungan jarak Haversine hanya untuk tampilan UI di klien.
/// Keputusan geofencing resmi tetap berada di server (AGENTS.md aturan 5).
class GeoUtils {
  const GeoUtils._();

  static const double _earthRadiusMeters = 6371000.0;

  static double distanceInMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final radLat1 = _degToRad(lat1);
    final radLat2 = _degToRad(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radLat1) *
            math.cos(radLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
