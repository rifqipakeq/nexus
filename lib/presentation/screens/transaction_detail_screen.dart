import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/tx_record.dart';
import '../../core/constants.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TxRecord tx;

  const TransactionDetailScreen({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isSuccess = tx.isSuccess;
    final statusColor = isSuccess ? const Color(0xFF4CAF50) : Colors.redAccent;
    final statusIcon = isSuccess ? Icons.check_circle : Icons.cancel;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: const Text(
          'Transaction Detail',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            _StatusBanner(isSuccess: isSuccess, statusColor: statusColor, statusIcon: statusIcon),
            const SizedBox(height: 24),

            // Value Card
            _ValueCard(tx: tx),
            const SizedBox(height: 20),

            // Detail Fields
            _DetailCard(
              title: 'Transaction Hash',
              children: [
                _CopyableRow(label: 'Hash', value: tx.hash),
              ],
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Addresses',
              children: [
                _CopyableRow(label: 'From', value: tx.from),
                const Divider(color: Colors.white12),
                _CopyableRow(label: 'To', value: tx.to.isEmpty ? '—' : tx.to),
              ],
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Gas & Fees',
              children: [
                _InfoRow(label: 'Gas Limit', value: tx.gas),
                const Divider(color: Colors.white12),
                _InfoRow(label: 'Gas Used', value: tx.gasUsed),
                const Divider(color: Colors.white12),
                _InfoRow(
                  label: 'Gas Price',
                  value: '${tx.gasPriceGwei.toStringAsFixed(2)} Gwei',
                ),
                const Divider(color: Colors.white12),
                _InfoRow(
                  label: 'Total Fee',
                  value: '${tx.gasFeeEth.toStringAsFixed(8)} ETH',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Block Info',
              children: [
                _InfoRow(label: 'Block', value: '#${tx.blockNumber}'),
                const Divider(color: Colors.white12),
                _InfoRow(
                  label: 'Timestamp',
                  value: DateFormat('MMM d, yyyy  HH:mm:ss').format(tx.dateTime),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // View on Explorer Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openExplorer(tx.hash),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Lihat di Sepolia Explorer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Copy Hash Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyToClipboard(context, tx.hash),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Salin Hash Transaksi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExplorer(String hash) async {
    final uri = Uri.parse('${AppConstants.sepoliaExplorerBase}$hash');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hash transaksi disalin ke clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}


class _StatusBanner extends StatelessWidget {
  final bool isSuccess;
  final Color statusColor;
  final IconData statusIcon;

  const _StatusBanner({
    required this.isSuccess,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSuccess ? 'Transaction Dikonfirmasi' : 'Transaction Gagal',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                isSuccess ? 'Berhasil dimasukkan ke dalam block' : 'Terjadi kesalahan',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final TxRecord tx;

  const _ValueCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F3A), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Jumlah',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '${tx.valueEth.toStringAsFixed(6)} ETH',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  final String label;
  final String value;

  const _CopyableRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.copy, size: 16, color: Color(0xFF6C63FF)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
