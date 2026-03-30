import 'package:hive/hive.dart';
import '../../core/constants.dart';

/// Local database service using Hive.
/// Stores: cached prices, wallet address, chat history, game score.
class LocalDatabaseService {
  // Singleton
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  late Box _pricesBox;
  late Box _walletBox;
  late Box _chatBox;
  late Box _gameBox;
  bool _initialized = false;

  /// Initialize all Hive boxes.
  Future<void> init() async {
    if (_initialized) return;
    _pricesBox = await Hive.openBox(AppConstants.hiveBoxPrices);
    _walletBox = await Hive.openBox(AppConstants.hiveBoxWallet);
    _chatBox = await Hive.openBox(AppConstants.hiveBoxChat);
    _gameBox = await Hive.openBox(AppConstants.hiveBoxGame);
    _initialized = true;
  }

  // ─── Prices ───────────────────────────────────────────────────

  Future<void> cachePrices(Map<String, double> prices) async {
    await _pricesBox.put('eth_usd', prices['usd']);
    await _pricesBox.put('eth_idr', prices['idr']);
    await _pricesBox.put('last_updated', DateTime.now().toIso8601String());
  }

  Map<String, double> getCachedPrices() {
    return {
      'usd': (_pricesBox.get('eth_usd', defaultValue: 0.0) as num).toDouble(),
      'idr': (_pricesBox.get('eth_idr', defaultValue: 0.0) as num).toDouble(),
    };
  }

  String? getPricesLastUpdated() {
    return _pricesBox.get('last_updated');
  }

  // ─── Wallet ───────────────────────────────────────────────────

  Future<void> saveWalletAddress(String address) async {
    await _walletBox.put('address', address);
  }

  String? getWalletAddress() {
    return _walletBox.get('address');
  }

  Future<void> saveBalance(double balance) async {
    await _walletBox.put('balance', balance);
  }

  double getBalance() {
    return (_walletBox.get('balance', defaultValue: 0.0) as num).toDouble();
  }

  // ─── Chat History ─────────────────────────────────────────────

  Future<void> addChatMessage(Map<String, String> message) async {
    final history = getChatHistory();
    history.add(message);
    await _chatBox.put('history', history);
  }

  List<Map<String, String>> getChatHistory() {
    final raw = _chatBox.get('history', defaultValue: <dynamic>[]);
    return (raw as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  Future<void> clearChatHistory() async {
    await _chatBox.put('history', <dynamic>[]);
  }

  // ─── Game Score ───────────────────────────────────────────────

  Future<void> saveGameScore(int score) async {
    await _gameBox.put('score', score);
  }

  int getGameScore() {
    return _gameBox.get('score', defaultValue: 0) as int;
  }

  Future<void> saveHighScore(int score) async {
    final current = getHighScore();
    if (score > current) {
      await _gameBox.put('high_score', score);
    }
  }

  int getHighScore() {
    return _gameBox.get('high_score', defaultValue: 0) as int;
  }

  Future<void> saveTotalGames(int count) async {
    await _gameBox.put('total_games', count);
  }

  int getTotalGames() {
    return _gameBox.get('total_games', defaultValue: 0) as int;
  }
}
