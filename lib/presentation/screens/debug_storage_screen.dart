import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers.dart';

class DebugStorageScreen extends ConsumerStatefulWidget {
  const DebugStorageScreen({super.key});

  @override
  ConsumerState<DebugStorageScreen> createState() => _DebugStorageScreenState();
}

class _DebugStorageScreenState extends ConsumerState<DebugStorageScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late Future<_DebugSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_DebugSnapshot> _loadSnapshot() async {
    final storage = ref.read(userScopedStorageProvider);
    final auth = ref.read(authServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    final accounts = auth.getAllAccounts();
    final secureEntries = await _secureStorage.readAll();

    return _DebugSnapshot(
      currentUser: currentUser,
      accounts: accounts,
      walletAddress: currentUser == null ? null : storage.getWalletAddress(),
      walletBalance: currentUser == null ? 0.0 : storage.getBalance(),
      lastNotifiedBalance: currentUser == null
          ? 0.0
          : storage.getLastNotifiedBalance(),
      transactionHistory: currentUser == null
          ? const []
          : storage.getTransactionHistory(),
      chatHistory: currentUser == null ? const [] : storage.getChatHistory(),
      gameScore: currentUser == null ? 0 : storage.getGameScore(),
      highScore: currentUser == null ? 0 : storage.getHighScore(),
      totalGames: currentUser == null ? 0 : storage.getTotalGames(),
      safeZones: currentUser == null ? const [] : storage.getSafeZones(),
      hasConfiguredZones: currentUser == null
          ? false
          : storage.getHasConfiguredZones(),
      selectedTimezone: currentUser == null
          ? 'Asia/Jakarta'
          : storage.getSelectedTimezone(),
      cachedPrices: storage.getCachedPrices(),
      pricesLastUpdated: storage.getPricesLastUpdated(),
      secureEntries: secureEntries,
    );
  }

  void _refresh() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  String _prettyJson(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _dataCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Debug Storage')),
        body: const Center(
          child: Text('Halaman ini hanya tersedia pada mode debug.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Storage'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<_DebugSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat data debug: ${snapshot.error}'),
            );
          }

          final data = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('Ringkasan'),
              _dataCard('Current User', _prettyJson(data.currentUser?.toMap())),
              _dataCard('Selected Timezone', data.selectedTimezone),
              _dataCard('Prices Last Updated', data.pricesLastUpdated ?? '-'),

              _sectionTitle('Akun Hive (accounts)'),
              _dataCard('Total Accounts', data.accounts.length.toString()),
              _dataCard(
                'Accounts JSON',
                _prettyJson(data.accounts.map((e) => e.toMap()).toList()),
              ),

              _sectionTitle('User Scoped Storage'),
              _dataCard('Wallet Address', data.walletAddress ?? '-'),
              _dataCard(
                'Wallet Balance',
                data.walletBalance.toStringAsFixed(6),
              ),
              _dataCard(
                'Last Notified Balance',
                data.lastNotifiedBalance.toStringAsFixed(6),
              ),
              _dataCard('Game Score', data.gameScore.toString()),
              _dataCard('High Score', data.highScore.toString()),
              _dataCard('Total Games', data.totalGames.toString()),
              _dataCard(
                'Has Configured Zones',
                data.hasConfiguredZones.toString(),
              ),
              _dataCard('Safe Zones', _prettyJson(data.safeZones)),
              _dataCard(
                'Transaction History',
                _prettyJson(data.transactionHistory),
              ),
              _dataCard('Chat History', _prettyJson(data.chatHistory)),
              _dataCard('Cached Prices', _prettyJson(data.cachedPrices)),

              _sectionTitle('FlutterSecureStorage'),
              _dataCard('All Secure Keys', _prettyJson(data.secureEntries)),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _DebugSnapshot {
  final dynamic currentUser;
  final List<dynamic> accounts;
  final String? walletAddress;
  final double walletBalance;
  final double lastNotifiedBalance;
  final List<dynamic> transactionHistory;
  final List<dynamic> chatHistory;
  final int gameScore;
  final int highScore;
  final int totalGames;
  final List<dynamic> safeZones;
  final bool hasConfiguredZones;
  final String selectedTimezone;
  final Map<String, double> cachedPrices;
  final String? pricesLastUpdated;
  final Map<String, String> secureEntries;

  const _DebugSnapshot({
    required this.currentUser,
    required this.accounts,
    required this.walletAddress,
    required this.walletBalance,
    required this.lastNotifiedBalance,
    required this.transactionHistory,
    required this.chatHistory,
    required this.gameScore,
    required this.highScore,
    required this.totalGames,
    required this.safeZones,
    required this.hasConfiguredZones,
    required this.selectedTimezone,
    required this.cachedPrices,
    required this.pricesLastUpdated,
    required this.secureEntries,
  });
}
