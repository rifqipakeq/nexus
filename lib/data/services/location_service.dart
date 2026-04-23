import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../../core/env_config.dart';

/// GPS function untuk safe zone transaksi
class LocationService {
  /// Request location permission and
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi tidak aktif. Silakan aktifkan GPS untuk menggunakan fitur ini.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi selalu ditolak.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// cek apakah user berada di safe zone
  Future<bool> isInsideSafeZone() async {
    try {
      final position = await getCurrentPosition();
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        EnvConfig.safeZoneLat,
        EnvConfig.safeZoneLng,
      );
      return distance <= EnvConfig.safeZoneRadius;
    } catch (_) {
      return false;
    }
  }

  /// rumus untuk menghitung jarak antara dua titik koordinat (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meter
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
