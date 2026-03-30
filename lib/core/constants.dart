/// Application-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'NexusNode';
  static const Duration inactivityTimeout = Duration(minutes: 10);
  static const Duration priceRefreshInterval = Duration(minutes: 5);
  static const String hiveBoxPrices = 'prices';
  static const String hiveBoxWallet = 'wallet';
  static const String hiveBoxChat = 'chat';
  static const String hiveBoxGame = 'game';
  static const String secureKeyPrivateKey = 'encrypted_private_key';
  static const String secureKeyAuthToken = 'auth_token';
  static const String secureKeyAesKey = 'aes_encryption_key';
  static const String secureKeyAesIv = 'aes_encryption_iv';
  static const int sepoliaChainId = 11155111;
}
