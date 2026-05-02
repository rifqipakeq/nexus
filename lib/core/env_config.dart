import 'package:flutter_dotenv/flutter_dotenv.dart';

/// akses ke env variable
class EnvConfig {
  EnvConfig._();

  static String get alchemyRpc =>
      dotenv.env['ALCHEMY_TESTNET_RPC'] ?? '';

  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? '';

  static String get coingeckoBaseUrl =>
      dotenv.env['COINGECKO_BASE_URL'] ?? 'https://api.coingecko.com/api/v3';

  static double get safeZoneLat =>
      double.tryParse(dotenv.env['SAFE_ZONE_LAT'] ?? '') ?? 0.0;

  static double get safeZoneLng =>
      double.tryParse(dotenv.env['SAFE_ZONE_LNG'] ?? '') ?? 0.0;

  static double get safeZoneRadius =>
      double.tryParse(dotenv.env['SAFE_ZONE_RADIUS'] ?? '') ?? 500.0;

  static String get etherscanApiKey =>
      dotenv.env['ETHERSCAN_API_KEY'] ?? '';
}
