import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/user_account.dart';
import 'password_service.dart';
import 'biometric_auth_service.dart';

/// Result of an authentication operation.
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

/// Manages the full local authentication lifecycle:
/// registration, login, logout, account switching, and session persistence.
///
/// ## Security Architecture
/// - Passwords are hashed with PBKDF2-HMAC-SHA256 (100k iterations)
/// - Per-user random 32-byte salt
/// - Only hashed passwords are stored (Hive box `accounts`)
/// - Active session userId is persisted in Flutter Secure Storage
/// - Biometric keys are hardware-backed (Secure Enclave / StrongBox)
///
/// ## Data Flow
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
  static const String _accountsBoxName = 'accounts';
  static const String _activeUserKey = 'active_user_id';

  final PasswordService _passwordService;
  final BiometricAuthService _biometricService;
  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  Box? _accountsBox;

  AuthService({
    PasswordService? passwordService,
    BiometricAuthService? biometricService,
    FlutterSecureStorage? secureStorage,
  })  : _passwordService = passwordService ?? PasswordService(),
        _biometricService = biometricService ?? BiometricAuthService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = const Uuid();

  /// Initialize the accounts Hive box. Must be called before any operations.
  Future<void> init() async {
    _accountsBox ??= await Hive.openBox(_accountsBoxName);
  }

  /// Ensure the box is open, or throw.
  Box get _box {
    if (_accountsBox == null || !_accountsBox!.isOpen) {
      throw StateError('AuthService not initialized. Call init() first.');
    }
    return _accountsBox!;
  }

  // ─── Registration ────────────────────────────────────────────────

  /// Register a new local user account.
  ///
  /// 1. Validates username uniqueness (case-insensitive)
  /// 2. Generates a random salt
  /// 3. Hashes the password with PBKDF2
  /// 4. Optionally enrolls biometric keys
  /// 5. Stores the account in Hive
  /// 6. Sets this user as the active session
  Future<AuthResult> register({
    required String username,
    required String password,
    bool enrollBiometric = true,
  }) async {
    // Validate input
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) {
      return AuthResult.failure('Username cannot be empty');
    }
    if (trimmedUsername.length < 3) {
      return AuthResult.failure('Username must be at least 3 characters');
    }
    if (password.length < 6) {
      return AuthResult.failure('Password must be at least 6 characters');
    }

    // Check uniqueness (case-insensitive)
    final existing = _findUserByUsername(trimmedUsername);
    if (existing != null) {
      return AuthResult.failure('Username already exists');
    }

    // Generate credentials
    final userId = _uuid.v4();
    final salt = _passwordService.generateSalt();
    final passwordHash = await _passwordService.hashPassword(password, salt);

    // Enroll biometric (optional, fails gracefully)
    String? biometricPublicKey;
    if (enrollBiometric) {
      final availability = await _biometricService.checkAvailability();
      if (availability.isAvailable && availability.hasEnrolled) {
        biometricPublicKey = await _biometricService.enrollBiometric(userId);
      }
    }

    // Create account
    final account = UserAccount(
      id: userId,
      username: trimmedUsername,
      passwordHash: passwordHash,
      salt: salt,
      biometricPublicKey: biometricPublicKey,
      createdAt: DateTime.now().toIso8601String(),
    );

    // Persist
    await _box.put(userId, account.toMap());
    await _setActiveUser(userId);

    debugPrint('User registered: $trimmedUsername ($userId)');
    return AuthResult.ok(account);
  }

  // ─── Login ───────────────────────────────────────────────────────

  /// Authenticate a user with username and password.
  ///
  /// Uses constant-time comparison on the PBKDF2 hash to prevent
  /// timing attacks that could reveal whether a partial password
  /// is correct.
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final account = _findUserByUsername(username.trim());
    if (account == null) {
      // Hash the password anyway to prevent timing-based username enumeration.
      // This ensures the response time is similar whether the user exists or not.
      await _passwordService.hashPassword(password, _passwordService.generateSalt());
      return AuthResult.failure('Invalid username or password');
    }

    final isValid = await _passwordService.verifyPassword(
      password,
      account.passwordHash,
      account.salt,
    );

    if (!isValid) {
      return AuthResult.failure('Invalid username or password');
    }

    await _setActiveUser(account.id);
    debugPrint('User logged in: ${account.username}');
    return AuthResult.ok(account);
  }

  /// Authenticate using biometric only (for returning users / session resume).
  Future<AuthResult> loginWithBiometric(String userId) async {
    final account = getUserById(userId);
    if (account == null) {
      return AuthResult.failure('Account not found');
    }

    if (account.biometricPublicKey == null) {
      return AuthResult.failure('No biometric enrolled for this account');
    }

    final result = await _biometricService.authenticate(userId);
    if (result == null || !result.success) {
      return AuthResult.failure('Biometric authentication failed');
    }

    await _setActiveUser(account.id);
    return AuthResult.ok(account);
  }

  // ─── Logout ──────────────────────────────────────────────────────

  /// Log out the current user. Clears the active session.
  Future<void> logout() async {
    await _secureStorage.delete(key: _activeUserKey);
    debugPrint('User logged out');
  }

  // ─── Account Switching ───────────────────────────────────────────

  /// Switch to a different registered account.
  /// The caller is responsible for reloading user-scoped data.
  Future<AuthResult> switchAccount(String userId) async {
    final account = getUserById(userId);
    if (account == null) {
      return AuthResult.failure('Account not found');
    }

    await _setActiveUser(userId);
    debugPrint('Switched to: ${account.username}');
    return AuthResult.ok(account);
  }

  // ─── Session Persistence ─────────────────────────────────────────

  /// Get the currently active user ID from secure storage.
  /// Returns null if no session exists (user must log in).
  Future<String?> getActiveUserId() async {
    return _secureStorage.read(key: _activeUserKey);
  }

  /// Get the currently active user account, if a session exists.
  Future<UserAccount?> getActiveUser() async {
    final userId = await getActiveUserId();
    if (userId == null) return null;
    return getUserById(userId);
  }

  /// Check if there is an active session.
  Future<bool> hasActiveSession() async {
    final userId = await getActiveUserId();
    return userId != null && getUserById(userId) != null;
  }

  // ─── Account Management ──────────────────────────────────────────

  /// Get all registered accounts.
  List<UserAccount> getAllAccounts() {
    return _box.values
        .map((v) => UserAccount.fromMap(v as Map<dynamic, dynamic>))
        .toList();
  }

  /// Get a specific account by ID.
  UserAccount? getUserById(String userId) {
    final data = _box.get(userId);
    if (data == null) return null;
    return UserAccount.fromMap(data as Map<dynamic, dynamic>);
  }

  /// Update a user's biometric public key (e.g., after re-enrollment).
  Future<void> updateBiometricKey(String userId, String? publicKey) async {
    final account = getUserById(userId);
    if (account == null) return;
    final updated = account.copyWith(biometricPublicKey: publicKey);
    await _box.put(userId, updated.toMap());
  }

  /// Delete a user account and their biometric keys.
  Future<void> deleteAccount(String userId) async {
    await _biometricService.deleteKeys(userId);
    await _box.delete(userId);

    // If this was the active user, clear session
    final activeId = await getActiveUserId();
    if (activeId == userId) {
      await logout();
    }
  }

  /// Check if any accounts exist (for first-launch detection).
  bool get hasAccounts => _box.isNotEmpty;

  // ─── Helpers ─────────────────────────────────────────────────────

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
