import 'package:biometric_signature/biometric_signature.dart';
import 'package:flutter/foundation.dart';

class BiometricAuthService {
  final BiometricSignature _biometric;

  BiometricAuthService({BiometricSignature? biometric})
      : _biometric = biometric ?? BiometricSignature();

  // helper untuk generate key alias per user
  String _keyAlias(String userId) => 'nexus_user_$userId';

  /// Check availability
  Future<BiometricAvailabilityResult> checkAvailability() async {
    try {
      final availability = await _biometric.biometricAuthAvailable();
      return BiometricAvailabilityResult(
        isAvailable: availability.canAuthenticate ?? false,
        hasEnrolled: availability.hasEnrolledBiometrics ?? false,
        reason: availability.reason,
      );
    } catch (e) {
      return BiometricAvailabilityResult(
        isAvailable: false,
        hasEnrolled: false,
        reason: 'Error saat memeriksa biometrik: $e',
      );
    }
  }

  /// Enroll biometric saat registrasi
  /// Generates a hardware-backed ECDSA keypair. The public key is returned
  /// for storage with the user account. The private key never leaves
  /// the secure hardware.
  Future<String?> enrollBiometric(String userId) async {
    try {
      final result = await _biometric.createKeys(
        keyAlias: _keyAlias(userId),
        keyFormat: KeyFormat.base64,
        promptMessage: 'Register biometric untuk login',
        config: CreateKeysConfig(
          signatureType: SignatureType.ecdsa,
          enforceBiometric: true,
          setInvalidatedByBiometricEnrollment: true,
          useDeviceCredentials: false,
          enableDecryption: false,
          failIfExists: false, 
        ),
      );

      if (result.code == BiometricError.success) {
        return result.publicKey;
      }

      debugPrint('Pendaftaran biometric gagal: ${result.code} ${result.error}');
      return null;
    } catch (e) {
      debugPrint('Error saat mendaftar biometric: $e');
      return null;
    }
  }

  /// Authenticate user dengan biometric
  Future<BiometricSignatureResult?> authenticate(
    String userId, {
    String? challenge,
  }) async {
    final payload = challenge ?? 'nexus_auth_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final result = await _biometric.createSignature(
        payload: payload,
        keyAlias: _keyAlias(userId),
        promptMessage: 'Authenticate dengan biometric',
        signatureFormat: SignatureFormat.base64,
        keyFormat: KeyFormat.base64,
        config: CreateSignatureConfig(
          allowDeviceCredentials: false,
        ),
      );

      if (result.code == BiometricError.success) {
        return BiometricSignatureResult(
          signature: result.signature ?? '',
          publicKey: result.publicKey ?? '',
          payload: payload,
          success: true,
        );
      }

      debugPrint('Autentikasi biometric gagal: ${result.code} ${result.error}');
      return null;
    } catch (e) {
      debugPrint('Error autentikasi biometric: $e');
      return null;
    }
  }

  /// Simple biometric prompt tanpa signature
  Future<bool> simpleAuthenticate() async {
    try {
      final result = await _biometric.simplePrompt(
        promptMessage: 'Verifikasi dengan biometric',
        config: SimplePromptConfig(
          subtitle: 'NexusNode',
          allowDeviceCredentials: true,
          biometricStrength: BiometricStrength.strong,
        ),
      );
      return result.success == true;
    } catch (e) {
      debugPrint('Simple biometric auth error: $e');
      return false;
    }
  }

  /// cek apakah user sudah enroll biometric
  Future<bool> hasEnrolledKeys(String userId) async {
    try {
      return await _biometric.biometricKeyExists(
        keyAlias: _keyAlias(userId),
        checkValidity: true,
      );
    } catch (e) {
      return false;
    }
  }

  /// hapus key biometric saat user hapus akun
  Future<bool> deleteKeys(String userId) async {
    try {
      return await _biometric.deleteKeys(keyAlias: _keyAlias(userId));
    } catch (e) {
      return false;
    }
  }
}

// class result untuk cek availability biometric
class BiometricAvailabilityResult {
  final bool isAvailable;
  final bool hasEnrolled;
  final String? reason;

  const BiometricAvailabilityResult({
    required this.isAvailable,
    required this.hasEnrolled,
    this.reason,
  });
}

/// class result untuk signature biometric, ada signature, public key, dan payload yang ditandatangani
class BiometricSignatureResult {
  final String signature;
  final String publicKey;
  final String payload;
  final bool success;

  const BiometricSignatureResult({
    required this.signature,
    required this.publicKey,
    required this.payload,
    required this.success,
  });
}
