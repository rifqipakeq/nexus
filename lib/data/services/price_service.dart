import '../../core/env_config.dart';
import 'api_service.dart';

class PriceService {
  final ApiService _api;

  PriceService(this._api);

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
      throw Exception('Gagal mengambil harga ETH: $e');
    }
  }
}
