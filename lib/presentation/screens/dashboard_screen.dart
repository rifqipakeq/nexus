import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants.dart';
import '../providers.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = false;
  bool _isUsd = false; // default rupiah

  Timer? _balancePollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startMotionDetection();
    _checkSafeZone();
    _startBalancePolling();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(userScopedStorageProvider);

      // Fetch ETH price
      final priceService = ref.read(priceServiceProvider);
      final prices = await priceService.getEthPrice();
      ref.read(ethPriceProvider.notifier).state = prices;
      await storage.cachePrices(prices);

      // Fetch balance 
      final address = ref.read(walletAddressProvider);
      if (address != null) {
        final blockchain = ref.read(blockchainServiceProvider);
        final balance = await blockchain.getBalance(address);

        // cek perubahan balance untuk notifikasi
        final lastNotified = storage.getLastNotifiedBalance();
        final notifications = ref.read(notificationServiceProvider);
        final notified = await notifications.checkBalanceChange(
          currentBalance: balance,
          lastNotifiedBalance: lastNotified,
        );
        if (notified) {
          final received = balance - lastNotified;
          await storage.addTransaction({
            'type': 'received',
            'from': 'External',
            'to': address,
            'value': '${received.toStringAsFixed(6)} ETH',
            'status': 'confirmed',
            'date': DateTime.now().toIso8601String(),
            'hash': 'poll_${DateTime.now().millisecondsSinceEpoch}',
          });
          ref.read(transactionHistoryProvider.notifier).state = storage
              .getTransactionHistory();
          await storage.saveLastNotifiedBalance(balance);
        }

        ref.read(walletBalanceProvider.notifier).state = balance;
        await storage.saveBalance(balance);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startBalancePolling() {
    _balancePollTimer = Timer.periodic(
      AppConstants.balancePollInterval,
      (_) => _loadData(),
    );
  }

  void _startMotionDetection() {
    final motionService = ref.read(motionServiceProvider);
    motionService.startListening(
      onShake: () {
        ref.read(balanceVisibleProvider.notifier).state = !ref.read(
          balanceVisibleProvider,
        );
      },
    );
  }

  Future<void> _checkSafeZone() async {
    final locationService = ref.read(locationServiceProvider);
    final isInside = await locationService.isInsideSafeZone();
    ref.read(isInSafeZoneProvider.notifier).state = isInside;
  }

  Future<void> _generateWallet() async {
    final blockchain = ref.read(blockchainServiceProvider);
    final wallet = await blockchain.generateWallet();
    final storage = ref.read(userScopedStorageProvider);
    await storage.saveWalletAddress(wallet['address']!);
    ref.read(walletAddressProvider.notifier).state = wallet['address'];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simpan kunci pribadi Anda dengan aman!\nKunci ini tidak akan ditampilkan lagi.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Address:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    wallet['address']!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: wallet['address']!));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Address tercopy!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Private Key:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    wallet['privateKey']!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: wallet['privateKey']!),
                    );
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Private key tercopy!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Saya Suadah Menyimpannya'),
          ),
        ],
      ),
    );
  }

  void _showQrCode(String address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wallet QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: address,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              address,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Address tercopy!')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _copyAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallet address tercopy ke clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    // 1. tutup semua box Hive yang terkait user untuk mencegah data bocor ke user lain saat switch account
    final storage = ref.read(userScopedStorageProvider);
    await storage.closeUserBoxes();
    // 2. clear active user di blockchain service untuk mencegah akses ke wallet setelah logout
    final blockchain = ref.read(blockchainServiceProvider);
    blockchain.clearActiveUser();
    // 3. Log out dari auth service 
    final auth = ref.read(authServiceProvider);
    await auth.logout();
    // 4. Reset semua user-scoped providers
    ref.invalidate(currentUserProvider);
    ref.invalidate(walletAddressProvider);
    ref.invalidate(walletBalanceProvider);
    ref.invalidate(balanceVisibleProvider);
    ref.invalidate(chatHistoryProvider);
    ref.invalidate(chatLoadingProvider);
    ref.invalidate(gameScoreProvider);
    ref.invalidate(highScoreProvider);
    ref.invalidate(totalGamesProvider);
    ref.invalidate(isInSafeZoneProvider);
    ref.invalidate(transactionHistoryProvider);
    // 5. arahkan ke login
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _balancePollTimer?.cancel();
    ref.read(motionServiceProvider).stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final address = ref.watch(walletAddressProvider);
    final balance = ref.watch(walletBalanceProvider);
    final prices = ref.watch(ethPriceProvider);
    final balanceVisible = ref.watch(balanceVisibleProvider);
    final isInSafeZone = ref.watch(isInSafeZoneProvider);

    final ethUsd = prices['usd'] ?? 0.0;
    final ethIdr = prices['idr'] ?? 0.0;
    final balanceUsd = balance * ethUsd;

    final idrFormatter = NumberFormat('#,##0', 'id_ID');
    final usdFormatter = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text('NexusNode'),
        actions: [
          // Account switcher
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () => context.push('/accounts'),
            tooltip: 'Switch Account',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info 
              if (currentUser != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF6C63FF),
                        child: Text(
                          currentUser.username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Halo, ${currentUser.username}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (currentUser.biometricPublicKey != null)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.verified_user,
                            size: 16,
                            color: Colors.greenAccent,
                          ),
                        ),
                    ],
                  ),
                ),

              // Wallet Card 
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Wallet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (address != null) ...[
                                IconButton(
                                  icon: const Icon(Icons.qr_code, size: 22),
                                  onPressed: () => _showQrCode(address),
                                  tooltip: 'Tunjukan QR Code',
                                ),
                              ],
                              // Visibility toggle
                              IconButton(
                                icon: Icon(
                                  balanceVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  ref
                                          .read(balanceVisibleProvider.notifier)
                                          .state =
                                      !balanceVisible;
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (address != null) ...[
                        // Tappable address with copy
                        GestureDetector(
                          onTap: () => _copyAddress(address),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${address.substring(0, 6)}...${address.substring(address.length - 4)}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          balanceVisible
                              ? '${balance.toStringAsFixed(6)} ETH'
                              : '••••••',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          balanceVisible
                              ? '\$${balanceUsd.toStringAsFixed(2)} USD'
                              : '••••',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📍 ${isInSafeZone ? "Dalam Zona Aman" : "Di Luar Zona Aman"}',
                          style: TextStyle(
                            color: isInSafeZone
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        const Text('Belum ada wallet'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _generateWallet,
                          icon: const Icon(Icons.add),
                          label: const Text('Generate Wallet'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Price Card 
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header + Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Harga ETH',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isUsd = !_isUsd;
                              });
                            },
                            icon: Icon(
                              _isUsd
                                  ? Icons.attach_money
                                  : Icons.currency_exchange,
                            ),
                            tooltip: 'Switch Currency',
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        // USD Row 
                        if (_isUsd)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('USD'),
                              Text(
                                '\$${usdFormatter.format(ethUsd)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),

                        // IDR Row 
                        if (!_isUsd)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('IDR'),
                              Text(
                                'Rp ${idrFormatter.format(ethIdr)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Actions 
              const Text(
                'Aksi Cepat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _ActionCard(
                    icon: Icons.send,
                    label: 'Kirim TX',
                    enabled: isInSafeZone && address != null,
                    onTap: () => context.push('/send'),
                  ),
                  _ActionCard(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan QR',
                    onTap: () => context.push('/scanner'),
                  ),
                  _ActionCard(
                    icon: Icons.smart_toy,
                    label: 'AI Chat',
                    onTap: () => context.push('/chat'),
                  ),
                  _ActionCard(
                    icon: Icons.videogame_asset,
                    label: 'Reaction Game',
                    onTap: () => context.push('/game'),
                  ),
                  _ActionCard(
                    icon: Icons.history,
                    label: 'Riwayat',
                    onTap: () => context.push('/history'),
                  ),
                  _ActionCard(
                    icon: Icons.location_on,
                    label: 'Safe Zone',
                    onTap: _checkSafeZone,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Shake Hint 
              Center(
                child: Text(
                  'Goyangkan ponsel untuk sembunyikan/lihat balance',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: enabled ? const Color(0xFF6C63FF) : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? null : Colors.grey,
                ),
              ),
              if (!enabled)
                const Text(
                  '(tidak tersedia)',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
