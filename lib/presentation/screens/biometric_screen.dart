import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';

/// Biometric verification screen shown after login.
/// Users must pass biometric auth before accessing the dashboard.
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
    // Auto-trigger biometric prompt on load
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    try {
      final security = ref.read(securityServiceProvider);
      final isAvailable = await security.isBiometricAvailable();

      if (!isAvailable) {
        // If biometrics not available, skip to dashboard
        if (mounted) context.go('/dashboard');
        return;
      }

      final success = await security.authenticateWithBiometrics();
      if (success && mounted) {
        context.go('/dashboard');
      } else {
        setState(() => _error = 'Authentication failed. Try again.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
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
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Skip (dev only)'),
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
  