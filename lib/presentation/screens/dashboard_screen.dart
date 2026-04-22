import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../providers.dart';

/// Main dashboard showing wallet info, prices, and navigation to features.
///
/// Key changes for multi-account support:
/// - Uses UserScopedStorage instead of global LocalDatabaseService
/// - Displays current user info
/// - Logout clears all user-scoped state
/// - Balance polling detects incoming ETH for notifications
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = false;
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

      // Fetch balance if wallet exists
      final address = ref.read(walletAddressProvider);
      if (address != null) {
        final blockchain = ref.read(blockchainServiceProvider);
        final balance = await blockchain.getBalance(address);

        // Check for balance changes (incoming ETH detection)
        final lastNotified = storage.getLastNotifiedBalance();
        final notifications = ref.read(notificationServiceProvider);
        final notified = await notifications.checkBalanceChange(
          currentBalance: balance,
          lastNotifiedBalance: lastNotified,
        );
        if (notified) {
          await storage.saveLastNotifiedBalance(balance);
        }

        ref.read(walletBalanceProvider.notifier).state = balance;
        await storage.saveBalance(balance);
      }
    } catch (_) {
      // Use cached data on error (offline support)
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
        ref.read(balanceVisibleProvider.notifier).state =
            !ref.read(balanceVisibleProvider);
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
        title: const Text('Wallet Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Save your private key securely!\nIt will not be shown again.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Address:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              wallet['address']!,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Private Key:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              wallet['privateKey']!,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Saved It'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    // 1. Close user-scoped storage (prevents data leakage)
    final storage = ref.read(userScopedStorageProvider);
    await storage.closeUserBoxes();

    // 2. Clear blockchain service active user
    final blockchain = ref.read(blockchainServiceProvider);
    blockchain.clearActiveUser();

    // 3. Log out from auth service (clears session in secure storage)
    final auth = ref.read(authServiceProvider);
    await auth.logout();

    // 4. Reset ALL user-scoped providers to prevent stale data
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

    // 5. Navigate to login
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('NexusNode Lite'),
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
              // ─── User Info ──────────────────────────────
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
                        'Hello, ${currentUser.username}',
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

              // ─── Wallet Card ──────────────────────────
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
                          IconButton(
                            icon: Icon(
                              balanceVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              ref.read(balanceVisibleProvider.notifier).state =
                                  !balanceVisible;
                            },
                          ),
                        ],
                      ),
                      if (address != null) ...[
                        Text(
                          '${address.substring(0, 6)}...${address.substring(address.length - 4)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
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
                          '📍 ${isInSafeZone ? "Inside Safe Zone" : "Outside Safe Zone"}',
                          style: TextStyle(
                            color: isInSafeZone
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        const Text('No wallet yet'),
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

              // ─── Price Card ───────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ETH Price',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('USD'),
                            Text(
                              '\$${ethUsd.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('IDR'),
                            Text(
                              'Rp ${ethIdr.toStringAsFixed(0)}',
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

              // ─── Quick Actions ────────────────────────
              const Text(
                'Quick Actions',
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
                    label: 'Send TX',
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
                    label: 'Price Game',
                    onTap: () => context.push('/game'),
                  ),
                  _ActionCard(
                    icon: Icons.history,
                    label: 'History',
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

              // ─── Shake Hint ───────────────────────────
              Center(
                child: Text(
                  '📱 Shake device to toggle balance visibility',
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
                  '(unavailable)',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
