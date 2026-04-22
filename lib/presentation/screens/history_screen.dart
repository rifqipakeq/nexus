import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

/// Transaction history screen (mocked data).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(walletAddressProvider);

    if (address == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction History')),
        body: const Center(child: Text('No wallet created yet.')),
      );
    }

    final blockchain = ref.read(blockchainServiceProvider);
    final history = blockchain.getMockTransactionHistory(address);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final tx = history[index];
          final isSent = tx['from'] == address;

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
                  Text(tx['value']!, style: const TextStyle(fontSize: 16)),
                  Text(
                    '${tx['date']} • ${tx['status']}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  Text(
                    'TX: ${tx['hash']}',
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
}
