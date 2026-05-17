import 'dart:convert';

enum MessageType { text, sos, relay }
enum MessageStatus { sending, sent, delivered, failed }

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final String? encryptedContent;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isMe;
  final int hopCount;
  final bool isEncrypted;

  // ── conversationId: links a sent message to the peer it was sent to
  // For received messages: equals senderId
  // For sent messages: equals the peer's senderId at time of sending
  final String conversationId;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.encryptedContent,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.isMe,
    this.hopCount = 0,
    this.isEncrypted = false,
    this.conversationId = '',
  });

  String toJson({String? encryptedPayload}) {
    return jsonEncode({
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'content': encryptedPayload ?? content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'hopCount': hopCount,
      'isEncrypted': encryptedPayload != null,
    });
  }

  factory MessageModel.fromJson(String jsonStr, {
    bool isMe = false,
    String? decryptedContent,
    String conversationId = '',
  }) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final rawContent = map['content'] as String;
    final wasEncrypted = map['isEncrypted'] as bool? ?? false;
    final senderId = map['senderId'] as String;

    return MessageModel(
      id: map['id'] as String,
      senderId: senderId,
      senderName: map['senderName'] as String,
      content: decryptedContent ?? rawContent,
      encryptedContent: wasEncrypted ? rawContent : null,
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.delivered,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isMe: isMe,
      hopCount: map['hopCount'] as int? ?? 0,
      isEncrypted: wasEncrypted,
      // For received messages, conversationId = senderId
      conversationId: conversationId.isNotEmpty ? conversationId : senderId,
    );
  }

  MessageModel copyWith({MessageStatus? status, String? conversationId}) {
    return MessageModel(
      id: id,
      senderId: senderId,
      senderName: senderName,
      content: content,
      encryptedContent: encryptedContent,
      type: type,
      status: status ?? this.status,
      timestamp: timestamp,
      isMe: isMe,
      hopCount: hopCount,
      isEncrypted: isEncrypted,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}