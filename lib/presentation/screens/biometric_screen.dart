import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';

class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});

  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  bool _isAuthenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    try {
      final biometricService = ref.read(biometricAuthServiceProvider);
      final availability = await biometricService.checkAvailability();

      if (!availability.isAvailable || !availability.hasEnrolled) {
        debugPrint('Fitur Biometrik tidak tersedia: ${availability.reason}');
        await _proceedToDashboard();
        return;
      }

      // cek session aktif dan cek user terkait biometric keys
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        final auth = ref.read(authServiceProvider);
        final savedUser = await auth.getActiveUser();
        if (savedUser != null) {
          ref.read(currentUserProvider.notifier).state = savedUser;
          final hasKeys = await biometricService.hasEnrolledKeys(savedUser.id);
          if (hasKeys) {
            final result = await biometricService.authenticate(savedUser.id);
            if (result != null && result.success) {
              await _proceedToDashboard();
              return;
            }
            setState(() => _error = 'Verifikasi biometrik gagal. Coba lagi.');
            return;
          }
        }

        final success = await biometricService.simpleAuthenticate();
        if (success) {
          await _proceedToDashboard();
        } else {
          setState(() => _error = 'Autentikasi gagal. Coba lagi.');
        }
        return;
      }

      // jika user sudah login dan punya biometric keys, langsung authenticate
      final hasKeys = await biometricService.hasEnrolledKeys(currentUser.id);
      if (hasKeys) {
        final result = await biometricService.authenticate(currentUser.id);
        if (result != null && result.success) {
          await _proceedToDashboard();
          return;
        }
        setState(() => _error = 'Verifikasi biometrik gagal. Coba lagi.');
      } else {
        // jika sudah login tapi belum setup biometric, fallback ke simple prompt untuk verifikasi
        final success = await biometricService.simpleAuthenticate();
        if (success) {
          await _proceedToDashboard();
        } else {
          setState(() => _error = 'Autentikasi gagal. Coba lagi.');
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _proceedToDashboard() async {
    if (!mounted) return;

    // Pastikan data user sudah dimuat ke provider sebelum navigasi
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      final storage = ref.read(userScopedStorageProvider);
      await storage.openForUser(currentUser.id);

      // Set active user di blockchain service untuk akses data terkait user
      final blockchain = ref.read(blockchainServiceProvider);
      blockchain.setActiveUser(currentUser.id);

      _loadUserData(storage);
    }

    if (mounted) context.go('/dashboard');
  }

  void _loadUserData(dynamic storage) {
    ref.read(walletAddressProvider.notifier).state = storage.getWalletAddress();
    ref.read(walletBalanceProvider.notifier).state = storage.getBalance();
    ref.read(chatHistoryProvider.notifier).state = storage.getChatHistory();
    ref.read(gameScoreProvider.notifier).state = storage.getGameScore();
    ref.read(highScoreProvider.notifier).state = storage.getHighScore();
    ref.read(totalGamesProvider.notifier).state = storage.getTotalGames();
    ref.read(ethPriceProvider.notifier).state = storage.getCachedPrices();
    // Legacy tx history (for backward compat)
    ref.read(transactionHistoryProvider.notifier).state =
        storage.getTransactionHistory();
    // Einstein: load cached rich tx history
    final cachedTxV2 = storage.getTxHistoryV2();
    if (cachedTxV2.isNotEmpty) {
      // Import is not needed here — txHistoryProvider holds TxRecord objects,
      // but we just seed from Hive raw maps; dashboard will re-fetch properly.
      // We leave txHistoryProvider empty here; HistoryScreen re-fetches on open.
    }
    // Einstein: premium & quiz tokens
    ref.read(isPremiumProvider.notifier).state = storage.isPremium;
    ref.read(quizTokensProvider.notifier).state = storage.getQuizTokens();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fingerprint,
                  size: 100,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verifikasi Biometrik',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifikasi identitas Anda untuk melanjutkan',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pastikan Anda sudah mengaktifkan biometrik di pengaturan akun.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                const SizedBox(height: 32),

                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else ...[
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Autentikasi Ulang'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _proceedToDashboard(),
                    child: const Text('Skip dan Lanjutkan ke Dashboard'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}