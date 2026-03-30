import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../../core/env_config.dart';

/// GPS-based safe zone check.
/// "Send Transaction" button is enabled only when user is inside the safe zone.
class LocationService {
  /// Request location permission and get current position.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Check if the user is within the configured safe zone radius.
  /// Returns true if inside, false if outside.
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

  /// Haversine formula to calculate distance in meters between two coordinates.
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
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
