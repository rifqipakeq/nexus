import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../core/constants.dart';

class UserScopedStorage {
  Box? _walletBox;
  Box? _chatBox;
  Box? _gameBox;
  Box? _tokensBox; 
  Box? _pricesBox;
  String? _currentUserId;

  bool get isInitialized => _currentUserId != null;
  String? get currentUserId => _currentUserId;
  bool get isTokensBoxOpen => _tokensBox != null && _tokensBox!.isOpen;

  Future<void> initGlobal() async {
    _pricesBox = await Hive.openBox('prices');
  }

  Future<void> openForUser(String userId) async {
    await closeUserBoxes();

    _currentUserId = userId;
    _walletBox = await Hive.openBox('user_${userId}_wallet');
    _chatBox = await Hive.openBox('user_${userId}_chat');
    _gameBox = await Hive.openBox('user_${userId}_game');
    _tokensBox = await Hive.openBox(AppConstants.userTokensBox(userId));

    debugPrint('Box untuk user: $userId');
  }

  Future<void> closeUserBoxes() async {
    await _safeClose(_walletBox);
    await _safeClose(_chatBox);
    await _safeClose(_gameBox);
    await _safeClose(_tokensBox);

    _walletBox = null;
    _chatBox = null;
    _gameBox = null;
    _tokensBox = null;
    _currentUserId = null;

    debugPrint('Tutup semua box user, siap untuk login user lain');
  }

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

  Box get tokensBox {
    _ensureUserOpen();
    if (_tokensBox == null || !_tokensBox!.isOpen) {
      throw StateError('Tokens box belum diinisialisasi!');
    }
    return _tokensBox!;
  }

  Box get pricesBox {
    if (_pricesBox == null || !_pricesBox!.isOpen) {
      throw StateError(
        'Price box belum diinisialisasi!. Pastikan initGlobal() dipanggil saat start app.',
      );
    }
    return _pricesBox!;
  }

  void _ensureUserOpen() {
    if (_currentUserId == null || _walletBox == null || !_walletBox!.isOpen) {
      throw StateError('Data user belum diinisialisasi!');
    }
  }


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

  String? getLastNotifiedTxHash() => walletBox.get('last_notified_tx_hash');

  Future<void> saveLastNotifiedTxHash(String hash) async {
    await walletBox.put('last_notified_tx_hash', hash);
  }


  Future<void> saveTxHistoryV2(List<Map<String, dynamic>> txs) async {
    await walletBox.put(AppConstants.keyTxHistoryV2, txs);
    await walletBox.put(
      AppConstants.keyTxLastFetched,
      DateTime.now().toIso8601String(),
    );
  }

  List<Map<String, dynamic>> getTxHistoryV2() {
    final raw = walletBox.get(
      AppConstants.keyTxHistoryV2,
      defaultValue: <dynamic>[],
    );
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> clearTxHistoryV2() async {
    await walletBox.put(AppConstants.keyTxHistoryV2, <dynamic>[]);
    await walletBox.delete(AppConstants.keyTxLastFetched);
  }

  String? getTxLastFetched() =>
      walletBox.get(AppConstants.keyTxLastFetched) as String?;

  // ─── Legacy transaction history (kept for backward compat) ────────────────

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


  bool get isPremium =>
      walletBox.get(AppConstants.keyIsPremium, defaultValue: false) as bool;

  Future<void> savePremiumStatus(bool status) async {
    await walletBox.put(AppConstants.keyIsPremium, status);
  }

  int getQuizTokens() =>
      (walletBox.get(AppConstants.keyQuizTokens, defaultValue: 0) as num)
          .toInt();

  Future<void> saveQuizTokens(int tokens) async {
    await walletBox.put(AppConstants.keyQuizTokens, tokens);
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
