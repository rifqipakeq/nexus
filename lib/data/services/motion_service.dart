import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects shake gestures using the accelerometer.
/// Used to toggle hide/show wallet balance.
class MotionService {
  StreamSubscription<AccelerometerEvent>? _subscription;

  /// Shake threshold (in m/s²). Typical shake is > 15.
  static const double _shakeThreshold = 15.0;

  /// Minimum time between shake detections.
  static const Duration _shakeCooldown = Duration(milliseconds: 1000);

  DateTime _lastShakeTime = DateTime.now();

  /// Start listening to accelerometer and call [onShake] when detected.
  void startListening({required void Function() onShake}) {
    _subscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // Subtract gravity (~9.8) and check threshold
      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime) > _shakeCooldown) {
          _lastShakeTime = now;
          onShake();
        }
      }
    });
  }

  /// Stop listening to accelerometer.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
