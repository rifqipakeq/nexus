import 'dart:math';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/env_config.dart';
import 'security_service.dart';

class BlockchainService {
  final SecurityService _security;
  late final Web3Client _client;

  String? _activeUserId; // current user active untuk private key acess

  BlockchainService(this._security) {
    _client = Web3Client(EnvConfig.alchemyRpc, http.Client());
  }

  void setActiveUser(String userId) {
    _activeUserId = userId;
  }

  void clearActiveUser() {
    _activeUserId = null;
  }

  String get _privateKeyStorageKey {
    if (_activeUserId == null) {
      throw StateError('Tidak ada session aktif. Pastikan user sudah login sebelum mengakses private key.');
    }
    return AppConstants.secureKeyPrivateKey(_activeUserId!);
  }

  // Wallet Generation
  // buat wallet eth baru, simpan private key terenkripsi di secure storage dengan key yang scoped ke user aktif 
  Future<Map<String, String>> generateWallet() async {
    final rng = Random.secure();
    final credentials = EthPrivateKey.createRandom(rng);
    final address = credentials.address;
    final privateKeyHex = _bytesToHex(credentials.privateKey);

    // enkripsi private key sebelum disimpan
    final encryptedKey = await _security.encryptData(privateKeyHex);
    await _security.saveSecure(_privateKeyStorageKey, encryptedKey);

    return {
      'address': address.hexEip55, // public address
      'privateKey': privateKeyHex, 
    };
  }

  /// load wallet dari secure storage
  Future<EthPrivateKey?> _loadCredentials() async {
    final encryptedKey = await _security.readSecure(_privateKeyStorageKey);
    if (encryptedKey == null) return null;
    final privateKeyHex = await _security.decryptData(encryptedKey);
    return EthPrivateKey.fromHex(privateKeyHex);
  }

  // Balance management
  /// ambil data balance eth untuk address terkait dari jaringan sepholia
  Future<double> getBalance(String address) async {
    try {
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await _client.getBalance(ethAddress);
      // Convert Wei ke ETH
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      throw Exception('Gagal mengambil balance: $e');
    }
  }

  // Kirim transaksi
  /// Kirim ETH dari wallet yang disimpan ke address tujuan
  Future<String> sendTransaction({
    required String toAddress,
    required double amountInEth,
  }) async {
    final credentials = await _loadCredentials();
    if (credentials == null) throw Exception('Tidak ada wallet aktif. Pastikan address wallet benar!');

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

  /// Dispose data
  void dispose() {
    _client.dispose();
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
