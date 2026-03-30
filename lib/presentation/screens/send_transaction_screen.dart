import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';

/// Send Transaction screen – enabled only inside safe zone.
class SendTransactionScreen extends ConsumerStatefulWidget {
  const SendTransactionScreen({super.key});

  @override
  ConsumerState<SendTransactionScreen> createState() =>
      _SendTransactionScreenState();
}

class _SendTransactionScreenState extends ConsumerState<SendTransactionScreen> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSending = false;
  String? _result;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final scanned = await context.push<String>('/scanner');
    if (scanned != null) {
      _addressController.text = scanned;
    }
  }

  Future<void> _send() async {
    final address = _addressController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (address.isEmpty || amount == null || amount <= 0) {
      setState(() => _result = 'Invalid address or amount');
      return;
    }

    setState(() {
      _isSending = true;
      _result = null;
    });

    try {
      final blockchain = ref.read(blockchainServiceProvider);
      final txHash = await blockchain.sendTransaction(
        toAddress: address,
        amountInEth: amount,
      );
      setState(() => _result = 'Success! TX: $txHash');
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInSafeZone = ref.watch(isInSafeZoneProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Send Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safe zone status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isInSafeZone
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isInSafeZone ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isInSafeZone ? Icons.check_circle : Icons.warning,
                    color: isInSafeZone ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isInSafeZone
                          ? 'You are inside the safe zone. Transactions enabled.'
                          : 'You are outside the safe zone. Transactions disabled.',
                      style: TextStyle(
                        color: isInSafeZone
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recipient address
            const Text(
              'Recipient Address',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(hintText: '0x...'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _scanQr,
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    color: Color(0xFF6C63FF),
                  ),
                  tooltip: 'Scan QR',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount
            const Text(
              'Amount (ETH)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: '0.01'),
            ),
            const SizedBox(height: 24),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isInSafeZone && !_isSending ? _send : null,
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Transaction'),
              ),
            ),
            const SizedBox(height: 16),

            // Result
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _result!,
                  style: TextStyle(
                    color: _result!.startsWith('Success')
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Network info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Network Info',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Network: Ethereum Sepolia Testnet\n'
                      '• Chain ID: 11155111\n'
                      '• Get test ETH: sepoliafaucet.com',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
