import 'package:flutter/foundation.dart';
import '../../../data/local/models/message_model.dart';
import '../../bluetooth/controllers/bluetooth_controller.dart';
import '../../../core/utils/logger.dart';
import '../../../data/remote/firebase/firestore_service.dart';

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

  // Locally deleted message IDs (Delete for Me)
  final Set<String> _deletedForMe = {};

  ChatController({required BluetoothController bluetoothController})
      : _bt = bluetoothController {
    _bt.addListener(_onChanged);
  }

  List<MessageModel> get allMessages => _bt.messages
      .where((m) => !_deletedForMe.contains(m.id))
      .toList();

  // Messages for a specific conversation
  List<MessageModel> messagesForSender(String peerId) {
    final peerConvIds = <String>{peerId};

    final otherPeerIds = _bt.messages
        .where((m) => !m.isMe && m.senderId != peerId)
        .map((m) => m.senderId)
        .toSet();

    return _bt.messages.where((m) {
      if (_deletedForMe.contains(m.id)) return false;

      if (m.isMe) {
        if (peerConvIds.contains(m.conversationId)) return true;
        if (m.conversationId.isNotEmpty &&
            !otherPeerIds.contains(m.conversationId)) {
          return true;
        }
        return false;
      } else {
        return m.senderId == peerId;
      }
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Delete for Me (local only — hides from this device only)
  void deleteMessageForMe(String messageId) {
    _deletedForMe.add(messageId);
    notifyListeners();
    AppLogger.info('Message deleted for me: $messageId', tag: 'Chat');
  }

  // Delete for Everyone (local + removes from Firestore)
  Future<void> deleteMessageForEveryone(String messageId) async {
    _deletedForMe.add(messageId);
    notifyListeners();

    FirestoreService.deleteMessage(messageId).catchError((e) {
      AppLogger.error('Firestore delete failed', tag: 'Chat', error: e);
    });

    AppLogger.info('Message deleted for everyone: $messageId', tag: 'Chat');
  }

  // Build conversation list
  List<Conversation> get conversations {
    final Map<String, Conversation> convMap = {};

    final connectedId   = _connectedPeerId;
    final connectedName = _connectedPeerName;

    if (connectedId.isNotEmpty) {
      final msgs = messagesForSender(connectedId);

      String lastMsg    = 'Tap to start chatting 💬';
      DateTime lastTime = DateTime.now();
      bool lastIsMe     = false;

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

    return convMap.values.toList()
      ..sort((a, b) {
        if (a.isConnectedNow && !b.isConnectedNow) return -1;
        if (!a.isConnectedNow && b.isConnectedNow) return 1;
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });
  }

  String get _connectedPeerId {
    if (!_bt.isConnected) return '';
    if (_bt.connectedPeerId.isNotEmpty) return _bt.connectedPeerId;

    final received = _bt.messages.where((m) => !m.isMe).toList();
    if (received.isNotEmpty) return received.last.senderId;

    if (_bt.connectedDevices.isNotEmpty) {
      return _bt.connectedDevices.first.remoteId.str;
    }

    if (_bt.serverHasClients && _bt.connectedClientName.isNotEmpty) {
      return 'server_client_${_bt.connectedClientName}';
    }

    return '';
  }

  String get _connectedPeerName {
    final received = _bt.messages.where((m) => !m.isMe).toList();
    if (received.isNotEmpty) return received.last.senderName;

    if (_bt.connectedClientName.isNotEmpty &&
        !_bt.connectedClientName.contains(':')) {
      return _bt.connectedClientName;
    }

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

    final success = await _bt.sendMessage(content);

    if (success) {
      final msgs = _bt.messages;
      if (msgs.isNotEmpty) {
        final sent = msgs.last;
        FirestoreService.saveMessage(sent, channel: 'bluetooth').catchError((e) {
          AppLogger.error('Firestore message save failed', tag: 'Chat', error: e);
        });
      }
    }

    return success;
  }

  void _onChanged() {
    final currentCount = _bt.messages.length;

    if (currentCount > _prevMessageCount) {
      final newMsgs = _bt.messages.skip(_prevMessageCount).toList();
      for (final msg in newMsgs) {
        if (!msg.isMe) {
          _unreadCounts[msg.senderId] =
              (_unreadCounts[msg.senderId] ?? 0) + 1;

          FirestoreService.saveMessage(msg, channel: 'bluetooth').catchError((e) {
            AppLogger.error(
              'Firestore received msg save failed',
              tag: 'Chat',
              error: e,
            );
          });
        }
      }
    }

    _prevMessageCount = currentCount;
    notifyListeners();
  }

  void clearAll() {
    _bt.clearMessages();
    _unreadCounts.clear();
    _deletedForMe.clear();
    _prevMessageCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _bt.removeListener(_onChanged);
    super.dispose();
  }
}