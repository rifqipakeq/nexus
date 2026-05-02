import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _filterHistory(List<Map<String, String>> history) {
    if (_query.isEmpty) return history;
    final q = _query.toLowerCase();
    return history.where((tx) {
      final from = (tx['from'] ?? '').toLowerCase();
      final to = (tx['to'] ?? '').toLowerCase();
      final hash = (tx['hash'] ?? '').toLowerCase();
      return from.contains(q) || to.contains(q) || hash.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(walletAddressProvider);
    final history = ref.watch(transactionHistoryProvider);

    if (address == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Transaksi')),
        body: const Center(child: Text('Tidak ada wallet terdaftar.')),
      );
    }

    final filtered = _filterHistory(history);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _clearHistory(context),
              tooltip: 'Bersihkan Riwayat',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan alamat atau hash tx...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
              ),
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
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _query.isNotEmpty
                              ? 'Data tidak ditemukan untuk "$_query"'
                              : 'Tidak ada transaksi',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        if (_query.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Kirim atau terima ETH untuk melihat riwayat Anda.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final tx = filtered[index];
                      final isSent = tx['type'] == 'sent';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSent
                                ? Colors.red.withValues(alpha: 0.2)
                                : Colors.green.withValues(alpha: 0.2),
                            child: Icon(
                              isSent
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: isSent
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                            ),
                          ),
                          title: Text(
                            isSent ? 'Dikirim' : 'Diterima',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx['value'] ?? '0 ETH',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (isSent && tx['to'] != null)
                                Text(
                                  'To: ${_shortAddress(tx['to']!)}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              if (!isSent && tx['from'] != null)
                                Text(
                                  'From: ${tx['from'] == 'External' ? 'External' : _shortAddress(tx['from']!)}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              Text(
                                '${_formatDate(tx['date'])} • ${tx['status'] ?? 'unknown'}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              if (tx['hash'] != null)
                                Text(
                                  'TX: ${_shortHash(tx['hash']!)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: tx['hash'] != null
                              ? () => _openExplorer(tx['hash']!)
                              : null,
                          trailing: tx['hash'] != null
                              ? IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 20),
                                  onPressed: () => _openExplorer(tx['hash']!),
                                  tooltip: 'Buka di Sepolia Etherscan',
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExplorer(String hash) async {
    final uri = Uri.parse('${AppConstants.sepoliaExplorerBase}$hash');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka explorer.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membuka explorer.')));
    }
  }

  Future<void> _clearHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bersihkan Riwayat?'),
        content: const Text('Ini akan menghapus semua catatan transaksi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Bersihkan',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = ref.read(userScopedStorageProvider);
      await storage.clearTransactionHistory();
      ref.read(transactionHistoryProvider.notifier).state = [];
    }
  }

  String _shortAddress(String addr) {
    if (addr.length > 10) {
      return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
    }
    return addr;
  }

  String _shortHash(String hash) {
    if (hash.length > 16) {
      return '${hash.substring(0, 10)}...${hash.substring(hash.length - 4)}';
    }
    return hash;
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('MMM d, yyyy  HH:mm').format(dt);
    } catch (_) {
      return isoDate;
    }
  }
}
