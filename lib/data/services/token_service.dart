import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import '../models/token_balance.dart';
import '../local/user_scoped_storage.dart';
import '../../core/constants.dart';
import '../../core/env_config.dart';
import '../../core/erc20_abi.dart';

/// Loads ERC-20 token balances for a wallet address using web3dart.
///
/// Flow:
/// 1. Load token definitions (hardcoded defaults + user-saved)
/// 2. Call balanceOf(address) on each contract
/// 3. Cache results in user_{id}_tokens Hive box
class TokenService {
  final UserScopedStorage _storage;
  late final Web3Client _client;

  TokenService(this._storage) {
    _client = Web3Client(EnvConfig.alchemyRpc, http.Client());
  }

  /// Load all tokens with cached balances (instant, offline-safe).
  List<TokenBalance> loadCached() {
    if (!_storage.isTokensBoxOpen) return _buildDefaults(BigInt.zero);
    final raw = _storage.tokensBox.get(
      AppConstants.keyTokenList,
      defaultValue: <dynamic>[],
    );
    if ((raw as List).isEmpty) return _buildDefaults(BigInt.zero);
    return raw.map((e) => TokenBalance.fromMap(e as Map)).toList();
  }

  /// Fetch live balances for all tokens for [walletAddress].
  /// Returns updated list and caches to Hive.
  Future<List<TokenBalance>> fetchBalances(String walletAddress) async {
    final ethAddress = EthereumAddress.fromHex(walletAddress);
    final tokens = _buildDefaults(BigInt.zero);
    final updated = <TokenBalance>[];

    for (final token in tokens) {
      try {
        final contract = DeployedContract(
          ContractAbi.fromJson(kErc20Abi, token.symbol),
          EthereumAddress.fromHex(token.contractAddress),
        );

        final balanceOfFn = contract.function('balanceOf');
        final result = await _client.call(
          contract: contract,
          function: balanceOfFn,
          params: [ethAddress],
        );

        final rawBalance = result.first as BigInt;
        updated.add(token.copyWith(
          rawBalance: rawBalance,
          lastUpdated: DateTime.now().toIso8601String(),
        ));
      } catch (e) {
        debugPrint('[TokenService] Error fetching ${token.symbol}: $e');
        // Keep token with zero balance on error
        updated.add(token);
      }
    }

    // Persist to tokensBox
    if (_storage.isTokensBoxOpen) {
      await _storage.tokensBox.put(
        AppConstants.keyTokenList,
        updated.map((t) => t.toMap()).toList(),
      );
    }

    return updated;
  }

  /// Build default token list with provided balance (usually BigInt.zero).
  List<TokenBalance> _buildDefaults(BigInt balance) {
    return kDefaultSepoliaTokens
        .map((t) => TokenBalance(
              symbol: t['symbol'] as String,
              name: t['name'] as String,
              contractAddress: t['address'] as String,
              decimals: t['decimals'] as int,
              rawBalance: balance,
            ))
        .toList();
  }

  void dispose() {
    _client.dispose();
  }
}
