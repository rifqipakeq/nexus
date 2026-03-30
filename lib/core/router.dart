import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/biometric_screen.dart';
import '../presentation/screens/dashboard_screen.dart';
import '../presentation/screens/chat_screen.dart';
import '../presentation/screens/game_screen.dart';
import '../presentation/screens/scanner_screen.dart';
import '../presentation/screens/send_transaction_screen.dart';
import '../presentation/screens/history_screen.dart';

/// GoRouter configuration with all app routes.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/biometric',
        builder: (context, state) => const BiometricScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(path: '/game', builder: (context, state) => const GameScreen()),
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
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
});
