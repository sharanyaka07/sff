import 'package:flutter/foundation.dart';
import '../../../data/local/models/message_model.dart';
import '../../bluetooth/controllers/bluetooth_controller.dart';
import '../../../core/utils/logger.dart';

class ChatController extends ChangeNotifier {
  final BluetoothController _bt;

  ChatController({required BluetoothController bluetoothController})
      : _bt = bluetoothController {
    _bt.addListener(_onChanged);
  }

  // ── All messages (from Bluetooth only) ───────────────────────────
  List<MessageModel> get allMessages => _bt.messages;

  // ── Connection state ─────────────────────────────────────────────
  bool get isConnected => _bt.isConnected;

  // Keep these for UI compatibility
  bool get isOnline => false;
  bool get isBluetoothConnected => _bt.isConnected;

  // ── Who we're chatting with ──────────────────────────────────────
  List<String> get recentSenders => _bt.messages
      .where((m) => !m.isMe)
      .map((m) => m.senderName)
      .toSet()
      .toList();

  String get connectedDeviceName {
    if (_bt.connectedDevices.isEmpty) return '';
    final d = _bt.connectedDevices.first;
    return d.platformName.isNotEmpty ? d.platformName : d.remoteId.str;
  }

  // ── Mode labels for UI banner ────────────────────────────────────
  String get modeLabel {
    if (isConnected) return '🔵 Bluetooth Chat';
    return '⚠️ Not Connected';
  }

  String get modeSubLabel {
    if (isConnected) {
      final name = connectedDeviceName;
      if (name.isNotEmpty) return 'Connected to $name';
      return 'Connected via Bluetooth';
    }
    return 'Go to Bluetooth tab → tap a device to connect';
  }

  // ── Send message ─────────────────────────────────────────────────
  Future<bool> sendMessage(String content) async {
    if (content.trim().isEmpty) return false;

    if (!isConnected) {
      AppLogger.warning('Cannot send — no Bluetooth connection');
      return false;
    }

    return _bt.sendMessage(content);
  }

  void _onChanged() => notifyListeners();

  void clearAll() {
    _bt.clearMessages();
    notifyListeners();
  }

  @override
  void dispose() {
    _bt.removeListener(_onChanged);
    super.dispose();
  }
}