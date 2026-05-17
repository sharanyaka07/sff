import 'package:flutter/foundation.dart';
import '../../../data/local/models/message_model.dart';
import '../../bluetooth/controllers/bluetooth_controller.dart';
import '../../../core/utils/logger.dart';

class Conversation {
  final String senderId;
  final String senderName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool lastMessageIsMe;
  final int unreadCount;
  final bool isConnectedNow;

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

  final Map<String, int> _unreadCounts = {};
  int _prevMessageCount = 0;

  ChatController({required BluetoothController bluetoothController})
      : _bt = bluetoothController {
    _bt.addListener(_onChanged);
  }

  List<MessageModel> get allMessages => _bt.messages;

  // ── Messages for a specific conversation ─────────────────────────
  // peerId is the peer's UUID (from handshake senderId).
  //
  // Sent messages match if:
  //   - conversationId == peerId  (UUID stamped after handshake) ✅
  //   - OR conversationId is a MAC that maps to this peerId via received msgs
  //     (race: message sent before handshake arrived, MAC was used as convId)
  //
  // Received messages match if senderId == peerId.
  List<MessageModel> messagesForSender(String peerId) {
    // Build a set of all known conversationIds for this peer:
    // their UUID + any MACs found on their received messages
    final peerConvIds = <String>{peerId};

    // Any MAC address that appeared as senderMac when we got their messages
    // is also a valid convId for sent messages to them
    // (We detect this by looking for received msgs whose senderId == peerId
    //  and checking if we have sent msgs with a MAC convId that's not in
    //  any other received sender's set — simpler: just accept MAC-format
    //  convIds that don't belong to any OTHER known peer)
    final otherPeerIds = _bt.messages
        .where((m) => !m.isMe && m.senderId != peerId)
        .map((m) => m.senderId)
        .toSet();

    return _bt.messages.where((m) {
      if (m.isMe) {
        // Sent message: show if convId matches this peer
        if (peerConvIds.contains(m.conversationId)) return true;
        // Also show if convId is a MAC-format that isn't claimed by another peer
        if (m.conversationId.isNotEmpty &&
            !otherPeerIds.contains(m.conversationId)) {
          // It's either our peer's MAC or an unknown — include it
          // (safe because we already exclude msgs with known other-peer IDs)
          return true;
        }
        return false;
      } else {
        // Received message: show if it came from this peer
        return m.senderId == peerId;
      }
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // ── Build conversation list ───────────────────────────────────────
  List<Conversation> get conversations {
    final Map<String, Conversation> convMap = {};

    // Step 1: Add currently connected peer
    final connectedId   = _connectedPeerId;
    final connectedName = _connectedPeerName;

    if (connectedId.isNotEmpty) {
      final msgs = messagesForSender(connectedId);

      String lastMsg   = 'Tap to start chatting 💬';
      DateTime lastTime = DateTime.now();
      bool lastIsMe    = false;

      if (msgs.isNotEmpty) {
        final last = msgs.last;
        lastMsg  = last.content;
        lastTime = last.timestamp;
        lastIsMe = last.isMe;
      }

      convMap[connectedId] = Conversation(
        senderId:        connectedId,
        senderName:      connectedName,
        lastMessage:     lastMsg,
        lastMessageTime: lastTime,
        lastMessageIsMe: lastIsMe,
        unreadCount:     _unreadCounts[connectedId] ?? 0,
        isConnectedNow:  true,
      );
    }

    // Step 2: Add past conversations from received message history
    final senderIds = _bt.messages
        .where((m) => !m.isMe)
        .map((m) => m.senderId)
        .toSet();

    for (final peerId in senderIds) {
      if (convMap.containsKey(peerId)) continue;

      final msgs = messagesForSender(peerId);
      if (msgs.isEmpty) continue;

      final lastMsg    = msgs.last;
      final senderName = _bt.messages
          .firstWhere((m) => m.senderId == peerId)
          .senderName;

      convMap[peerId] = Conversation(
        senderId:        peerId,
        senderName:      senderName,
        lastMessage:     lastMsg.content,
        lastMessageTime: lastMsg.timestamp,
        lastMessageIsMe: lastMsg.isMe,
        unreadCount:     _unreadCounts[peerId] ?? 0,
        isConnectedNow:  false,
      );
    }

    // Sort: connected first, then most recent
    return convMap.values.toList()
      ..sort((a, b) {
        if (a.isConnectedNow && !b.isConnectedNow) return -1;
        if (!a.isConnectedNow && b.isConnectedNow) return 1;
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });
  }

  // ── Connected peer ID — from handshake (UUID), not MAC ───────────
  String get _connectedPeerId {
    if (!_bt.isConnected) return '';

    // Priority 1: peer UUID stored during handshake (most reliable)
    if (_bt.connectedPeerId.isNotEmpty) return _bt.connectedPeerId;

    // Priority 2: senderId from last received message
    final received = _bt.messages.where((m) => !m.isMe).toList();
    if (received.isNotEmpty) return received.last.senderId;

    // Priority 3: outgoing device MAC
    if (_bt.connectedDevices.isNotEmpty) {
      return _bt.connectedDevices.first.remoteId.str;
    }

    // Priority 4: server client pseudo-ID
    if (_bt.serverHasClients && _bt.connectedClientName.isNotEmpty) {
      return 'server_client_${_bt.connectedClientName}';
    }

    return '';
  }

  // ── Connected peer name ───────────────────────────────────────────
  String get _connectedPeerName {
    // Priority 1: name from received messages (always the real peer name)
    final received = _bt.messages.where((m) => !m.isMe).toList();
    if (received.isNotEmpty) return received.last.senderName;

    // Priority 2: name from handshake (guaranteed not our own name)
    if (_bt.connectedClientName.isNotEmpty &&
        !_bt.connectedClientName.contains(':')) {
      return _bt.connectedClientName;
    }

    // Priority 3: platform name
    if (_bt.connectedDevices.isNotEmpty) {
      final d = _bt.connectedDevices.first;
      if (d.platformName.isNotEmpty) return d.platformName;
    }

    if (_bt.connectedClientName.isNotEmpty) return _bt.connectedClientName;
    return 'Connected Device';
  }

  void markAsRead(String senderId) {
    _unreadCounts[senderId] = 0;
    notifyListeners();
  }

  void clearConversation(String senderId) {
    _bt.clearMessagesForSender(senderId);
    _unreadCounts.remove(senderId);
    notifyListeners();
  }

  bool get isConnected          => _bt.isConnected;
  bool get isOnline             => false;
  bool get isBluetoothConnected => _bt.isConnected;

  List<String> get recentSenders => _bt.messages
      .where((m) => !m.isMe)
      .map((m) => m.senderName)
      .toSet()
      .toList();

  String get connectedDeviceName => _connectedPeerName;

  String get modeLabel => isConnected
      ? '🔵 Bluetooth Connected'
      : '⚠️ Not Connected';

  String get modeSubLabel => isConnected
      ? 'Connected to $connectedDeviceName'
      : 'Go to Bluetooth tab → tap a device to connect';

  Future<bool> sendMessage(String content) async {
    if (content.trim().isEmpty) return false;
    if (!isConnected) {
      AppLogger.warning('Cannot send — no Bluetooth connection');
      return false;
    }
    return _bt.sendMessage(content);
  }

  void _onChanged() {
    final currentCount = _bt.messages.length;
    if (currentCount > _prevMessageCount) {
      final newMsgs = _bt.messages.skip(_prevMessageCount).toList();
      for (final msg in newMsgs) {
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