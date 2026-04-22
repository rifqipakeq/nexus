import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Manages user-scoped Hive boxes to prevent data leakage between accounts.
///
/// ## WHY DATA LEAKAGE HAPPENS IN THE ORIGINAL CODE:
///
/// The original `LocalDatabaseService` uses global box names like `wallet`,
/// `chat`, `game`. When User A logs in, their data is stored in these boxes.
/// When User B logs in, the SAME boxes are reused. User B sees User A's
/// wallet address, chat history, and game scores because the boxes were
/// never cleared or re-scoped.
///
/// Even worse, the `LocalDatabaseService` is a singleton that caches box
/// references in memory. Even after "logout", the old data persists in
/// the open boxes.
///
/// ## HOW THIS SOLUTION GUARANTEES ISOLATION:
///
/// Each user gets uniquely named Hive boxes:
/// ```
/// user_{userId}_wallet
/// user_{userId}_chat
/// user_{userId}_game
/// ```
///
/// The `prices` box remains global because ETH price data is not
/// user-specific — it's the same for everyone.
///
/// ## DATA LIFECYCLE:
///
/// 1. **Login**: `openForUser(userId)` opens user-scoped boxes
/// 2. **Usage**: All reads/writes go through the scoped box references
/// 3. **Logout**: `closeUserBoxes()` flushes and closes all user boxes,
///    then nulls out references. Any subsequent access throws.
/// 4. **Switch**: Close old user's boxes → open new user's boxes
///
/// This guarantees that after logout, no in-memory references to
/// the previous user's data exist.
class UserScopedStorage {
  Box? _walletBox;
  Box? _chatBox;
  Box? _gameBox;
  Box? _pricesBox; // Global, not user-scoped
  String? _currentUserId;

  bool get isInitialized => _currentUserId != null;
  String? get currentUserId => _currentUserId;

  // ─── Initialization ──────────────────────────────────────────────

  /// Open the global prices box (call once at app startup).
  Future<void> initGlobal() async {
    _pricesBox = await Hive.openBox('prices');
  }

  /// Open user-scoped Hive boxes for the given user.
  /// Must be called after login, before accessing any user data.
  Future<void> openForUser(String userId) async {
    // Close any previously open user boxes
    await closeUserBoxes();

    _currentUserId = userId;
    _walletBox = await Hive.openBox('user_${userId}_wallet');
    _chatBox = await Hive.openBox('user_${userId}_chat');
    _gameBox = await Hive.openBox('user_${userId}_game');

    debugPrint('Opened scoped storage for user: $userId');
  }

  /// Flush and close all user-scoped boxes.
  /// Call this on logout to prevent data leakage.
  Future<void> closeUserBoxes() async {
    await _safeClose(_walletBox);
    await _safeClose(_chatBox);
    await _safeClose(_gameBox);

    _walletBox = null;
    _chatBox = null;
    _gameBox = null;
    _currentUserId = null;

    debugPrint('Closed all user-scoped storage');
  }

  /// Close everything including global boxes (app shutdown).
  Future<void> closeAll() async {
    await closeUserBoxes();
    await _safeClose(_pricesBox);
    _pricesBox = null;
  }

  Future<void> _safeClose(Box? box) async {
    if (box != null && box.isOpen) {
      await box.flush();
      await box.close();
    }
  }

  // ─── Box Accessors (with guard) ──────────────────────────────────

  Box get walletBox {
    _ensureUserOpen();
    return _walletBox!;
  }

  Box get chatBox {
    _ensureUserOpen();
    return _chatBox!;
  }

  Box get gameBox {
    _ensureUserOpen();
    return _gameBox!;
  }

  Box get pricesBox {
    if (_pricesBox == null || !_pricesBox!.isOpen) {
      throw StateError('Global storage not initialized. Call initGlobal() first.');
    }
    return _pricesBox!;
  }

  void _ensureUserOpen() {
    if (_currentUserId == null || _walletBox == null || !_walletBox!.isOpen) {
      throw StateError(
        'User-scoped storage not open. Call openForUser() after login.',
      );
    }
  }

  // ─── Prices (Global) ────────────────────────────────────────────

  Future<void> cachePrices(Map<String, double> prices) async {
    await pricesBox.put('eth_usd', prices['usd']);
    await pricesBox.put('eth_idr', prices['idr']);
    await pricesBox.put('last_updated', DateTime.now().toIso8601String());
  }

  Map<String, double> getCachedPrices() {
    return {
      'usd': (pricesBox.get('eth_usd', defaultValue: 0.0) as num).toDouble(),
      'idr': (pricesBox.get('eth_idr', defaultValue: 0.0) as num).toDouble(),
    };
  }

  String? getPricesLastUpdated() => pricesBox.get('last_updated');

  // ─── Wallet (User-Scoped) ───────────────────────────────────────

  Future<void> saveWalletAddress(String address) async {
    await walletBox.put('address', address);
  }

  String? getWalletAddress() => walletBox.get('address');

  Future<void> saveBalance(double balance) async {
    await walletBox.put('balance', balance);
  }

  double getBalance() {
    return (walletBox.get('balance', defaultValue: 0.0) as num).toDouble();
  }

  /// Get the last known balance for notification deduplication.
  double getLastNotifiedBalance() {
    return (walletBox.get('last_notified_balance', defaultValue: 0.0) as num)
        .toDouble();
  }

  Future<void> saveLastNotifiedBalance(double balance) async {
    await walletBox.put('last_notified_balance', balance);
  }

  /// Get the last notified transaction hash for deduplication.
  String? getLastNotifiedTxHash() => walletBox.get('last_notified_tx_hash');

  Future<void> saveLastNotifiedTxHash(String hash) async {
    await walletBox.put('last_notified_tx_hash', hash);
  }

  // ─── Chat History (User-Scoped) ─────────────────────────────────

  Future<void> addChatMessage(Map<String, String> message) async {
    final history = getChatHistory();
    history.add(message);
    await chatBox.put('history', history);
  }

  List<Map<String, String>> getChatHistory() {
    final raw = chatBox.get('history', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  Future<void> clearChatHistory() async {
    await chatBox.put('history', <dynamic>[]);
  }

  // ─── Game Score (User-Scoped) ───────────────────────────────────

  Future<void> saveGameScore(int score) async {
    await gameBox.put('score', score);
  }

  int getGameScore() => gameBox.get('score', defaultValue: 0) as int;

  Future<void> saveHighScore(int score) async {
    final current = getHighScore();
    if (score > current) {
      await gameBox.put('high_score', score);
    }
  }

  int getHighScore() => gameBox.get('high_score', defaultValue: 0) as int;

  Future<void> saveTotalGames(int count) async {
    await gameBox.put('total_games', count);
  }

  int getTotalGames() => gameBox.get('total_games', defaultValue: 0) as int;

  // ─── Transaction History (User-Scoped) ──────────────────────────

  /// Add a transaction record to the user's history.
  Future<void> addTransaction(Map<String, String> tx) async {
    final history = getTransactionHistory();
    // Insert at the beginning so newest transactions appear first.
    history.insert(0, tx);
    await walletBox.put('tx_history', history);
  }

  /// Get all transaction records for the current user, newest first.
  List<Map<String, String>> getTransactionHistory() {
    final raw = walletBox.get('tx_history', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  /// Clear all transaction history for the current user.
  Future<void> clearTransactionHistory() async {
    await walletBox.put('tx_history', <dynamic>[]);
  }
}
