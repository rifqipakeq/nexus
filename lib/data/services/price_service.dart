import '../../core/env_config.dart';
import 'api_service.dart';

/// Fetches ETH prices from CoinGecko in multiple currencies.
class PriceService {
  final ApiService _api;

  PriceService(this._api);

  /// Fetch ETH price in USD, IDR, and CNY.
  Future<Map<String, double>> getEthPrice() async {
    try {
      final response = await _api.get(
        '${EnvConfig.coingeckoBaseUrl}/simple/price',
        queryParameters: {'ids': 'ethereum', 'vs_currencies': 'usd,idr,cny'},
      );

      final data = response.data['ethereum'];
      return {
        'usd': (data['usd'] as num).toDouble(),
        'idr': (data['idr'] as num).toDouble(),
        'cny': (data['cny'] as num).toDouble(),
      };
    } catch (e) {
      throw Exception('Failed to fetch ETH price: $e');
    }
  }
}
