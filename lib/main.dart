import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'core/session_manager.dart';
import 'core/router.dart';
import 'data/local/user_scoped_storage.dart';
import 'data/services/security_service.dart';
import 'data/services/auth_service.dart';
import 'data/services/notification_service.dart';
import 'presentation/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize global storage (prices box)
  final storage = UserScopedStorage();
  await storage.initGlobal();

  // Initialize the accounts box
  final auth = AuthService();
  await auth.init();

  // Initialize encryption keys
  final security = SecurityService();
  await security.ensureEncryptionKeys();

  // Initialize local notifications (no Firebase)
  final notifications = NotificationService();
  try {
    await notifications.initialize();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  // Pass pre-initialized instances into Riverpod so providers don't
  // create separate (uninitialized) objects.
  runApp(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userScopedStorageProvider.overrideWithValue(storage),
        securityServiceProvider.overrideWithValue(security),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const NexusNodeApp(),
    ),
  );
}

class NexusNodeApp extends ConsumerWidget {
  const NexusNodeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return SessionManager(
      timeout: AppConstants.inactivityTimeout,
      onTimeout: () {
        // Auto-logout: navigate to login
        router.go('/login');
      },
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );
  }
}
