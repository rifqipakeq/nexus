class AppConstants {
  AppConstants._();

  // app constant
  static const String appName = 'Nexus';
  static const Duration inactivityTimeout = Duration(minutes: 10);
  static const Duration priceRefreshInterval = Duration(minutes: 5);

  // Hive box global
  static const String hiveBoxPrices = 'prices';
  static const String hiveBoxAccounts = 'accounts';

  // User-scoped hive box
  static String userWalletBox(String userId) => 'user_${userId}_wallet';
  static String userChatBox(String userId) => 'user_${userId}_chat';
  static String userGameBox(String userId) => 'user_${userId}_game';
  static const String userSafeZonesKey = 'user_safe_zones';
  static const String userTimezoneKey = 'user_timezone';
  static const String userHasConfiguredZonesKey = 'user_has_configured_zones';
  static const String keyIsPremium = 'is_premium';
  static const String keyQuizTokens = 'quiz_tokens';

  /// Minimum quiz tokens untuk akses fitur premium
  static const int premiumTokenThreshold = 10;

  /// Tokens consumed per chat message
  static const int tokensPerAiMessage = 10;

  // Secure storage keys (global)
  static const String secureKeyAesKey = 'aes_encryption_key';
  static const String secureKeyAesIv = 'aes_encryption_iv';
  static const String secureKeyActiveUser = 'active_user_id';

  // Secure storage keys (user-scoped)
  static String secureKeyPrivateKey(String userId) =>
      '${userId}_encrypted_private_key';

  // Blockchain
  static const int sepoliaChainId = 11155111;

  // durasi cek balance untuk notif
  static const Duration balancePollInterval = Duration(seconds: 10);

  static const String sepoliaExplorerBase = 'https://sepolia.etherscan.io/tx/';
}
