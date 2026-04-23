import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// deteksi getaran dengan accelerometer. Digunakan untuk toggle hide/show saldo wallet.
class MotionService {
  StreamSubscription<AccelerometerEvent>? _subscription;

  /// shake threshold (dalam m/s²). Getaran biasa biasanya > 15. 
  static const double _shakeThreshold = 15.0;

  ///minimum waktu antara dua getaran untuk dianggap shake
  static const Duration _shakeCooldown = Duration(milliseconds: 1000);

  DateTime _lastShakeTime = DateTime.now();

  void startListening({required void Function() onShake}) {
    _subscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // deteksi shake berdasarkan magnitude dan cooldown
      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime) > _shakeCooldown) {
          _lastShakeTime = now;
          onShake();
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
