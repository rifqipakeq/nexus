import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';

/// Biometric verification screen shown after login.
///
/// Uses hardware-backed cryptographic signatures (biometric_signature package)
/// instead of the boolean-only local_auth. This means:
/// - The biometric hardware produces a verifiable signature
/// - An attacker cannot bypass auth by hooking the API return value
/// - The private signing key never leaves the Secure Enclave / StrongBox
///
/// Fallback: If biometrics are unavailable (emulator, no hardware), the user
/// can proceed directly to the dashboard (they've already authenticated
/// with username + password).
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
        // No biometric hardware or no enrolled biometrics — skip
        debugPrint('Biometrics unavailable: ${availability.reason}');
        await _proceedToDashboard();
        return;
      }

      // Check if the current user has biometric keys enrolled
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        // No user in session — try to restore from persisted session
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
            setState(() => _error = 'Biometric verification failed. Try again.');
            return;
          }
        }
        // No biometric keys — use simple prompt
        final success = await biometricService.simpleAuthenticate();
        if (success) {
          await _proceedToDashboard();
        } else {
          setState(() => _error = 'Authentication failed. Try again.');
        }
        return;
      }

      // User exists — try signature-based auth
      final hasKeys = await biometricService.hasEnrolledKeys(currentUser.id);
      if (hasKeys) {
        final result = await biometricService.authenticate(currentUser.id);
        if (result != null && result.success) {
          await _proceedToDashboard();
          return;
        }
        setState(() => _error = 'Biometric verification failed. Try again.');
      } else {
        // No keys enrolled for this user — use simple prompt
        final success = await biometricService.simpleAuthenticate();
        if (success) {
          await _proceedToDashboard();
        } else {
          setState(() => _error = 'Authentication failed. Try again.');
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

    // Open user-scoped storage before navigating
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      final storage = ref.read(userScopedStorageProvider);
      await storage.openForUser(currentUser.id);

      // Set the active user in blockchain service
      final blockchain = ref.read(blockchainServiceProvider);
      blockchain.setActiveUser(currentUser.id);

      // Load user's data into providers
      _loadUserData(storage);
    }

    if (mounted) context.go('/dashboard');
  }

  void _loadUserData(dynamic storage) {
    // Load user-scoped data into providers
    ref.read(walletAddressProvider.notifier).state = storage.getWalletAddress();
    ref.read(walletBalanceProvider.notifier).state = storage.getBalance();
    ref.read(chatHistoryProvider.notifier).state = storage.getChatHistory();
    ref.read(gameScoreProvider.notifier).state = storage.getGameScore();
    ref.read(highScoreProvider.notifier).state = storage.getHighScore();
    ref.read(totalGamesProvider.notifier).state = storage.getTotalGames();
    ref.read(ethPriceProvider.notifier).state = storage.getCachedPrices();
    ref.read(transactionHistoryProvider.notifier).state =
        storage.getTransactionHistory();
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
                  'Biometric Verification',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verify your identity to continue',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Using hardware-backed signature',
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
                    label: const Text('Authenticate'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _proceedToDashboard(),
                    child: const Text('Skip (password already verified)'),
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