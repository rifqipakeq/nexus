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
  static const Duration balancePollInterval = Duration(seconds: 30);
}
