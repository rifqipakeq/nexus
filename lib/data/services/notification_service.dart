import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles local notifications and Firebase Cloud Messaging setup.
class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ─── Initialization ───────────────────────────────────────────

  Future<void> initialize({bool firebaseAvailable = true}) async {
    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) {
          print('Notification tapped: ${details.payload}');
        }
      },
    );

    // Firebase Messaging setup (only if Firebase is available)
    if (firebaseAvailable) {
      await _setupFirebaseMessaging();
    }
  }

  // ─── Local Notifications ──────────────────────────────────────

  /// Show price alert notification.
  Future<void> showPriceAlert({
    required double oldPrice,
    required double newPrice,
  }) async {
    final percentChange = ((newPrice - oldPrice) / oldPrice * 100)
        .toStringAsFixed(2);

    await _localNotifications.show(
      1,
      '📈 ETH Price Alert',
      'ETH price increased by $percentChange% → \$${newPrice.toStringAsFixed(2)}',
      _defaultDetails(),
      payload: 'price_alert',
    );
  }

  /// Show inactivity reminder.
  Future<void> showInactivityReminder() async {
    await _localNotifications.show(
      2,
      '⏰ Inactivity Reminder',
      'You have been inactive for a while. Your session will expire soon.',
      _defaultDetails(),
      payload: 'inactivity',
    );
  }

  /// Show generic notification.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      _defaultDetails(),
      payload: payload,
    );
  }

  NotificationDetails _defaultDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'nexus_node_channel',
        'NexusNode Notifications',
        channelDescription: 'NexusNode Lite notification channel',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  // ─── Firebase Cloud Messaging ─────────────────────────────────

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Get FCM token
    final token = await messaging.getToken();
    if (kDebugMode) {
      print('FCM Token: $token');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(
          id: DateTime.now().millisecond,
          title: message.notification!.title ?? 'NexusNode',
          body: message.notification!.body ?? '',
        );
      }
    });

    // Handle background/terminated messages are handled in main.dart
  }
}
