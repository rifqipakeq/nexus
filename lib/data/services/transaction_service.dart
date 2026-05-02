import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tx_record.dart';
import '../../core/constants.dart';
import '../../core/env_config.dart';
import '../local/user_scoped_storage.dart';

/// Fetches and caches real transaction history from Etherscan Sepolia API.
///
/// Flow:
/// 1. Load from Hive (walletBox['tx_history_v2'])
/// 2. Fetch fresh data from Etherscan
/// 3. Merge by hash (dedup) and persist back to Hive
class TransactionService {
  final UserScopedStorage _storage;

  TransactionService(this._storage);

  /// Load cached transactions from Hive (instant, offline-safe).
  List<TxRecord> loadCached() {
    final raw = _storage.walletBox.get(
      AppConstants.keyTxHistoryV2,
      defaultValue: <dynamic>[],
    );
    return (raw as List)
        .map((e) => TxRecord.fromMap(e as Map))
        .toList();
  }

  /// Fetch latest transactions from Etherscan API for [address].
  /// Returns merged list (fresh + cached, deduped by hash).
  ///
  /// Example request:
  /// GET https://api-sepolia.etherscan.io/api
  ///   ?module=account&action=txlist
  ///   &address=0x...&startblock=0&endblock=99999999
  ///   &page=1&offset=25&sort=desc&apikey=YOUR_KEY
  Future<List<TxRecord>> fetchAndCache(String address) async {
    final apiKey = EnvConfig.etherscanApiKey;
    final url = Uri.parse(AppConstants.etherscanSepoliaBase).replace(
      queryParameters: {
        'module': 'account',
        'action': 'txlist',
        'address': address,
        'startblock': '0',
        'endblock': '99999999',
        'page': '1',
        'offset': '50',
        'sort': 'desc',
        'apikey': apiKey.isNotEmpty ? apiKey : 'YourApiKeyToken',
      },
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[TransactionService] HTTP ${response.statusCode}');
        return loadCached();
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['status'] != '1') {
        // 'No transactions found' is a valid empty state
        final msg = body['message'] as String? ?? '';
        if (msg.contains('No transactions')) {
          return [];
        }
        debugPrint('[TransactionService] API error: ${body['message']}');
        return loadCached();
      }

      final results = (body['result'] as List)
          .map((e) => TxRecord.fromEtherscanJson(e as Map<String, dynamic>))
          .toList();

      // Merge with existing cache (dedup by hash)
      final cached = loadCached();
      final seen = <String>{};
      final merged = <TxRecord>[];

      for (final tx in [...results, ...cached]) {
        if (seen.add(tx.hash)) {
          merged.add(tx);
        }
      }

      // Persist to Hive
      await _storage.walletBox.put(
        AppConstants.keyTxHistoryV2,
        merged.map((tx) => tx.toMap()).toList(),
      );
      await _storage.walletBox.put(
        AppConstants.keyTxLastFetched,
        DateTime.now().toIso8601String(),
      );

      debugPrint('[TransactionService] Fetched ${results.length} txs, total cached: ${merged.length}');
      return merged;
    } catch (e) {
      debugPrint('[TransactionService] Fetch error: $e');
      return loadCached();
    }
  }

  /// Clear all cached transactions.
  Future<void> clearCache() async {
    await _storage.walletBox.put(AppConstants.keyTxHistoryV2, <dynamic>[]);
    await _storage.walletBox.delete(AppConstants.keyTxLastFetched);
  }

  /// Timestamp of last successful fetch (null if never fetched).
  String? get lastFetchedAt =>
      _storage.walletBox.get(AppConstants.keyTxLastFetched) as String?;
}
