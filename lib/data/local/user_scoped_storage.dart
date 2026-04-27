import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../core/constants.dart';

class UserScopedStorage {
  Box? _walletBox;
  Box? _chatBox;
  Box? _gameBox;
  Box? _pricesBox;
  String? _currentUserId;

  // Cek apakah user sudah pernah login
  bool get isInitialized => _currentUserId != null;
  String? get currentUserId => _currentUserId;

  /// Init price box sebagai global variable
  Future<void> initGlobal() async {
    _pricesBox = await Hive.openBox('prices');
  }

  /// Init data unik tiap user, diakses setelah login
  Future<void> openForUser(String userId) async {
    // Close  data user sebelumnya
    await closeUserBoxes();

    _currentUserId = userId;
    _walletBox = await Hive.openBox('user_${userId}_wallet');
    _chatBox = await Hive.openBox('user_${userId}_chat');
    _gameBox = await Hive.openBox('user_${userId}_game');

    debugPrint('Box untuk user: $userId');
  }

  /// Tutup semua box yang terkait user saat logout
  /// data masih namun cuman bisa akses oleh user terkait
  Future<void> closeUserBoxes() async {
    await _safeClose(_walletBox);
    await _safeClose(_chatBox);
    await _safeClose(_gameBox);

    _walletBox = null;
    _chatBox = null;
    _gameBox = null;
    _currentUserId = null;

    debugPrint('Tutup semua box user, siap untuk login user lain');
  }

  /// Tutup semua box saat app shutdown
  Future<void> closeAll() async {
    await closeUserBoxes();
    await _safeClose(_pricesBox);
    _pricesBox = null;
  }

  // soft close
  Future<void> _safeClose(Box? box) async {
    if (box != null && box.isOpen) {
      await box.flush();
      await box.close();
    }
  }

  // Box accessors
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
      throw StateError(
        'Price box belum diinisialisasi!. Pastikan initGlobal() dipanggil saat start app.',
      );
    }
    return _pricesBox!;
  }

  // Mekanisme untuk memastikan box user sudah dibuka sebelum data diakses
  void _ensureUserOpen() {
    if (_currentUserId == null || _walletBox == null || !_walletBox!.isOpen) {
      throw StateError('Data user belum diinisialisasi!');
    }
  }

  // Price global var, idr, usd, cny
  // pakai cache untuk mengurangi loading dan offline support
  Future<void> cachePrices(Map<String, double> prices) async {
    await pricesBox.put('eth_usd', prices['usd']);
    await pricesBox.put('eth_idr', prices['idr']);
    await pricesBox.put('eth_cny', prices['cny']);
    await pricesBox.put('last_updated', DateTime.now().toIso8601String());
  }

  Map<String, double> getCachedPrices() {
    return {
      'usd': (pricesBox.get('eth_usd', defaultValue: 0.0) as num).toDouble(),
      'idr': (pricesBox.get('eth_idr', defaultValue: 0.0) as num).toDouble(),
      'cny': (pricesBox.get('eth_cny', defaultValue: 0.0) as num).toDouble(),
    };
  }

  String? getPricesLastUpdated() => pricesBox.get('last_updated');

  // Wallet data (user-scoped)
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

  double getLastNotifiedBalance() {
    return (walletBox.get('last_notified_balance', defaultValue: 0.0) as num)
        .toDouble();
  }

  Future<void> saveLastNotifiedBalance(double balance) async {
    await walletBox.put('last_notified_balance', balance);
  }

  /// Cek notifikasi terakhir, kalo sama tidak perlu kirim notifikasi lagi
  String? getLastNotifiedTxHash() => walletBox.get('last_notified_tx_hash');

  Future<void> saveLastNotifiedTxHash(String hash) async {
    await walletBox.put('last_notified_tx_hash', hash);
  }

  // Chat History (User-Scoped)
  Future<void> addChatMessage(Map<String, String> message) async {
    final history = getChatHistory();
    // tidak pakai append karena nosql
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

  // Game Score (User-Scoped)
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

  // Transaction History (User-Scoped)
  Future<void> addTransaction(Map<String, String> tx) async {
    final history = getTransactionHistory();
    history.insert(0, tx);
    await walletBox.put('tx_history', history);
  }

  List<Map<String, String>> getTransactionHistory() {
    final raw = walletBox.get('tx_history', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  Future<void> clearTransactionHistory() async {
    await walletBox.put('tx_history', <dynamic>[]);
  }

  Future<void> saveSafeZones(List<Map<String, dynamic>> zones) async {
    await walletBox.put(AppConstants.userSafeZonesKey, zones);
    if (zones.isNotEmpty) {
      await walletBox.put(AppConstants.userHasConfiguredZonesKey, true);
    }
  }

  List<Map<String, dynamic>> getSafeZones() {
    final raw = walletBox.get(
      AppConstants.userSafeZonesKey,
      defaultValue: <dynamic>[],
    );
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> clearSafeZones() async {
    await walletBox.put(AppConstants.userSafeZonesKey, <dynamic>[]);
  }

  bool getHasConfiguredZones() {
    return walletBox.get(
          AppConstants.userHasConfiguredZonesKey,
          defaultValue: false,
        ) as bool;
  }

  Future<void> saveSelectedTimezone(String tzName) async {
    await walletBox.put(AppConstants.userTimezoneKey, tzName);
  }

  String getSelectedTimezone() {
    return walletBox.get(
      AppConstants.userTimezoneKey,
      defaultValue: 'Asia/Jakarta',
    ) as String;
  }
}
