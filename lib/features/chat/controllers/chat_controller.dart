import 'package:flutter/foundation.dart';
import '../../../data/local/models/message_model.dart';
import '../../bluetooth/controllers/bluetooth_controller.dart';
import '../../../core/utils/logger.dart';

// ── Conversation model — one entry per unique sender ────────────────
class Conversation {
  final String senderId;
  final String senderName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool lastMessageIsMe;
  final int unreadCount;
  final bool isConnectedNow; // ← is this person currently connected?

  const Conversation({
    required this.senderId,
    required this.senderName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageIsMe,
    this.unreadCount = 0,
    this.isConnectedNow = false,
  });
}

class ChatController extends ChangeNotifier {
  final BluetoothController _bt;

  // ── Track unread counts per senderId ────────────────────────────
  final Map<String, int> _unreadCounts = {};

  // ── Track previous message count to detect new arrivals ─────────
  int _prevMessageCount = 0;

  ChatController({required BluetoothController bluetoothController})
      : _bt = bluetoothController {
    _bt.addListener(_onChanged);
  }

  // ── All messages ─────────────────────────────────────────────────
  List<MessageModel> get allMessages => _bt.messages;

  // ── Messages for a specific sender (both sent and received) ──────
  List<MessageModel> messagesForSender(String senderId) {
    return _bt.messages
        .where((m) => m.isMe || m.senderId == senderId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // ── Build conversation list ───────────────────────────────────────
  // Shows:
  // 1. Currently connected device (even with no messages yet)
  // 2. Past conversations from message history
  List<Conversation> get conversations {
    final Map<String, Conversation> convMap = {};

    // ── Step 1: Add currently connected device first ──────────────
    // This ensures the chat option always shows when connected,
    // even before any message has been sent or received.
    final connectedId = _connectedPeerId;
    final connectedName = _connectedPeerName;

    if (connectedId.isNotEmpty) {
      // Find last message with this peer if any
      final peerMessages = _bt.messages
          .where((m) => !m.isMe && m.senderId == connectedId)
          .toList();

      final myMessages = _bt.messages.where((m) => m.isMe).toList();
      final allPeerConvo = [...peerMessages, ...myMessages]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      String lastMsg = 'Tap to start chatting 💬';
      DateTime lastTime = DateTime.now();
      bool lastIsMe = false;

      if (allPeerConvo.isNotEmpty) {
        final last = allPeerConvo.last;
        lastMsg = last.isMe ? last.content : last.content;
        lastTime = last.timestamp;
        lastIsMe = last.isMe;
      }

      convMap[connectedId] = Conversation(
        senderId: connectedId,
        senderName: connectedName,
        lastMessage: lastMsg,
        lastMessageTime: lastTime,
        lastMessageIsMe: lastIsMe,
        unreadCount: _unreadCounts[connectedId] ?? 0,
        isConnectedNow: true,
      );
    }

    // ── Step 2: Add past conversations from message history ────────
    final senders = _bt.messages
        .where((m) => !m.isMe)
        .map((m) => m.senderId)
        .toSet();

    for (final senderId in senders) {
      if (convMap.containsKey(senderId)) continue; // already added

      final convoMessages = messagesForSender(senderId);
      if (convoMessages.isEmpty) continue;

      final lastMsg = convoMessages.last;
      final senderName = _bt.messages
          .firstWhere((m) => m.senderId == senderId)
          .senderName;

      convMap[senderId] = Conversation(
        senderId: senderId,
        senderName: senderName,
        lastMessage: lastMsg.isMe
            ? lastMsg.content
            : lastMsg.content,
        lastMessageTime: lastMsg.timestamp,
        lastMessageIsMe: lastMsg.isMe,
        unreadCount: _unreadCounts[senderId] ?? 0,
        isConnectedNow: false,
      );
    }

    // Sort: connected first, then by most recent message
    final result = convMap.values.toList()
      ..sort((a, b) {
        if (a.isConnectedNow && !b.isConnectedNow) return -1;
        if (!a.isConnectedNow && b.isConnectedNow) return 1;
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });

    return result;
  }

  // ── Get connected peer's ID ───────────────────────────────────────
  // Uses senderId from last received message, or device remoteId
  String get _connectedPeerId {
    if (!_bt.isConnected) return '';

    // Check if we have a recent message from someone
    final received = _bt.messages.where((m) => !m.isMe).toList();
    if (received.isNotEmpty) {
      return received.last.senderId;
    }

    // Fall back to connected device MAC as ID
    if (_bt.connectedDevices.isNotEmpty) {
      return _bt.connectedDevices.first.remoteId.str;
    }

    // Server-side: use connectedClientName as pseudo-ID
    if (_bt.serverHasClients && _bt.connectedClientName.isNotEmpty) {
      return 'server_client_${_bt.connectedClientName}';
    }

    return '';
  }

  // ── Get connected peer's display name ────────────────────────────
  String get _connectedPeerName {
    // 1. Handshake name (most reliable)
    if (_bt.connectedClientName.isNotEmpty &&
        !_bt.connectedClientName.contains(':')) {
      return _bt.connectedClientName;
    }

    // 2. Name from received messages
    final received = _bt.messages.where((m) => !m.isMe).toList();
    if (received.isNotEmpty) {
      return received.last.senderName;
    }

    // 3. Platform name from connected devices
    if (_bt.connectedDevices.isNotEmpty) {
      final d = _bt.connectedDevices.first;
      if (d.platformName.isNotEmpty) return d.platformName;
    }

    // 4. connectedClientName even if it's MAC
    if (_bt.connectedClientName.isNotEmpty) {
      return _bt.connectedClientName;
    }

    return 'Connected Device';
  }

  // ── Mark conversation as read ────────────────────────────────────
  void markAsRead(String senderId) {
    _unreadCounts[senderId] = 0;
    notifyListeners();
  }

  // ── Clear a single conversation ──────────────────────────────────
  void clearConversation(String senderId) {
    _bt.clearMessagesForSender(senderId);
    _unreadCounts.remove(senderId);
    notifyListeners();
  }

  // ── Connection state ─────────────────────────────────────────────
  bool get isConnected => _bt.isConnected;
  bool get isOnline => false;
  bool get isBluetoothConnected => _bt.isConnected;

  List<String> get recentSenders => _bt.messages
      .where((m) => !m.isMe)
      .map((m) => m.senderName)
      .toSet()
      .toList();

  String get connectedDeviceName => _connectedPeerName;

  String get modeLabel {
    if (isConnected) return '🔵 Bluetooth Connected';
    return '⚠️ Not Connected';
  }

  String get modeSubLabel {
    if (isConnected) return 'Connected to $connectedDeviceName';
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

  // ── Listener: track unread counts ───────────────────────────────
  void _onChanged() {
    final currentCount = _bt.messages.length;

    if (currentCount > _prevMessageCount) {
      // New messages arrived — increment unread for received ones
      final newMessages =
          _bt.messages.skip(_prevMessageCount).toList();
      for (final msg in newMessages) {
        if (!msg.isMe) {
          _unreadCounts[msg.senderId] =
              (_unreadCounts[msg.senderId] ?? 0) + 1;
        }
      }
    }

    _prevMessageCount = currentCount;
    notifyListeners();
  }

  void clearAll() {
    _bt.clearMessages();
    _unreadCounts.clear();
    _prevMessageCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _bt.removeListener(_onChanged);
    super.dispose();
  }
}