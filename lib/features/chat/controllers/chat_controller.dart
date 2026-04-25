 import 'package:flutter/foundation.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../data/local/models/message_model.dart';
import '../../../data/remote/firebase/fcm_service.dart';
import '../../bluetooth/controllers/bluetooth_controller.dart';
import '../../../core/utils/logger.dart';

enum ChatMode { bluetooth, online, hybrid }

class ChatController extends ChangeNotifier {
  final ConnectivityService _connectivityService;
  final BluetoothController _bluetoothController;
  final FcmService _fcmService;

  ChatController({
    required ConnectivityService connectivityService,
    required BluetoothController bluetoothController,
    required FcmService fcmService,
  })  : _connectivityService = connectivityService,
        _bluetoothController = bluetoothController,
        _fcmService = fcmService {
    // Listen to connectivity changes
    _connectivityService.statusStream.listen(_onConnectivityChanged);

    // Listen to bluetooth & fcm message changes
    _bluetoothController.addListener(_onMessagesChanged);
    _fcmService.addListener(_onMessagesChanged);
  }

  // ── State ────────────────────────────────────────────────────────
  ChatMode _mode = ChatMode.bluetooth;
  ChatMode get mode => _mode;

  bool get isOnline => _connectivityService.isOnline;
  bool get isBluetoothConnected =>
      _bluetoothController.connectedDevices.isNotEmpty;

  // ── All messages combined from both sources ───────────────────────
  List<MessageModel> get allMessages {
    final bluetoothMsgs = _bluetoothController.messages;
    final onlineMsgs = _fcmService.onlineMessages;

    // Combine and sort by timestamp
    final combined = [...bluetoothMsgs, ...onlineMsgs];
    combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return combined;
  }

  String get modeLabel {
    if (isOnline && isBluetoothConnected) return '🔀 Hybrid Mode';
    if (isOnline) return '🌐 Online Mode';
    if (isBluetoothConnected) return '🔵 Bluetooth Mode';
    return '⚠️ No Connection';
  }

  String get modeSubLabel {
    if (isOnline && isBluetoothConnected) {
      return 'Using both Bluetooth and Internet';
    }
    if (isOnline) return 'Messages sent via Firebase';
    if (isBluetoothConnected) return 'Messages sent via Bluetooth';
    return 'Connect to Bluetooth or Internet';
  }

  // ── Send Message — Auto Route ────────────────────────────────────
  Future<bool> sendMessage(String content) async {
    if (content.trim().isEmpty) return false;

    bool sent = false;

    AppLogger.info('Sending message. Online: $isOnline, BT: $isBluetoothConnected');

    // Send via Bluetooth if connected
    if (isBluetoothConnected) {
      final btResult = await _bluetoothController.sendMessage(content);
      if (btResult) {
        sent = true;
        AppLogger.bluetooth('Message sent via Bluetooth ✅');
      }
    }

    // Send via Firebase if online
    if (isOnline) {
      final fcmResult = await _fcmService.sendMessageToToken(
        targetToken: 'broadcast',
        content: content,
        senderId: _bluetoothController.deviceId,
        senderName: _bluetoothController.deviceName,
      );
      if (fcmResult) {
        sent = true;
        AppLogger.success('Message sent via Firebase ✅');
      }
    }

    if (!sent) {
      AppLogger.warning('Message could not be sent — no connection');
    }

    return sent;
  }

  // ── Listeners ────────────────────────────────────────────────────
  void _onConnectivityChanged(ConnectionStatus status) {
    _updateMode();
    notifyListeners();
    AppLogger.info('Connectivity changed: $status → Mode: $_mode');
  }

  void _onMessagesChanged() {
    notifyListeners();
  }

  void _updateMode() {
    if (isOnline && isBluetoothConnected) {
      _mode = ChatMode.hybrid;
    } else if (isOnline) {
      _mode = ChatMode.online;
    } else {
      _mode = ChatMode.bluetooth;
    }
  }

  void clearAll() {
    _bluetoothController.clearMessages();
    _fcmService.clearMessages();
    notifyListeners();
  }

  @override
  void dispose() {
    _bluetoothController.removeListener(_onMessagesChanged);
    _fcmService.removeListener(_onMessagesChanged);
    super.dispose();
  }
}