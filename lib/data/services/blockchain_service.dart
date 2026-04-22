import 'dart:math';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/env_config.dart';
import 'security_service.dart';

/// Manages Ethereum Sepolia wallet operations.
///
/// Private keys are encrypted with AES-256 and stored in secure storage,
/// scoped to the active user's ID to prevent cross-user access.
class BlockchainService {
  final SecurityService _security;
  late final Web3Client _client;

  /// The currently active user's ID. Used to scope private key storage.
  String? _activeUserId;

  BlockchainService(this._security) {
    _client = Web3Client(EnvConfig.alchemyRpc, http.Client());
  }

  /// Set the active user ID. Must be called after login.
  void setActiveUser(String userId) {
    _activeUserId = userId;
  }

  /// Clear the active user (on logout).
  void clearActiveUser() {
    _activeUserId = null;
  }

  String get _privateKeyStorageKey {
    if (_activeUserId == null) {
      throw StateError('No active user set. Call setActiveUser() first.');
    }
    return AppConstants.secureKeyPrivateKey(_activeUserId!);
  }

  // ─── Wallet Generation ────────────────────────────────────────

  /// Generates a new Ethereum wallet, encrypts the private key, and returns the address.
  /// The private key is stored under the active user's scoped key.
  Future<Map<String, String>> generateWallet() async {
    final rng = Random.secure();
    final credentials = EthPrivateKey.createRandom(rng);
    final address = credentials.address;
    final privateKeyHex = _bytesToHex(credentials.privateKey);

    // Encrypt private key before storing
    final encryptedKey = await _security.encryptData(privateKeyHex);
    await _security.saveSecure(_privateKeyStorageKey, encryptedKey);

    return {
      'address': address.hexEip55,
      'privateKey': privateKeyHex, // shown once, then discarded from memory
    };
  }

  /// Loads wallet credentials from encrypted secure storage.
  Future<EthPrivateKey?> _loadCredentials() async {
    final encryptedKey = await _security.readSecure(_privateKeyStorageKey);
    if (encryptedKey == null) return null;
    final privateKeyHex = await _security.decryptData(encryptedKey);
    return EthPrivateKey.fromHex(privateKeyHex);
  }

  // ─── Balance ──────────────────────────────────────────────────

  /// Fetches ETH balance for the given address from Sepolia.
  Future<double> getBalance(String address) async {
    try {
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await _client.getBalance(ethAddress);
      // Convert Wei to ETH
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      throw Exception('Failed to fetch balance: $e');
    }
  }

  // ─── Send Transaction ─────────────────────────────────────────

  /// Sends ETH from the stored wallet to [toAddress].
  /// Amount is in ETH (e.g. 0.01).
  Future<String> sendTransaction({
    required String toAddress,
    required double amountInEth,
  }) async {
    final credentials = await _loadCredentials();
    if (credentials == null) throw Exception('No wallet found');

    final to = EthereumAddress.fromHex(toAddress);
    final amount = EtherAmount.fromBigInt(
      EtherUnit.wei,
      BigInt.from(amountInEth * 1e18),
    );

    final txHash = await _client.sendTransaction(
      credentials,
      Transaction(to: to, value: amount),
      chainId: AppConstants.sepoliaChainId,
    );
    return txHash;
  }

  // ─── Mock Transaction History ─────────────────────────────────

  /// Returns mocked transaction history for display purposes.
  /// In production you'd call Alchemy / Etherscan API.
  List<Map<String, String>> getMockTransactionHistory(String address) {
    return [
      {
        'hash': '0xabc123...def',
        'from': address,
        'to': '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD38',
        'value': '0.05 ETH',
        'status': 'confirmed',
        'date': '2026-02-28',
      },
      {
        'hash': '0xdef456...abc',
        'from': '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD38',
        'to': address,
        'value': '0.1 ETH',
        'status': 'confirmed',
        'date': '2026-02-27',
      },
      {
        'hash': '0x789ghi...jkl',
        'from': address,
        'to': '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4',
        'value': '0.02 ETH',
        'status': 'pending',
        'date': '2026-02-26',
      },
    ];
  }

  /// Dispose the web3 client.
  void dispose() {
    _client.dispose();
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
