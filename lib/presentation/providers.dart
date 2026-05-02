import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_account.dart';
import '../data/models/tx_record.dart';
import '../data/models/token_balance.dart';
import '../data/services/security_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/password_service.dart';
import '../data/services/biometric_auth_service.dart';
import '../data/services/api_service.dart';
import '../data/services/blockchain_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/location_service.dart';
import '../data/services/motion_service.dart';
import '../data/services/gemini_service.dart';
import '../data/services/price_service.dart';
import '../data/services/transaction_service.dart';
import '../data/services/token_service.dart';
import '../data/services/swap_service.dart';
import '../data/services/quiz_service.dart';
import '../data/local/user_scoped_storage.dart';

// ─── Core Service Providers ───────────────────────────────────────────────────

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final passwordServiceProvider = Provider<PasswordService>((ref) {
  return PasswordService();
});

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    passwordService: ref.read(passwordServiceProvider),
    biometricService: ref.read(biometricAuthServiceProvider),
  );
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

final userScopedStorageProvider = Provider<UserScopedStorage>((ref) {
  return UserScopedStorage();
});



final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref.read(userScopedStorageProvider));
});

final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService(ref.read(userScopedStorageProvider));
});

final swapServiceProvider = Provider<SwapService>((ref) {
  return SwapService();
});

final quizServiceProvider = Provider<QuizService>((ref) {
  return QuizService(ref.read(userScopedStorageProvider));
});

final currentUserProvider = StateProvider<UserAccount?>((ref) => null);

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Get list akun
final allAccountsProvider = Provider<List<UserAccount>>((ref) {
  final auth = ref.read(authServiceProvider);
  return auth.getAllAccounts();
});


final walletAddressProvider = StateProvider<String?>((ref) => null);

final walletBalanceProvider = StateProvider<double>((ref) => 0.0);

final balanceVisibleProvider = StateProvider<bool>((ref) => true);


final ethPriceProvider = StateProvider<Map<String, double>>((ref) {
  return {'usd': 0.0, 'idr': 0.0, 'cny': 0.0};
});


final isInSafeZoneProvider = StateProvider<bool>((ref) => false);


final chatHistoryProvider = StateProvider<List<Map<String, String>>>((ref) {
  return [];
});

final chatLoadingProvider = StateProvider<bool>((ref) => false);


final gameScoreProvider = StateProvider<int>((ref) => 0);

final highScoreProvider = StateProvider<int>((ref) => 0);

final totalGamesProvider = StateProvider<int>((ref) => 0);


final txHistoryProvider = StateProvider<List<TxRecord>>((ref) => []);

final txHistoryLoadingProvider = StateProvider<bool>((ref) => false);

final transactionHistoryProvider =
    StateProvider<List<Map<String, String>>>((ref) => []);


final tokenListProvider = StateProvider<List<TokenBalance>>((ref) => []);

final tokenListLoadingProvider = StateProvider<bool>((ref) => false);


final isPremiumProvider = StateProvider<bool>((ref) => false);

final quizTokensProvider = StateProvider<int>((ref) => 0);


final userSafeZonesProvider =
    StateProvider<List<Map<String, dynamic>>>((ref) => []);

final userHasConfiguredZonesProvider = StateProvider<bool>((ref) => false);


final selectedTimezoneProvider =
    StateProvider<String>((ref) => 'Asia/Jakarta');
