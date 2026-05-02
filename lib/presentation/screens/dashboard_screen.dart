import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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
  String _selectedCurrency = 'usd';
  String selectedCurrency = 'usd';
  bool _wasVisibleBeforeProximity = true;
  bool _isProximityNear = false;
  Timer? _balancePollTimer;
  Timer? _pricePollTimer;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _loadUserPreferences();
    _loadData();
    _loadPremiumState();
    _startMotionDetection();
    _startProximityDetection();
    _startBalancePolling();
    _startPricePolling();
  }

  Future<void> _loadPremiumState() async {
    final storage = ref.read(userScopedStorageProvider);
    // Load premium & quiz tokens from Hive
    ref.read(isPremiumProvider.notifier).state = storage.isPremium;
    ref.read(quizTokensProvider.notifier).state = storage.getQuizTokens();
    // Load ERC-20 tokens
    await _loadErc20Tokens(); // einstein
  }

// einstein
  Future<void> _loadErc20Tokens() async {
    final address = ref.read(walletAddressProvider);
    if (address == null) return;
    ref.read(tokenListLoadingProvider.notifier).state = true;
    try {
      final tokenService = ref.read(tokenServiceProvider);
      // Load cached first for instant display
      final cached = tokenService.loadCached();
      if (cached.isNotEmpty) {
        ref.read(tokenListProvider.notifier).state = cached;
      }
      // Fetch fresh balances
      final fresh = await tokenService.fetchBalances(address);
      if (mounted) {
        ref.read(tokenListProvider.notifier).state = fresh;
      }
    } catch (_) {} finally {
      if (mounted) {
        ref.read(tokenListLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    final storage = ref.read(userScopedStorageProvider);
    final zones = storage.getSafeZones();
    ref.read(userSafeZonesProvider.notifier).state = zones;
    final hasConfigured = storage.getHasConfiguredZones();
    ref.read(userHasConfiguredZonesProvider.notifier).state = hasConfigured;
    final tz2 = storage.getSelectedTimezone();
    ref.read(selectedTimezoneProvider.notifier).state = tz2;
    await _checkSafeZone();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(userScopedStorageProvider);

      // Fetch ETH price (USD, IDR, CNY)
      final priceService = ref.read(priceServiceProvider);
      final prices = await priceService.getEthPrice();
      ref.read(ethPriceProvider.notifier).state = prices;
      await storage.cachePrices(prices);

      // Fetch balance
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

  Future<void> _refreshBalance() async {
    if (!mounted) return;
    final address = ref.read(walletAddressProvider);
    if (address == null) return;
    try {
      final blockchain = ref.read(blockchainServiceProvider);
      final storage = ref.read(userScopedStorageProvider);
      final balance = await blockchain.getBalance(address);
      if (!mounted) return;

      // Incoming ETH detection
      final lastNotified = storage.getLastNotifiedBalance();
      final notifications = ref.read(notificationServiceProvider);
      final notified = await notifications.checkBalanceChange(
        currentBalance: balance,
        lastNotifiedBalance: lastNotified,
      );
      if (!mounted) return;
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
        if (!mounted) return;
        ref.read(transactionHistoryProvider.notifier).state = storage
            .getTransactionHistory();
        await storage.saveLastNotifiedBalance(balance);
      }

      ref.read(walletBalanceProvider.notifier).state = balance;
      await storage.saveBalance(balance);
    } catch (_) {}
  }

  void _startBalancePolling() {
    _balancePollTimer = Timer.periodic(
      AppConstants.balancePollInterval,
      (_) => _refreshBalance(),
    );
  }

  Future<void> _refreshPrice() async {
    if (!mounted) return;
    try {
      final priceService = ref.read(priceServiceProvider);
      final storage = ref.read(userScopedStorageProvider);
      final prices = await priceService.getEthPrice();
      if (!mounted) return;
      ref.read(ethPriceProvider.notifier).state = prices;
      await storage.cachePrices(prices);
    } catch (_) {}
  }

  void _startPricePolling() {
    _pricePollTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshPrice(),
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

  void _startProximityDetection() {
    final motionService = ref.read(motionServiceProvider);
    motionService.startProximityListening(
      onNear: () {
        if (!_isProximityNear) {
          _isProximityNear = true;
          _wasVisibleBeforeProximity = ref.read(balanceVisibleProvider);
          ref.read(balanceVisibleProvider.notifier).state = false;
        }
      },
      onFar: () {
        if (_isProximityNear) {
          _isProximityNear = false;
          ref.read(balanceVisibleProvider.notifier).state =
              _wasVisibleBeforeProximity;
        }
      },
    );
  }

  Future<void> _checkSafeZone() async {
    final locationService = ref.read(locationServiceProvider);
    final userZones = ref.read(userSafeZonesProvider);
    final hasConfigured = ref.read(userHasConfiguredZonesProvider);
    final isInside = await locationService.isInsideAnyZone(
      userZones,
      userHasConfiguredZones: hasConfigured,
    );
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
        title: const Text('Wallet Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simpan private key anada!\n',
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
            child: const Text('Saya sudah simpan'),
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
        content: Text('Address tercopy!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Profile image
  Future<void> _pickAvatar() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 75,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64Img = base64Encode(bytes);

    final auth = ref.read(authServiceProvider);
    final updated = await auth.updateAvatar(currentUser.id, base64Img);
    if (updated != null) {
      ref.read(currentUserProvider.notifier).state = updated;
    }
  }

  Future<void> _logout() async {
    final storage = ref.read(userScopedStorageProvider);
    await storage.closeUserBoxes();

    final blockchain = ref.read(blockchainServiceProvider);
    blockchain.clearActiveUser();

    final auth = ref.read(authServiceProvider);
    await auth.logout();

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
    ref.invalidate(txHistoryProvider);
    ref.invalidate(userSafeZonesProvider);
    ref.invalidate(userHasConfiguredZonesProvider);
    ref.invalidate(selectedTimezoneProvider);
    ref.invalidate(tokenListProvider); // einstein
    ref.invalidate(isPremiumProvider);
    ref.invalidate(quizTokensProvider);

    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _balancePollTimer?.cancel();
    _pricePollTimer?.cancel();
    ref.read(motionServiceProvider).stopAll();
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

    ref.listen<List<Map<String, dynamic>>>(userSafeZonesProvider, (_, __) {
      _checkSafeZone();
    });

    final ethUsd = prices['usd'] ?? 0.0;
    final ethIdr = prices['idr'] ?? 0.0;
    final ethCny = prices['cny'] ?? 0.0;

    void _changeCurrency() {
      setState(() {
        if (selectedCurrency == 'usd') {
          selectedCurrency = 'idr';
        } else if (selectedCurrency == 'idr') {
          selectedCurrency = 'cny';
        } else {
          selectedCurrency = 'usd';
        }
      });
    }

    double getConvertedBalance() {
      switch (selectedCurrency) {
        case 'idr':
          return balance * ethIdr;
        case 'cny':
          return balance * ethCny;
        default:
          return balance * ethUsd;
      }
    }

    final idrFormatter = NumberFormat('#,##0', 'id_ID');
    final usdFormatter = NumberFormat('#,##0.00', 'en_US');
    final cnyFormatter = NumberFormat('#,##0.00', 'zh_CN');

    String getFormattedBalance() {
      final value = getConvertedBalance();

      switch (selectedCurrency) {
        case 'idr':
          return 'Rp ${idrFormatter.format(value)}';
        case 'cny':
          return '¥ ${cnyFormatter.format(value)}';
        default:
          return '\$ ${usdFormatter.format(value)}';
      }
    }

    ImageProvider? avatarImage;
    if (currentUser?.avatarBase64 != null &&
        currentUser!.avatarBase64!.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(currentUser.avatarBase64!));
      } catch (_) {
        avatarImage = null;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
        title: const Text('Nexus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () => context.push('/accounts'),
            tooltip: 'Ganti akun',
          ),
          IconButton(
            icon: const Icon(Icons.reviews_outlined),
            onPressed: () => context.push('/review'),
            tooltip: 'Review',
          ),
        ],
      ),
      body: Column(
        children: [
          _ClockWidget(onRefresh: _checkSafeZone),
          Expanded(
            child: RefreshIndicator(
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
                            GestureDetector(
                              onTap: _pickAvatar,
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF6C63FF),
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? Text(
                                        currentUser.username[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
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
                                  const SizedBox(height: 4),
                                  // Quiz token chip + premium badge
                                  Consumer(
                                    builder: (_, ref, __) {
                                      final tokens = ref.watch(quizTokensProvider);
                                      final isPremium = ref.watch(isPremiumProvider);
                                      return Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.token, size: 11, color: Color(0xFF6C63FF)),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '$tokens tokens',
                                                  style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 10, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isPremium) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'PREMIUM',
                                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                ],
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
                                    if (address != null)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.qr_code,
                                          size: 22,
                                        ),
                                        onPressed: () => _showQrCode(address),
                                        tooltip: 'Show QR Code',
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        balanceVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        ref
                                                .read(
                                                  balanceVisibleProvider
                                                      .notifier,
                                                )
                                                .state =
                                            !balanceVisible;
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (address != null) ...[
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
                              GestureDetector(
                                onTap: _changeCurrency,
                                child: Text(
                                  balanceVisible
                                      ? getFormattedBalance()
                                      : '••••',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '📍 ${isInSafeZone ? "Di Dalam Zona Aman" : "Di Luar Zona Aman"}',
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
                                  'Harga ETH',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Currency dropdown
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[700]!,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCurrency,
                                      isDense: true,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'usd',
                                          child: Text('USD'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'idr',
                                          child: Text('IDR'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'cny',
                                          child: Text('CNY'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _selectedCurrency = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else
                              _buildPriceRow(
                                currency: _selectedCurrency,
                                ethUsd: ethUsd,
                                ethIdr: ethIdr,
                                ethCny: ethCny,
                                usdFormatter: usdFormatter,
                                idrFormatter: idrFormatter,
                                cnyFormatter: cnyFormatter,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ERC-20 Token List (Einstein)
                    if (address != null)
                      _TokenListCard(
                        onRefresh: _loadErc20Tokens,
                      ),

                    const SizedBox(height: 16),

                    // Quick Actions
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
                          label: 'Transfer',
                          enabled: isInSafeZone && address != null,
                          onTap: () async {
                            await context.push('/send');
                            await _refreshBalance();
                          },
                        ),
                        // einstein
                        _ActionCard(
                          icon: Icons.swap_horiz,
                          label: 'Swap Tokens',
                          onTap: () => context.push('/swap'),
                        ),
                        _ActionCard(
                          icon: Icons.smart_toy,
                          label: 'Nexus Bot',
                          onTap: () => context.push('/chat'),
                        ),
                        _ActionCard(
                          icon: Icons.quiz,
                          label: 'Crypto Quiz',
                          onTap: () async {
                            await context.push('/game');
                            _loadPremiumState();
                          },
                        ),
                        _ActionCard(
                          icon: Icons.history,
                          label: 'Riwayat',
                          onTap: () => context.push('/history'),
                        ),
                        _ActionCard(
                          icon: Icons.shield,
                          label: 'Zona Aman',
                          onTap: () async {
                            await context.push('/safe-zones');
                            await _checkSafeZone();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sensor hints
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Goyangkan device untuk mengalihkan visibilitas saldo',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tutup sensor jarak untuk menyembunyikan saldo',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow({
    required String currency,
    required double ethUsd,
    required double ethIdr,
    required double ethCny,
    required NumberFormat usdFormatter,
    required NumberFormat idrFormatter,
    required NumberFormat cnyFormatter,
  }) {
    String label;
    String formattedPrice;

    switch (currency) {
      case 'idr':
        label = 'Rupiah';
        formattedPrice = 'Rp ${idrFormatter.format(ethIdr)}';
        break;
      case 'cny':
        label = 'Yuan';
        formattedPrice = '¥ ${cnyFormatter.format(ethCny)}';
        break;
      case 'usd':
      default:
        label = 'Dollar';
        formattedPrice = '\$${usdFormatter.format(ethUsd)}';
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          formattedPrice,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }
}

// einstein
/// ERC-20 token list card for the dashboard.
class _TokenListCard extends ConsumerWidget {
  final Future<void> Function() onRefresh;
  const _TokenListCard({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(tokenListProvider);
    final isLoading = ref.watch(tokenListLoadingProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tokens',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6C63FF),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: onRefresh,
                        tooltip: 'Refresh token balances',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Sepolia',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ETH row (always shown)
            Consumer(
              builder: (_, ref, __) {
                final balance = ref.watch(walletBalanceProvider);
                return _TokenRow(
                  symbol: 'ETH',
                  name: 'Ethereum',
                  balance: balance.toStringAsFixed(6),
                  color: const Color(0xFF627EEA),
                );
              },
            ),
            const Divider(color: Colors.white12, height: 16),
            // ERC-20 rows
            if (tokens.isEmpty && !isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No token balances found on Sepolia.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              )
            else
              ...tokens.asMap().entries.map((entry) {
                final token = entry.value;
                final isLast = entry.key == tokens.length - 1;
                return Column(
                  children: [
                    _TokenRow(
                      symbol: token.symbol,
                      name: token.name,
                      balance: token.balanceFormatted,
                      color: _tokenColor(token.symbol),
                    ),
                    if (!isLast)
                      const Divider(color: Colors.white12, height: 16),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Color _tokenColor(String symbol) {
    switch (symbol) {
      case 'LINK':
        return const Color(0xFF2A5ADA);
      case 'UNI':
        return const Color(0xFFFF007A);
      case 'USDC':
        return const Color(0xFF2775CA);
      default:
        return const Color(0xFF6C63FF);
    }
  }
}

class _TokenRow extends StatelessWidget {
  final String symbol;
  final String name;
  final String balance;
  final Color color;

  const _TokenRow({
    required this.symbol,
    required this.name,
    required this.balance,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              symbol[0],
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                name,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          balance,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
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

class _ClockWidget extends ConsumerStatefulWidget {
  final Future<void> Function() onRefresh;
  const _ClockWidget({required this.onRefresh});

  @override
  ConsumerState<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends ConsumerState<_ClockWidget> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  static const List<Map<String, String>> _timezones = [
    {'label': 'Jakarta', 'sub': 'WIB · UTC+7', 'tz': 'Asia/Jakarta'},
    {'label': 'Makassar', 'sub': 'WITA · UTC+8', 'tz': 'Asia/Makassar'},
    {'label': 'Jayapura', 'sub': 'WIT · UTC+9', 'tz': 'Asia/Jayapura'},
    {'label': 'London', 'sub': 'GMT/BST', 'tz': 'Europe/London'},
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(String tzName) {
    try {
      final location = tz.getLocation(tzName);
      final tzNow = tz.TZDateTime.from(_now, location);
      final h = tzNow.hour.toString().padLeft(2, '0');
      final m = tzNow.minute.toString().padLeft(2, '0');
      final s = tzNow.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      final h = _now.hour.toString().padLeft(2, '0');
      final m = _now.minute.toString().padLeft(2, '0');
      final s = _now.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
  }

  String _formatDate(String tzName) {
    try {
      final location = tz.getLocation(tzName);
      final tzNow = tz.TZDateTime.from(_now, location);
      return DateFormat('EEE, d MMM yyyy', 'en_US').format(tzNow);
    } catch (_) {
      return DateFormat('EEE, d MMM yyyy', 'en_US').format(_now);
    }
  }

  void _openTimezonePicker() {
    final currentTz = ref.read(selectedTimezoneProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Pilih Zona Waktu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ..._timezones.map((tzOption) {
              final selected = tzOption['tz'] == currentTz;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: selected
                    ? const Color(0xFF6C63FF).withAlpha(40)
                    : Colors.transparent,
                leading: Icon(
                  Icons.language,
                  color: selected ? const Color(0xFF6C63FF) : Colors.white54,
                ),
                title: Text(
                  tzOption['label']!,
                  style: TextStyle(
                    color: selected ? const Color(0xFF6C63FF) : Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  tzOption['sub']!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: Color(0xFF6C63FF))
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final storage = ref.read(userScopedStorageProvider);
                  await storage.saveSelectedTimezone(tzOption['tz']!);
                  ref.read(selectedTimezoneProvider.notifier).state =
                      tzOption['tz']!;
                  await widget.onRefresh();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTz = ref.watch(selectedTimezoneProvider);
    final tzMeta = _timezones.firstWhere(
      (t) => t['tz'] == selectedTz,
      orElse: () => _timezones.first,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0F3460),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Clock display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(selectedTz),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                _formatDate(selectedTz),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),

          GestureDetector(
            onTap: _openTimezonePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withAlpha(40),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withAlpha(120),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.language,
                    size: 13,
                    color: Color(0xFF6C63FF),
                  ),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tzMeta['label']!,
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        tzMeta['sub']!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more,
                    size: 14,
                    color: Color(0xFF6C63FF),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
