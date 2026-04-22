import 'package:biometric_signature/biometric_signature.dart';
import 'package:flutter/foundation.dart';

/// Wraps the `biometric_signature` package to provide hardware-backed
/// biometric authentication with cryptographic proof.
///
/// Key differences from `local_auth`:
/// - `local_auth` returns a boolean → easily spoofed by API hooking.
/// - `biometric_signature` produces a cryptographic signature using a
///   private key stored in hardware (Secure Enclave / StrongBox / TPM).
///   The signature can be verified against the stored public key.
///
/// This service manages per-user biometric key aliases so each account
/// has its own hardware-backed keypair.
class BiometricAuthService {
  final BiometricSignature _biometric;

  BiometricAuthService({BiometricSignature? biometric})
      : _biometric = biometric ?? BiometricSignature();

  /// Construct a key alias scoped to a specific user.
  /// Each user gets their own hardware-backed keypair.
  String _keyAlias(String userId) => 'nexus_user_$userId';

  /// Check if biometric hardware is available on this device.
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
        reason: 'Error checking biometrics: $e',
      );
    }
  }

  /// Enroll biometric keys for a user during registration.
  ///
  /// Generates a hardware-backed ECDSA keypair. The public key is returned
  /// for storage with the user account. The private key never leaves
  /// the secure hardware.
  ///
  /// Returns the Base64-encoded public key, or null if enrollment failed.
  Future<String?> enrollBiometric(String userId) async {
    try {
      final result = await _biometric.createKeys(
        keyAlias: _keyAlias(userId),
        keyFormat: KeyFormat.base64,
        promptMessage: 'Register your biometric for NexusNode',
        config: CreateKeysConfig(
          signatureType: SignatureType.ecdsa,
          enforceBiometric: true,
          setInvalidatedByBiometricEnrollment: true,
          useDeviceCredentials: false,
          enableDecryption: false,
          failIfExists: false, // Allow re-enrollment
        ),
      );

      if (result.code == BiometricError.success) {
        return result.publicKey;
      }

      debugPrint('Biometric enrollment failed: ${result.code} ${result.error}');
      return null;
    } catch (e) {
      debugPrint('Biometric enrollment error: $e');
      return null;
    }
  }

  /// Authenticate a user using their biometric.
  ///
  /// Creates a cryptographic signature of a challenge payload using the
  /// hardware-backed private key. This proves the biometric owner is
  /// genuinely present — unlike `local_auth` which only returns a boolean.
  ///
  /// [userId] - The user to authenticate.
  /// [challenge] - A unique payload to sign (prevents replay attacks).
  ///
  /// Returns the signature result, or null if authentication failed.
  Future<BiometricSignatureResult?> authenticate(
    String userId, {
    String? challenge,
  }) async {
    final payload = challenge ?? 'nexus_auth_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final result = await _biometric.createSignature(
        payload: payload,
        keyAlias: _keyAlias(userId),
        promptMessage: 'Authenticate to access NexusNode',
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

      debugPrint('Biometric auth failed: ${result.code} ${result.error}');
      return null;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return null;
    }
  }

  /// Simple biometric prompt without cryptographic operations.
  /// Useful for quick re-authentication (e.g., session resume).
  Future<bool> simpleAuthenticate() async {
    try {
      final result = await _biometric.simplePrompt(
        promptMessage: 'Verify your identity',
        config: SimplePromptConfig(
          subtitle: 'NexusNode Lite',
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

  /// Check if a user has enrolled biometric keys.
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

  /// Delete biometric keys for a user (e.g., account deletion).
  Future<bool> deleteKeys(String userId) async {
    try {
      return await _biometric.deleteKeys(keyAlias: _keyAlias(userId));
    } catch (e) {
      return false;
    }
  }
}

/// Result of a biometric availability check.
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

/// Result of a biometric signature operation.
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
