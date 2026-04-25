import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/logger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ── Initialize ───────────────────────────────────────────────────
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        AppLogger.info(
          'Notification tapped: ${response.payload}',
          tag: 'NOTIF',
        );
      },
    );

    await _createChannels();

    _initialized = true;
    AppLogger.success('NotificationService initialized ✅', tag: 'NOTIF');
  }

  // ── Create Android Notification Channels ─────────────────────────
  static Future<void> _createChannels() async {
    const sosChannel = AndroidNotificationChannel(
      'sos_channel',
      'SOS Alerts',
      description: 'Critical SOS emergency alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const messageChannel = AndroidNotificationChannel(
      'message_channel',
      'Messages',
      description: 'Incoming chat messages',
      importance: Importance.high,
      playSound: true,
    );

    const bluetoothChannel = AndroidNotificationChannel(
      'bluetooth_channel',
      'Bluetooth',
      description: 'Bluetooth device alerts',
      importance: Importance.defaultImportance,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(sosChannel);
      await androidPlugin.createNotificationChannel(messageChannel);
      await androidPlugin.createNotificationChannel(bluetoothChannel);
    }

    AppLogger.success('Notification channels created ✅', tag: 'NOTIF');
  }

  // ── Show SOS Alert Notification ──────────────────────────────────
  static Future<void> showSosAlert({
    required String senderName,
    required String location,
  }) async {
    if (!_initialized) await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sos_channel',
        'SOS Alerts',
        channelDescription: 'Critical SOS emergency alerts',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFD32F2F),
        playSound: true,
        enableVibration: true,
        ticker: 'SOS ALERT',
        styleInformation: BigTextStyleInformation(''),
      ),
    );

    await _plugin.show(
      1001,
      '🆘 SOS ALERT!',
      '$senderName needs help! Location: $location',
      details,
      payload: 'sos',
    );

    AppLogger.sos('SOS notification shown ✅');
  }

  // ── Show Message Notification ────────────────────────────────────
  static Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String channel,
  }) async {
    if (!_initialized) await initialize();

    final channelIcon = channel == 'bluetooth' ? '📡' : '🌐';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'message_channel',
        'Messages',
        channelDescription: 'Incoming chat messages',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '$channelIcon Message from $senderName',
      message,
      details,
      payload: 'message',
    );

    AppLogger.info('Message notification shown ✅', tag: 'NOTIF');
  }

  // ── Show Bluetooth Device Found Notification ─────────────────────
  static Future<void> showBluetoothDeviceFound({
    required String deviceName,
    required int deviceCount,
  }) async {
    if (!_initialized) await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'bluetooth_channel',
        'Bluetooth',
        channelDescription: 'Bluetooth device alerts',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        onlyAlertOnce: true,
      ),
    );

    await _plugin.show(
      2001,
      '📡 Safe Connect Device Nearby',
      '$deviceName found — $deviceCount device(s) in range',
      details,
      payload: 'bluetooth',
    );
  }

  // ── Show General Notification ────────────────────────────────────
  static Future<void> showGeneral({
    required String title,
    required String body,
    int id = 9999,
  }) async {
    if (!_initialized) await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'message_channel',
        'Messages',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(id, title, body, details);
  }

  // ── Cancel all notifications ─────────────────────────────────────
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}