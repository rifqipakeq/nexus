import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/constants.dart';

/// Handles AES encryption/decryption, biometric auth, and secure storage.
class SecurityService {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  SecurityService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _localAuth = localAuth ?? LocalAuthentication();

  // ─── AES Encryption ───────────────────────────────────────────

  /// Generates and persists a random AES-256 key + IV if not already stored.
  Future<void> ensureEncryptionKeys() async {
    final existingKey = await _secureStorage.read(
      key: AppConstants.secureKeyAesKey,
    );
    if (existingKey != null) return;

    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final ivBytes = List<int>.generate(16, (_) => random.nextInt(256));

    await _secureStorage.write(
      key: AppConstants.secureKeyAesKey,
      value: base64Encode(keyBytes),
    );
    await _secureStorage.write(
      key: AppConstants.secureKeyAesIv,
      value: base64Encode(ivBytes),
    );
  }

  Future<encrypt_pkg.Key> _getKey() async {
    final encoded = await _secureStorage.read(
      key: AppConstants.secureKeyAesKey,
    );
    return encrypt_pkg.Key.fromBase64(encoded!);
  }

  Future<encrypt_pkg.IV> _getIV() async {
    final encoded = await _secureStorage.read(key: AppConstants.secureKeyAesIv);
    return encrypt_pkg.IV.fromBase64(encoded!);
  }

  /// Encrypt plaintext using AES-256 CBC.
  Future<String> encryptData(String plainText) async {
    final key = await _getKey();
    final iv = await _getIV();
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  /// Decrypt AES-256 CBC ciphertext.
  Future<String> decryptData(String encryptedBase64) async {
    final key = await _getKey();
    final iv = await _getIV();
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc),
    );
    return encrypter.decrypt64(encryptedBase64, iv: iv);
  }

  // ─── Biometric Auth ───────────────────────────────────────────

  /// Check if device supports biometrics.
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Prompt biometric authentication.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access NexusNode Lite',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ─── Secure Storage Helpers ───────────────────────────────────

  Future<void> saveSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> readSecure(String key) async {
    return _secureStorage.read(key: key);
  }

  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
