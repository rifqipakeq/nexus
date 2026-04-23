import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Method
/// 1. refresh berkala untuk deteksi wallet balance
/// 2. bandingkan balance baru dengan balance terakhir yang sudah diberi notifikasi
/// 3. jika balance naik → notifikasi "Received ETH", jika turun → notifikasi
/// 
/// tipe notif
/// - kirim transaksi: tertrigger saat kirim transaksi
/// - terima transaksi: terdeteksi via polling balance, muncul sebagai notifikasi lokal
/// - pengingat inaktivitas: muncul sebelum session timeout
///
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Monotonically increasing notification ID to prevent collisions.
  int _nextNotificationId = 100;

  // init method untuk setup channel dan permission
  Future<void> initialize() async {
    // Android 
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher', // permission android 
    );

    // iOS 
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

  // notif kirim
  Future<void> showTransactionSent({
    required double amount,
    required String toAddress,
    required String txHash,
  }) async {
    final shortAddress = toAddress.length > 10
        ? '${toAddress.substring(0, 6)}...${toAddress.substring(toAddress.length - 4)}'
        : toAddress;

    await _show(
      title: 'ETH Dikirim',
      body: 'Mengirim ${amount.toStringAsFixed(6)} ETH ke alamat $shortAddress',
      payload: 'tx_sent:$txHash',
      channelId: 'nexus_transactions',
      channelName: 'Transaction Notifications',
    );
  }

  /// notif terima
  Future<void> showBalanceReceived({
    required double previousBalance,
    required double newBalance,
  }) async {
    final received = newBalance - previousBalance;
    if (received <= 0) return;

    await _show(
      title: 'ETH Diterima',
      body:
          'Menerima ${received.toStringAsFixed(6)} ETH\nSaldo baru: ${newBalance.toStringAsFixed(6)} ETH',
      payload: 'balance_received',
      channelId: 'nexus_transactions',
      channelName: 'Transaction Notifications',
    );
  }

  // Price alert
  Future<void> showPriceAlert({
    required double oldPrice,
    required double newPrice,
  }) async {
    final percentChange = ((newPrice - oldPrice) / oldPrice * 100)
        .toStringAsFixed(2);
    final direction = newPrice > oldPrice ? '📈 ' : '📉 ';

    await _show(
      title: '$direction ETH Price Alert',
      body:
          'Harga ETH berubah  $percentChange% → \$${newPrice.toStringAsFixed(2)}',
      payload: 'price_alert',
      channelId: 'nexus_price_alerts',
      channelName: 'Price Alerts',
    );
  }

  // notif tidak aktif
  Future<void> showInactivityReminder() async {
    await _show(
      title: 'Pengingat Inaktivitas',
      body: 'Anda tidak aktif. Sesi Anda akan berakhir segera.',
      payload: 'inactivity',
      channelId: 'nexus_session',
      channelName: 'Session Notifications',
    );
  }

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

  //  Balance Change Detection
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
    return false;
  }

  // Internal 
  Future<void> _show({
    required String title,
    required String body,
    String? payload,
    required String channelId,
    required String channelName,
  }) async {
    await _localNotifications.show(
      _nextNotificationId++, // biar ngga bentrok
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
