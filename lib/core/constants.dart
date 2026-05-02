class AppConstants {
  AppConstants._();

  // app constant
  static const String appName = 'NexusNode';
  static const Duration inactivityTimeout = Duration(minutes: 10);
  static const Duration priceRefreshInterval = Duration(minutes: 5);

  // Hive box global
  static const String hiveBoxPrices = 'prices';
  static const String hiveBoxAccounts = 'accounts';

  // User-scoped hive box
  static String userWalletBox(String userId) => 'user_${userId}_wallet';
  static String userChatBox(String userId) => 'user_${userId}_chat';
  static String userGameBox(String userId) => 'user_${userId}_game';
  static String userTokensBox(String userId) =>
      'user_${userId}_tokens'; // ERC-20

  // Wallet box keys (legacy)
  static const String userSafeZonesKey = 'user_safe_zones';
  static const String userTimezoneKey = 'user_timezone';
  static const String userHasConfiguredZonesKey = 'user_has_configured_zones';

  // Wallet box keys
  static const String keyTxHistoryV2 = 'tx_history_v2';
  static const String keyTxLastFetched = 'tx_last_fetched';
  static const String keyIsPremium = 'is_premium';
  static const String keyQuizTokens = 'quiz_tokens';

  // Token box keys
  static const String keyTokenList = 'token_list';

  // Secure storage keys (global)
  static const String secureKeyAesKey = 'aes_encryption_key';
  static const String secureKeyAesIv = 'aes_encryption_iv';
  static const String secureKeyActiveUser = 'active_user_id';

  // Secure storage keys (user-scoped)
  static String secureKeyPrivateKey(String userId) =>
      '${userId}_encrypted_private_key';

  // Blockchain
  static const int sepoliaChainId = 11155111;

  // Blockchain API
  static const String etherscanSepoliaBase =
      'https://api-sepolia.etherscan.io/api';
  static const String sepoliaExplorerBase = 'https://sepolia.etherscan.io/tx/';

  // durasi cek balance untuk notif
  static const Duration balancePollInterval = Duration(seconds: 10);

  /// Minimum quiz tokens untuk akses fitur premium
  static const int premiumTokenThreshold = 10;

  /// Tokens consumed per chat message
  static const int tokensPerAiMessage = 1;
}
