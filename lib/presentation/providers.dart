import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/security_service.dart';
import '../data/services/api_service.dart';
import '../data/services/blockchain_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/location_service.dart';
import '../data/services/motion_service.dart';
import '../data/services/gemini_service.dart';
import '../data/services/price_service.dart';
import '../data/local/local_database_service.dart';

// ─── Service Providers ──────────────────────────────────────────

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final blockchainServiceProvider = Provider<BlockchainService>((ref) {
  return BlockchainService(ref.read(securityServiceProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final motionServiceProvider = Provider<MotionService>((ref) {
  return MotionService();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final priceServiceProvider = Provider<PriceService>((ref) {
  return PriceService(ref.read(apiServiceProvider));
});

final localDbProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService();
});

// ─── Auth State ─────────────────────────────────────────────────

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(firebaseAuthProvider).authStateChanges();
});

// ─── Wallet State ───────────────────────────────────────────────

final walletAddressProvider = StateProvider<String?>((ref) {
  return ref.read(localDbProvider).getWalletAddress();
});

final walletBalanceProvider = StateProvider<double>((ref) {
  return ref.read(localDbProvider).getBalance();
});

final balanceVisibleProvider = StateProvider<bool>((ref) => true);

// ─── Price State ────────────────────────────────────────────────

final ethPriceProvider = StateProvider<Map<String, double>>((ref) {
  return ref.read(localDbProvider).getCachedPrices();
});

// ─── Location State ─────────────────────────────────────────────

final isInSafeZoneProvider = StateProvider<bool>((ref) => false);

// ─── Chat State ─────────────────────────────────────────────────

final chatHistoryProvider = StateProvider<List<Map<String, String>>>((ref) {
  return ref.read(localDbProvider).getChatHistory();
});

final chatLoadingProvider = StateProvider<bool>((ref) => false);

// ─── Game State ─────────────────────────────────────────────────

final gameScoreProvider = StateProvider<int>((ref) {
  return ref.read(localDbProvider).getGameScore();
});

final highScoreProvider = StateProvider<int>((ref) {
  return ref.read(localDbProvider).getHighScore();
});

final totalGamesProvider = StateProvider<int>((ref) {
  return ref.read(localDbProvider).getTotalGames();
});
