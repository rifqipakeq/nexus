import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';

class SendTransactionScreen extends ConsumerStatefulWidget {
  const SendTransactionScreen({super.key});

  @override
  ConsumerState<SendTransactionScreen> createState() =>
      _SendTransactionScreenState();
}

class _SendTransactionScreenState extends ConsumerState<SendTransactionScreen> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  String? _resultMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final scanned = await context.push<String>('/scanner');
    if (scanned != null && mounted) {
      _addressController.text = scanned;
      // Trigger revalidation after scan
      _formKey.currentState?.validate();
    }
  }

  /// Validates Ethereum address format (0x followed by 40 hex chars)
  String? _validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address penerima wajib diisi';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(trimmed)) {
      return 'Format address tidak valid (harus 0x + 40 karakter hex)';
    }
    return null;
  }

  /// Validates ETH amount
  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Jumlah ETH wajib diisi';
    }
    // Accept both . and , as decimal separator
    final normalized = value.trim().replaceAll(',', '.');
    final amount = double.tryParse(normalized);
    if (amount == null) {
      return 'Masukkan angka yang valid (contoh: 0.01)';
    }
    if (amount <= 0) {
      return 'Jumlah harus lebih dari 0';
    }
    final balance = ref.read(walletBalanceProvider);
    if (amount > balance) {
      return 'Saldo tidak cukup (saldo: ${balance.toStringAsFixed(6)} ETH)';
    }
    // Limit to 18 decimal places (ETH precision)
    if (normalized.contains('.') && normalized.split('.').last.length > 18) {
      return 'Maksimal 18 desimal';
    }
    return null;
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final address = _addressController.text.trim();
    // Normalize comma to period for parsing
    final amountStr = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.parse(amountStr);

    setState(() {
      _isSending = true;
      _resultMessage = null;
      _isSuccess = false;
    });

    try {
      final blockchain = ref.read(blockchainServiceProvider);
      final txHash = await blockchain.sendTransaction(
        toAddress: address,
        amountInEth: amount,
      );

      if (!mounted) return;

      final notifications = ref.read(notificationServiceProvider);
      await notifications.showTransactionSent(
        amount: amount,
        toAddress: address,
        txHash: txHash,
      );

      if (!mounted) return;

      final storage = ref.read(userScopedStorageProvider);
      final walletAddress = ref.read(walletAddressProvider);
      if (walletAddress != null) {
        final newBalance = await blockchain.getBalance(walletAddress);
        if (!mounted) return;
        ref.read(walletBalanceProvider.notifier).state = newBalance;
        await storage.saveBalance(newBalance);
        await storage.saveLastNotifiedBalance(newBalance);
      }

      await storage.addTransaction({
        'type': 'sent',
        'from': walletAddress ?? '',
        'to': address,
        'value': '${amount.toStringAsFixed(6)} ETH',
        'status': 'confirmed',
        'date': DateTime.now().toIso8601String(),
        'hash': txHash,
      });

      if (!mounted) return;
      ref.read(transactionHistoryProvider.notifier).state =
          storage.getTransactionHistory();

      setState(() {
        _isSuccess = true;
        _resultMessage = 'Transaksi berhasil dikirim!\nTX Hash: $txHash';
      });

      // Clear form on success
      _addressController.clear();
      _amountController.clear();
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _isSuccess = false;
          _resultMessage = 'Format data tidak valid: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        // Parse common blockchain errors into user-friendly messages
        final msg = _friendlyError(e.toString());
        setState(() {
          _isSuccess = false;
          _resultMessage = msg;
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Convert raw blockchain/network errors to user-friendly Indonesian messages
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('insufficient funds') || lower.contains('saldo')) {
      return 'Saldo ETH tidak cukup untuk melakukan transaksi ini (termasuk biaya gas).';
    }
    if (lower.contains('nonce')) {
      return 'Terjadi konflik nonce transaksi. Coba lagi dalam beberapa saat.';
    }
    if (lower.contains('gas')) {
      return 'Estimasi gas gagal. Coba lagi atau periksa koneksi jaringan.';
    }
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('socket')) {
      return 'Koneksi ke jaringan gagal. Periksa koneksi internet Anda dan coba lagi.';
    }
    if (lower.contains('invalid address') || lower.contains('bad address')) {
      return 'Address tujuan tidak valid.';
    }
    if (lower.contains('execution reverted')) {
      return 'Transaksi ditolak oleh kontrak. Pastikan data sudah benar.';
    }
    // Fallback: show cleaned error
    return 'Gagal mengirim transaksi: $raw';
  }

  @override
  Widget build(BuildContext context) {
    final isInSafeZone = ref.watch(isInSafeZoneProvider);
    final balance = ref.watch(walletBalanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kirim Transaksi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Safe zone status banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isInSafeZone
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isInSafeZone ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isInSafeZone ? Icons.check_circle : Icons.warning,
                      color:
                          isInSafeZone ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isInSafeZone
                            ? 'Anda berada di zona aman. Transaksi diaktifkan.'
                            : 'Anda berada di luar zona aman. Transaksi dinonaktifkan.',
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
              const SizedBox(height: 8),

              // Balance info
              Text(
                'Saldo tersedia: ${balance.toStringAsFixed(6)} ETH',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Recipient address
              const Text(
                'Address Penerima',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _addressController,
                      enabled: isInSafeZone && !_isSending,
                      decoration: const InputDecoration(
                        hintText: '0x...',
                        helperText: 'Alamat Ethereum 42 karakter',
                      ),
                      validator: _validateAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      onPressed: isInSafeZone && !_isSending ? _scanQr : null,
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFF6C63FF),
                      ),
                      tooltip: 'Scan QR',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount
              const Text(
                'Jumlah (ETH)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                enabled: isInSafeZone && !_isSending,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: '0.01',
                  helperText: 'Saldo: ${balance.toStringAsFixed(6)} ETH',
                  suffixText: 'ETH',
                ),
                validator: _validateAmount,
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      : const Text('Kirim Transaksi'),
                ),
              ),
              const SizedBox(height: 16),

              // Result message
              if (_resultMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          _isSuccess ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.error_outline,
                        color:
                            _isSuccess ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          _resultMessage!,
                          style: TextStyle(
                            color: _isSuccess
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
                        '• Ini adalah testnet, bukan uang nyata.',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
