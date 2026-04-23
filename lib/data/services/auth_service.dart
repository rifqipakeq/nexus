import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/user_account.dart';
import 'password_service.dart';
import 'biometric_auth_service.dart';

class AuthResult {
  final bool success;
  final String? error;
  final UserAccount? user;

  const AuthResult({required this.success, this.error, this.user});

  factory AuthResult.failure(String error) =>
      AuthResult(success: false, error: error);

  factory AuthResult.ok(UserAccount user) =>
      AuthResult(success: true, user: user);
}

/// FLOW DATA
/// ```
/// Register → validate → salt + hash password → create biometric keys
///   → store UserAccount in Hive → set active session
///
/// Login → find user → hash input password with stored salt
///   → constant-time compare → optional biometric → set active session
///
/// Logout → clear session from secure storage → return to login
///
/// Switch → set new active userId → caller handles data reload
/// ```

class AuthService {
  static const String _accountsBoxName = 'accounts'; // box untuk akun user
  static const String _activeUserKey =
      'active_user_id'; // key untuk session aktif di secure storage

  final PasswordService _passwordService;
  final BiometricAuthService _biometricService;
  final FlutterSecureStorage _secureStorage; // session
  final Uuid _uuid;

  Box? _accountsBox;

  AuthService({
    PasswordService? passwordService,
    BiometricAuthService? biometricService,
    FlutterSecureStorage? secureStorage,
  }) : _passwordService = passwordService ?? PasswordService(),
       _biometricService = biometricService ?? BiometricAuthService(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _uuid = const Uuid();

  Future<void> init() async {
    _accountsBox ??= await Hive.openBox(_accountsBoxName);
  }

  /// make sure box sudah di init sebelum akses data
  Box get _box {
    if (_accountsBox == null || !_accountsBox!.isOpen) {
      throw StateError('AuthService belum terinisialisasi!');
    }
    return _accountsBox!;
  }

  // Registration
  /// 1. validasi username wajib
  /// 2. Generates salt
  /// 3. Hashes password PBKDF2
  /// 4. optional login biometric
  /// 5. simpan data akun ke box hive
  /// 6. session aktif untuk user terkait

  Future<AuthResult> register({
    required String username,
    required String password,
    bool enrollBiometric = true,
  }) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) {
      return AuthResult.failure('Username tidak boleh kosong!');
    }
    if (trimmedUsername.length < 3) {
      return AuthResult.failure('Username minimal 3 karakter!');
    }
    if (password.length < 6) {
      return AuthResult.failure('Password minimal 6 karakter!');
    }

    // check username
    final existing = _findUserByUsername(trimmedUsername);
    if (existing != null) {
      return AuthResult.failure('Username sudah ada. Buat username lain!');
    }

    // Generate credentials, salt,hash
    final userId = _uuid.v4();
    final salt = _passwordService.generateSalt();
    final passwordHash = await _passwordService.hashPassword(password, salt);

    // daftar biometric (opsional)
    String? biometricPublicKey;
    if (enrollBiometric) {
      final availability = await _biometricService.checkAvailability();
      if (availability.isAvailable && availability.hasEnrolled) {
        biometricPublicKey = await _biometricService.enrollBiometric(userId);
      }
    }

    // buat akun
    final account = UserAccount(
      id: userId,
      username: trimmedUsername,
      passwordHash: passwordHash,
      salt: salt,
      biometricPublicKey: biometricPublicKey,
      createdAt: DateTime.now().toIso8601String(),
    );

    // tampan akun ke Hive dan set session aktif
    await _box.put(userId, account.toMap());
    await _setActiveUser(userId);

