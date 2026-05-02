import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/tx_record.dart';
import '../providers.dart';
import 'transaction_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final address = ref.read(walletAddressProvider);
    if (address == null) return;

    ref.read(txHistoryLoadingProvider.notifier).state = true;
    final txService = ref.read(transactionServiceProvider);
    final txs = await txService.fetchAndCache(address);
    ref.read(txHistoryProvider.notifier).state = txs;
    ref.read(txHistoryLoadingProvider.notifier).state = false;
  }

  List<TxRecord> _filterHistory(List<TxRecord> history) {
    if (_query.isEmpty) return history;
    final q = _query.toLowerCase();
    return history.where((tx) {
      return tx.from.toLowerCase().contains(q) ||
          tx.to.toLowerCase().contains(q) ||
          tx.hash.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(walletAddressProvider);
    final history = ref.watch(txHistoryProvider);
    final isLoading = ref.watch(txHistoryLoadingProvider);

    if (address == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        appBar: _buildAppBar(history, isLoading),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text('Tidak ada wallet yang terhubung.',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    final filtered = _filterHistory(history);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: _buildAppBar(history, isLoading),
      body: Column(
        children: [
          // Last fetched info
          if (!isLoading)
            _LastFetchedBar(
              txService: ref.read(transactionServiceProvider),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan alamat atau hash...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Colors.white38),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 18, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF16213E),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                ),
              ),
            ),
          ),

          // Loading
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Fetching from Etherscan...',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _query.isNotEmpty
                              ? Icons.search_off
                              : Icons.receipt_long,
                          size: 64,
                          color: Colors.white12,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _query.isNotEmpty
                              ? 'Tidak ada hasil untuk "$_query"'
                              : isLoading
                                  ? 'Memuat...'
                                  : 'Tidak ada transaksi yang ditemukan',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 15),
                        ),
                        if (_query.isEmpty && !isLoading) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Kirim atau terima ETH di Sepolia untuk melihat riwayat.',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadHistory,
                    color: const Color(0xFF6C63FF),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        final myAddress =
                            ref.read(walletAddressProvider) ?? '';
                        final isSent = tx.from.toLowerCase() ==
                            myAddress.toLowerCase();

                        return _TxCard(
                          tx: tx,
                          isSent: isSent,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TransactionDetailScreen(tx: tx),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(List<TxRecord> history, bool isLoading) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0E1A),
      elevation: 0,
      title: const Text(
        'Transaction History',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: isLoading ? null : _loadHistory,
          tooltip: 'Refresh',
        ),
        if (history.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => _clearHistory(context),
            tooltip: 'Clear Cache',
          ),
      ],
    );
  }

  Future<void> _clearHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Clear History?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This clears the local cache. Data will re-fetch from Etherscan on next refresh.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final txService = ref.read(transactionServiceProvider);
      await txService.clearCache();
      ref.read(txHistoryProvider.notifier).state = [];
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _LastFetchedBar extends StatelessWidget {
  final dynamic txService;

  const _LastFetchedBar({required this.txService});

  @override
  Widget build(BuildContext context) {
    final lastFetched = txService.lastFetchedAt as String?;
    if (lastFetched == null) return const SizedBox.shrink();

    String timeStr = '';
    try {
      final dt = DateTime.parse(lastFetched);
      timeStr = DateFormat('HH:mm · MMM d').format(dt);
    } catch (_) {
      timeStr = lastFetched;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF0D1B2A),
      child: Row(
        children: [
          const Icon(Icons.cloud_done, size: 12, color: Colors.white24),
          const SizedBox(width: 6),
          Text(
            'Last synced: $timeStr via Etherscan',
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  final TxRecord tx;
  final bool isSent;
  final VoidCallback onTap;

  const _TxCard({
    required this.tx,
    required this.isSent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final directionColor = isSent ? Colors.redAccent : const Color(0xFF4CAF50);
    final directionIcon = isSent ? Icons.arrow_upward : Icons.arrow_downward;
    final directionLabel = isSent ? 'Sent' : 'Received';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            // Direction Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: directionColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(directionIcon, color: directionColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        directionLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!tx.isSuccess)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FAILED',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isSent
                        ? 'To: ${_short(tx.to)}'
                        : 'From: ${_short(tx.from)}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMM d, yyyy · HH:mm').format(tx.dateTime),
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isSent ? '-' : '+'}${tx.valueEth.toStringAsFixed(5)}',
                  style: TextStyle(
                    color: directionColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'ETH',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _short(String addr) {
    if (addr.length > 10) {
      return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
    }
    return addr;
  }
}
