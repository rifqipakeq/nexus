import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(walletAddressProvider);
    final history = ref.watch(transactionHistoryProvider);

    if (address == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Transaksi')),
        body: const Center(child: Text('Tidak ada dompet yang dibuat.')),
      );
    }

    if (history.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Transaksi')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey[700]),
              const SizedBox(height: 16),
              Text(
                'Belum ada transaksi',
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Kirim atau terima ETH untuk melihat riwayat Anda.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _clearHistory(context, ref),
            tooltip: 'Clear history',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final tx = history[index];
          final isSent = tx['type'] == 'sent';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isSent
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.2),
                child: Icon(
                  isSent ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isSent ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
              title: Text(
                isSent ? 'Sent' : 'Received',
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
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  if (!isSent && tx['from'] != null)
                    Text(
                      'From: ${tx['from'] == 'External' ? 'External' : _shortAddress(tx['from']!)}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  Text(
                    '${_formatDate(tx['date'])} • ${tx['status'] ?? 'unknown'}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  if (tx['hash'] != null)
                    Text(
                      'TX: ${_shortHash(tx['hash']!)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
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