    debugPrint('Username sukses terdaftar: $trimmedUsername ($userId)');
    return AuthResult.ok(account);
  }

  // Login
  /// 1. cari username
  /// 2. jika tidak ada, hash password dengan salt random untuk cegah timing attack
  /// 3. jika ada, hash password input dengan salt yang disimpan
  /// 4. jika valid, optional biometric auth untuk keamanan tambahan
  /// 5. set session aktif untuk user terkait
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final account = _findUserByUsername(username.trim());
    if (account == null) {
      await _passwordService.hashPassword(
        password,
        _passwordService.generateSalt(),
      );
      return AuthResult.failure('Invalid username atau password');
    }

    final isValid = await _passwordService.verifyPassword(
      password,
      account.passwordHash,
      account.salt,
    );

    if (!isValid) {
      return AuthResult.failure('Invalid username atau password');
    }

    await _setActiveUser(account.id);
    debugPrint('User loggin: ${account.username}');
    return AuthResult.ok(account);
  }

  /// Biometric
  /// 1. Cari akun berdasarkan userId
  /// 2. Jika akun tidak ditemukan atau tidak memiliki biometric, gagal
  /// 3. Panggil service biometric untuk autentikasi
  /// 4. Jika berhasil, set session aktif untuk user terkait
  Future<AuthResult> loginWithBiometric(String userId) async {
    final account = getUserById(userId);
    if (account == null) {
      return AuthResult.failure('Akun tidak ditemukan');
    }

    if (account.biometricPublicKey == null) {
      return AuthResult.failure('Tidak ada data biometric untuk akun ini');
    }

    final result = await _biometricService.authenticate(userId);
    if (result == null || !result.success) {
      return AuthResult.failure('Autentikasi biometric gagal');
    }

    await _setActiveUser(account.id);
    return AuthResult.ok(account);
  }

  // Logout
  Future<void> logout() async {
    await _secureStorage.delete(key: _activeUserKey);
    debugPrint('User logout');
  }

  // Ganti akun
  // 1. Cari akun berdasarkan userId
  // 2. Jika akun tidak ditemukan, gagal
  // 3. Jika ditemukan, set session aktif untuk user terkait
  Future<AuthResult> switchAccount(String userId) async {
    final account = getUserById(userId);
    if (account == null) {
      return AuthResult.failure('Akun tidak ditemukan');
    }

    await _setActiveUser(userId);
    debugPrint('Beralih ke: ${account.username}');
    return AuthResult.ok(account);
  }

  // Session
  // 1. Ambil userId aktif dari secure storage
  // 2. Jika tidak ada, berarti tidak ada session aktif
  // 3. Jika ada, ambil data akun terkait untuk akses informasi user
  Future<String?> getActiveUserId() async {
    return _secureStorage.read(key: _activeUserKey);
  }

  Future<UserAccount?> getActiveUser() async {
    final userId = await getActiveUserId();
    if (userId == null) return null;
    return getUserById(userId);
  }

  /// cek apa ada session aktif
  Future<bool> hasActiveSession() async {
    final userId = await getActiveUserId();
    return userId != null && getUserById(userId) != null;
  }

  // Manage akun
  List<UserAccount> getAllAccounts() {
    return _box.values
        .map((v) => UserAccount.fromMap(v as Map<dynamic, dynamic>))
        .toList();
  }

  UserAccount? getUserById(String userId) {
    final data = _box.get(userId);
    if (data == null) return null;
    return UserAccount.fromMap(data as Map<dynamic, dynamic>);
  }

  /// update data biometric
  Future<void> updateBiometricKey(String userId, String? publicKey) async {
    final account = getUserById(userId);
    if (account == null) return;
    final updated = account.copyWith(biometricPublicKey: publicKey);
    await _box.put(userId, updated.toMap());
  }

  /// hapus akun, termasuk data biometric dan sesi jika aktif
  Future<void> deleteAccount(String userId) async {
    await _biometricService.deleteKeys(userId);
    await _box.delete(userId);

    // jika user aktif, logout untuk clear session
    final activeId = await getActiveUserId();
    if (activeId == userId) {
      await logout();
    }
  }

  // cek apakah ada akun yang terdaftar, untuk first launch logic
  bool get hasAccounts => _box.isNotEmpty;

  // Helpers
  Future<void> _setActiveUser(String userId) async {
    await _secureStorage.write(key: _activeUserKey, value: userId);
  }

  UserAccount? _findUserByUsername(String username) {
    final lowerUsername = username.toLowerCase();
    try {
      final data = _box.values.firstWhere(
        (v) => (v as Map)['username'].toString().toLowerCase() == lowerUsername,
      );
      return UserAccount.fromMap(data as Map<dynamic, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
