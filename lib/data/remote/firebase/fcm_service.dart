import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/local/models/message_model.dart';
import 'package:uuid/uuid.dart';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.info('Background message: ${message.messageId}', tag: 'FCM');
}

class FcmService extends ChangeNotifier {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  final List<MessageModel> _onlineMessages = [];
  List<MessageModel> get onlineMessages =>
      List.unmodifiable(_onlineMessages);

  bool _initialized = false;
  bool get initialized => _initialized;

  // ── Initialize ───────────────────────────────────────────────────
  Future<void> initialize({
    required String deviceId,
    required String deviceName,
  }) async {
    if (_initialized) return;

    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      AppLogger.info(
        'FCM Permission: ${settings.authorizationStatus}',
        tag: 'FCM',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.warning('FCM permissions denied', tag: 'FCM');
        return;
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      AppLogger.success('FCM Token: $_fcmToken', tag: 'FCM');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        AppLogger.info('FCM Token refreshed', tag: 'FCM');
        notifyListeners();
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.info(
          'Foreground message: ${message.messageId}',
          tag: 'FCM',
        );
        _handleIncomingMessage(message, deviceId);
      });

      // Handle background message tap (app was in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.info(
          'Message opened app: ${message.messageId}',
          tag: 'FCM',
        );
        _handleIncomingMessage(message, deviceId);
      });

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Check for initial message (app opened from terminated state)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleIncomingMessage(initialMessage, deviceId);
      }

      _initialized = true;
      notifyListeners();
      AppLogger.success('FCM initialized ✅', tag: 'FCM');
    } catch (e) {
      AppLogger.error('FCM init failed', tag: 'FCM', error: e);
    }
  }

  // ── Handle Incoming Message ──────────────────────────────────────
  void _handleIncomingMessage(RemoteMessage message, String myDeviceId) {
    try {
      final data = message.data;

      final chatMessage = MessageModel(
        id: data['messageId'] ?? const Uuid().v4(),
        senderId: data['senderId'] ?? 'unknown',
        senderName: data['senderName'] ?? 'Unknown User',
        content: data['content'] ?? message.notification?.body ?? '',
        type: MessageType.text,
        status: MessageStatus.delivered,
        timestamp: DateTime.now(),
        isMe: data['senderId'] == myDeviceId,
      );

      // Don't show notification for own messages
      if (!chatMessage.isMe) {
        // ── Show notification based on message type ───────────────
        if (chatMessage.content.contains('🆘') ||
            chatMessage.content.toUpperCase().contains('SOS')) {
          NotificationService.showSosAlert(
            senderName: chatMessage.senderName,
            location: chatMessage.content,
          );
        } else {
          NotificationService.showMessageNotification(
            senderName: chatMessage.senderName,
            message: chatMessage.content,
            channel: 'online',
          );
        }
      }

      _onlineMessages.add(chatMessage);
      notifyListeners();

      AppLogger.success(
        'Message received from ${chatMessage.senderName}',
        tag: 'FCM',
      );
    } catch (e) {
      AppLogger.error('Failed to parse FCM message', tag: 'FCM', error: e);
    }
  }

  // ── Send Message via FCM ─────────────────────────────────────────
  Future<bool> sendMessageToToken({
    required String targetToken,
    required String content,
    required String senderId,
    required String senderName,
  }) async {
    AppLogger.info('Sending FCM message to token...', tag: 'FCM');

    final message = MessageModel(
      id: const Uuid().v4(),
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: MessageType.text,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
      isMe: true,
    );

    _onlineMessages.add(message);
    notifyListeners();
    return true;
  }

  void clearMessages() {
    _onlineMessages.clear();
    notifyListeners();
  }
}