class UserAccount {
  final String id;
  final String username;
  final String passwordHash;
  final String salt;
  final String? biometricPublicKey;
  final String createdAt;

  const UserAccount({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.salt,
    this.biometricPublicKey,
    required this.createdAt,
  });

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

  /// buat salinan untuk update data karena immutable
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
