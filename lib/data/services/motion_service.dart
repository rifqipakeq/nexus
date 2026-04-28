import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

class MotionService {
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<dynamic>? _proximitySubscription;

  static const double _shakeThreshold = 15.0;

  static const Duration _shakeCooldown = Duration(milliseconds: 1000);

  DateTime _lastShakeTime = DateTime.now();

  void startListening({required void Function() onShake}) {
    _accelSubscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime) > _shakeCooldown) {
          _lastShakeTime = now;
          onShake();
        }
      }
    });
  }

  void startProximityListening({
    required void Function() onNear,
    required void Function() onFar,
  }) {
    try {
      _proximitySubscription = ProximitySensor.events.listen((int event) {
        debugPrint('Proximity sensor: $event');
        if (event > 0) {
          onNear();
        } else {
          onFar();
        }
      });
    } catch (e) {
      debugPrint('Proximity sensor tidak tersedia: $e');
    }
  }

  void stopListening() {
    _accelSubscription?.cancel();
    _accelSubscription = null;
  }

  void stopProximityListening() {
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
  }

  void stopAll() {
    stopListening();
    stopProximityListening();
  }
}
