import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// handling password hashing dan verifikasi menggunakan PBKDF2-HMAC-SHA256.
/// - 100,000 iterasi
/// - 32-byte  random salt per user
/// - 32-byte (256-bit) derived key
class PasswordService {
  /// 100k standar oWASP 2023 untuk PBKDF2-HMAC-SHA256.
  static const int _iterations = 100000;
  static const int _bits = 256;
  static const int _saltLength = 32;
  final Pbkdf2 _pbkdf2;

  PasswordService()
    : _pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: _bits,
      );

  String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(
      _saltLength,
      (_) => random.nextInt(256),
    );
    return base64Encode(saltBytes);
  }

  Future<String> hashPassword(String password, String saltBase64) async {
    final saltBytes = base64Decode(saltBase64);

    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: saltBytes,
    );

    final hashBytes = await secretKey.extractBytes();
    return base64Encode(hashBytes);
  }

  /// verifikasi password dengan hash yang disimpan
  /// password - Password plaintext yang akan diverifikasi.
  /// storedHash - Hash yang disimpan dalam format Base64.
  /// saltBase64 - Salt yang digunakan selama hashing asli, dalam format Base64
  Future<bool> verifyPassword(
    String password,
    String storedHash,
    String saltBase64,
  ) async {
    final computedHash = await hashPassword(password, saltBase64);
    return _constantTimeEquals(
      base64Decode(computedHash),
      base64Decode(storedHash),
    );
  }

  /// Constant-time byte array comparison.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
