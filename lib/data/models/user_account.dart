/// Data model representing a locally-stored user account.
///
/// Passwords are NEVER stored in plaintext. Only the [passwordHash]
/// (derived via PBKDF2-HMAC-SHA256) and the [salt] used for derivation
/// are persisted. The biometric public key is stored so the app can
/// verify cryptographic signatures produced by the hardware-backed
/// biometric key.
class UserAccount {
  /// Unique user identifier (UUID v4).
  final String id;

  /// Human-readable username (unique, case-insensitive).
  final String username;

  /// Base64-encoded PBKDF2-HMAC-SHA256 hash of the password.
  final String passwordHash;

  /// Base64-encoded random salt (32 bytes) used during hashing.
  final String salt;

  /// Base64-encoded public key from biometric enrollment.
  /// Null if user has not enrolled biometrics.
  final String? biometricPublicKey;

  /// ISO 8601 creation timestamp.
  final String createdAt;

  const UserAccount({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.salt,
    this.biometricPublicKey,
    required this.createdAt,
  });

  /// Serialize to a Map for Hive storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'passwordHash': passwordHash,
      'salt': salt,
      'biometricPublicKey': biometricPublicKey,
      'createdAt': createdAt,
    };
  }

  /// Deserialize from a Hive-stored Map.
  factory UserAccount.fromMap(Map<dynamic, dynamic> map) {
    return UserAccount(
      id: map['id'] as String,
      username: map['username'] as String,
      passwordHash: map['passwordHash'] as String,
      salt: map['salt'] as String,
      biometricPublicKey: map['biometricPublicKey'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }

  /// Create a copy with optional field overrides.
  UserAccount copyWith({
    String? id,
    String? username,
    String? passwordHash,
    String? salt,
    String? biometricPublicKey,
    String? createdAt,
  }) {
    return UserAccount(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      biometricPublicKey: biometricPublicKey ?? this.biometricPublicKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'UserAccount(id: $id, username: $username)';
}
