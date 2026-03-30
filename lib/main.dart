import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'core/session_manager.dart';
import 'core/router.dart';
import 'data/local/local_database_service.dart';
import 'data/services/security_service.dart';
import 'data/services/notification_service.dart';

/// Background message handler for Firebase Cloud Messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize Firebase
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    firebaseReady = true;
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase init failed: $e');
    debugPrint('App will run without Firebase features');
  }

  // Initialize local database
  final localDb = LocalDatabaseService();
  await localDb.init();

  // Initialize encryption keys
  final security = SecurityService();
  await security.ensureEncryptionKeys();

  // Initialize notifications
  final notifications = NotificationService();
  try {
    await notifications.initialize(firebaseAvailable: firebaseReady);
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  runApp(const ProviderScope(child: NexusNodeApp()));
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
