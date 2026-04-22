import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Handles password hashing and verification using PBKDF2-HMAC-SHA256.
///
/// Security properties:
/// - 100,000 iterations (OWASP minimum recommendation for PBKDF2-SHA256)
/// - 32-byte cryptographically random salt per user
/// - 32-byte (256-bit) derived key
/// - Constant-time comparison to prevent timing attacks
class PasswordService {
  /// PBKDF2 iteration count. Higher = slower but more resistant to brute-force.
  /// 100k is the OWASP 2023 minimum for PBKDF2-HMAC-SHA256.
  static const int _iterations = 100000;

  /// Derived key length in bits.
  static const int _bits = 256;

  /// Salt length in bytes.
  static const int _saltLength = 32;

  final Pbkdf2 _pbkdf2;

  PasswordService()
      : _pbkdf2 = Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: _iterations,
          bits: _bits,
        );

  /// Generate a cryptographically secure random salt.
  /// Returns a Base64-encoded string for storage.
  String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Hash a password with the given salt using PBKDF2-HMAC-SHA256.
  ///
  /// [password] - The plaintext password to hash.
  /// [saltBase64] - Base64-encoded salt string.
  /// Returns Base64-encoded hash string.
  Future<String> hashPassword(String password, String saltBase64) async {
    final saltBytes = base64Decode(saltBase64);

    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: saltBytes,
    );

    final hashBytes = await secretKey.extractBytes();
    return base64Encode(hashBytes);
  }

  /// Verify a password against a stored hash using constant-time comparison.
  ///
  /// This method intentionally avoids short-circuit evaluation to prevent
  /// timing attacks that could leak information about which bytes differ.
  ///
  /// [password] - The plaintext password to verify.
  /// [storedHash] - The Base64-encoded stored hash.
  /// [saltBase64] - The Base64-encoded salt used during original hashing.
  /// Returns true if the password matches.
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
  ///
  /// Unlike `==` or `listEquals`, this always compares ALL bytes regardless
  /// of where a mismatch occurs, preventing timing side-channel attacks.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
