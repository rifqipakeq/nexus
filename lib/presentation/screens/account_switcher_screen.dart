import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';

class AccountSwitcherScreen extends ConsumerWidget {
  const AccountSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final accounts = auth.getAllAccounts();
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Akun')),
      body: accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada akun yang tersimpan.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Buat Akun'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length + 1, // +1 untuk tombol "Add Account"
              itemBuilder: (context, index) {
                if (index == accounts.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/register'),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Tambah Akun Baru'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  );
                }

                final account = accounts[index];
                final isActive = currentUser?.id == account.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? const Color(0xFF6C63FF)
                          : Colors.grey[700],
                      child: Text(
                        account.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      account.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Created: ${_formatDate(account.createdAt)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        if (account.biometricPublicKey != null)
                          const Text(
                            'Biometrik terdaftar',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.greenAccent,
                            ),
                          ),
                      ],
                    ),
                    trailing: isActive
                        ? const Chip(
                            label: Text('Aktif', style: TextStyle(fontSize: 11)),
                            backgroundColor: Color(0xFF6C63FF),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: isActive
                        ? null
                        : () => _switchToAccount(context, ref, account.id),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _switchToAccount(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final auth = ref.read(authServiceProvider);

    final account = auth.getUserById(userId);
    if (account == null) return;

    if (account.biometricPublicKey != null) {
      final result = await auth.loginWithBiometric(userId);
      // Always check mounted after every await
      if (!context.mounted) return;
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Autentikasi biometrik gagal'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      ref.read(currentUserProvider.notifier).state = result.user;
    } else {
      final result = await auth.switchAccount(userId);
      if (!context.mounted) return;
      if (!result.success) return;
      ref.read(currentUserProvider.notifier).state = result.user;
    }

    if (context.mounted) {
      context.go('/biometric');
    }
  }

  String _formatDate(String iso8601) {
    try {
      final dt = DateTime.parse(iso8601);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso8601;
    }
  }
}
