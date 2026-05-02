import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/screens/review_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/register_screen.dart';
import '../presentation/screens/biometric_screen.dart';
import '../presentation/screens/dashboard_screen.dart';
import '../presentation/screens/chat_screen.dart';
import '../presentation/screens/quiz_screen.dart';
import '../presentation/screens/scanner_screen.dart';
import '../presentation/screens/send_transaction_screen.dart';
import '../presentation/screens/history_screen.dart';
import '../presentation/screens/account_switcher_screen.dart';
import '../presentation/screens/safe_zone_screen.dart';
import '../presentation/screens/debug_storage_screen.dart';
import '../presentation/screens/transaction_detail_screen.dart';
import '../presentation/screens/swap_screen.dart';
import '../data/models/tx_record.dart';

/// GoRouter config
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/biometric',
        builder: (context, state) => const BiometricScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(path: '/game', builder: (context, state) => const QuizScreen()),
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/send',
        builder: (context, state) => const SendTransactionScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AccountSwitcherScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: '/safe-zones',
        builder: (context, state) => const SafeZoneScreen(),
      ),
      GoRoute(
        path: '/tx-detail',
        builder: (context, state) {
          final tx = state.extra as TxRecord;
          return TransactionDetailScreen(tx: tx);
        },
      ),
      // Einstein: Token Swap
      GoRoute(path: '/swap', builder: (context, state) => const SwapScreen()),
      if (kDebugMode)
        GoRoute(
          path: '/debug-storage',
          builder: (context, state) => const DebugStorageScreen(),
        ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
  );
});
