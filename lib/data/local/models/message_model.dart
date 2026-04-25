import 'dart:convert';

enum MessageType { text, sos, relay }
enum MessageStatus { sending, sent, delivered, failed }

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String content;        // Always DECRYPTED for display
  final String? encryptedContent; // The encrypted version
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isMe;
  final int hopCount;
  final bool isEncrypted;

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
  });

  // ── Convert to JSON for sending over BLE ─────────────────────────
  // NOTE: We send the ENCRYPTED content over the wire
  String toJson({String? encryptedPayload}) {
    return jsonEncode({
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      // Send encrypted content if available, otherwise plain
      'content': encryptedPayload ?? content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'hopCount': hopCount,
      'isEncrypted': encryptedPayload != null,
    });
  }

  // ── Parse JSON received over BLE ─────────────────────────────────
  factory MessageModel.fromJson(String jsonStr, {
    bool isMe = false,
    String? decryptedContent,
  }) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final rawContent = map['content'] as String;
    final wasEncrypted = map['isEncrypted'] as bool? ?? false;

    return MessageModel(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      // Use decrypted content if provided, otherwise raw
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
    );
  }

  MessageModel copyWith({MessageStatus? status}) {
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
    );
  }
}