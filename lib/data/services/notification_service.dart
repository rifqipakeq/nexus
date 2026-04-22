import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles local-only notifications. All Firebase dependencies have been removed.
///
/// ## Notification Strategy (No Firebase)
///
/// Since we cannot receive push notifications without a server, we use a
/// **polling-based approach** for balance change detection:
///
/// 1. The dashboard periodically refreshes the wallet balance (via timer or pull-to-refresh).
/// 2. When the balance changes, we compare against the last known balance:
///    - **Increase** → "Received ETH" notification
///    - **Decrease** → "Sent ETH" notification (also triggered immediately on send)
/// 3. Deduplication: We track `lastNotifiedBalance` in Hive to avoid
///    re-notifying for the same balance value.
///
/// ## Notification Types
/// - **Transaction sent**: Triggered immediately when `sendTransaction` succeeds
/// - **Balance received**: Detected via polling, shown as local notification
/// - **Price alert**: Shown when ETH price changes significantly
/// - **Inactivity reminder**: Shown before session timeout
///
/// ## Foreground/Background Handling
/// - Foreground: Notifications shown via `flutter_local_notifications`
/// - Background: Without Firebase, notifications only fire while the app process
///   is alive. This is a known limitation of the no-backend architecture.
class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Monotonically increasing notification ID to prevent collisions.
  int _nextNotificationId = 100;

  // ─── Initialization ───────────────────────────────────────────

  Future<void> initialize() async {
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
        debugPrint('Notification tapped: ${details.payload}');
      },
    );
  }

  // ─── Transaction Notifications ────────────────────────────────

  /// Show notification when a transaction is sent.
  Future<void> showTransactionSent({
    required double amount,
    required String toAddress,
    required String txHash,
  }) async {
    final shortAddress = toAddress.length > 10
        ? '${toAddress.substring(0, 6)}...${toAddress.substring(toAddress.length - 4)}'
        : toAddress;

    await _show(
      title: '📤 ETH Sent',
      body: 'Sent ${amount.toStringAsFixed(6)} ETH to $shortAddress',
      payload: 'tx_sent:$txHash',
      channelId: 'nexus_transactions',
      channelName: 'Transaction Notifications',
    );
  }

  /// Show notification when incoming ETH is detected (via balance polling).
  Future<void> showBalanceReceived({
    required double previousBalance,
    required double newBalance,
  }) async {
    final received = newBalance - previousBalance;
    if (received <= 0) return;

    await _show(
      title: '📥 ETH Received',
      body:
          'Received ${received.toStringAsFixed(6)} ETH\nNew balance: ${newBalance.toStringAsFixed(6)} ETH',
      payload: 'balance_received',
      channelId: 'nexus_transactions',
      channelName: 'Transaction Notifications',
    );
  }

  // ─── Price Alerts ─────────────────────────────────────────────

  /// Show price alert notification.
  Future<void> showPriceAlert({
    required double oldPrice,
    required double newPrice,
  }) async {
    final percentChange = ((newPrice - oldPrice) / oldPrice * 100)
        .toStringAsFixed(2);
    final direction = newPrice > oldPrice ? '📈' : '📉';

    await _show(
      title: '$direction ETH Price Alert',
      body:
          'ETH price changed by $percentChange% → \$${newPrice.toStringAsFixed(2)}',
      payload: 'price_alert',
      channelId: 'nexus_price_alerts',
      channelName: 'Price Alerts',
    );
  }

  // ─── Inactivity ───────────────────────────────────────────────

  /// Show inactivity reminder.
  Future<void> showInactivityReminder() async {
    await _show(
      title: '⏰ Inactivity Reminder',
      body: 'You have been inactive. Your session will expire soon.',
      payload: 'inactivity',
      channelId: 'nexus_session',
      channelName: 'Session Notifications',
    );
  }

  // ─── Generic ──────────────────────────────────────────────────

  /// Show a generic notification.
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _show(
      title: title,
      body: body,
      payload: payload,
      channelId: 'nexus_node_channel',
      channelName: 'NexusNode Notifications',
    );
  }

  // ─── Balance Change Detection ─────────────────────────────────

  /// Check for balance changes and trigger appropriate notifications.
  ///
  /// Call this after every balance refresh. It compares the new balance
  /// with the last notified balance and shows a notification if different.
  ///
  /// Returns true if a notification was shown.
  Future<bool> checkBalanceChange({
    required double currentBalance,
    required double lastNotifiedBalance,
  }) async {
    if (currentBalance == lastNotifiedBalance) return false;

    if (currentBalance > lastNotifiedBalance) {
      await showBalanceReceived(
        previousBalance: lastNotifiedBalance,
        newBalance: currentBalance,
      );
      return true;
    }
    // Balance decreased — likely outgoing tx, already notified via showTransactionSent
    return false;
  }

  // ─── Internal ─────────────────────────────────────────────────

  Future<void> _show({
    required String title,
    required String body,
    String? payload,
    required String channelId,
    required String channelName,
  }) async {
    await _localNotifications.show(
      _nextNotificationId++,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: '$channelName for NexusNode Lite',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
