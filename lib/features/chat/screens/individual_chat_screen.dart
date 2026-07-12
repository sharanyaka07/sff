import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/models/message_model.dart';
import '../controllers/chat_controller.dart';

class IndividualChatScreen extends StatefulWidget {
  final String senderId;
  final String senderName;

  const IndividualChatScreen({
    super.key,
    required this.senderId,
    required this.senderName,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(ChatController chat) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final success = await chat.sendMessage(text);
    _scrollToBottom();

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No connection. Connect via Bluetooth first.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  // ── Long-press delete dialog ─────────────────────────────────────
  void _showDeleteOptions(
      BuildContext context, ChatController chat, MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Delete Message',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // Delete for Me
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.surfaceLight,
                child: Icon(Icons.person_off_outlined,
                    color: AppColors.textSecondary),
              ),
              title: const Text(
                'Delete for Me',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                'Remove from your device only',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textHint),
              ),
              onTap: () {
                Navigator.pop(ctx);
                chat.deleteMessageForMe(message.id);
              },
            ),

            // Delete for Everyone (only for messages sent by me)
            if (message.isMe)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22FF4444),
                  child: Icon(Icons.delete_forever_outlined,
                      color: AppColors.danger),
                ),
                title: const Text(
                  'Delete for Everyone',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Remove from all devices & cloud',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textHint),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteForEveryone(context, chat, message);
                },
              ),

            const SizedBox(height: 8),

            // Cancel
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm Delete for Everyone ──────────────────────────────────
  void _confirmDeleteForEveryone(
      BuildContext context, ChatController chat, MessageModel message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete for Everyone?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will remove the message from all devices and the cloud database.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              chat.deleteMessageForEveryone(message.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chat, _) {
        final messages = chat.messagesForSender(widget.senderId);
        _scrollToBottom();

        return Scaffold(
          appBar: AppBar(
            leadingWidth: 40,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    widget.senderName.isNotEmpty
                        ? widget.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.senderName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      chat.isBluetoothConnected
                          ? 'Online via Bluetooth'
                          : 'Offline',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _showClearDialog(context, chat),
                tooltip: 'Clear chat',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final prevMsg =
                              index > 0 ? messages[index - 1] : null;
                          final showDate = prevMsg == null ||
                              !_isSameDay(
                                  prevMsg.timestamp, msg.timestamp);
                          return Column(
                            children: [
                              if (showDate)
                                _DateSeparator(date: msg.timestamp),
                              // Long press to show delete options
                              GestureDetector(
                                onLongPress: () => _showDeleteOptions(
                                    context, chat, msg),
                                child: _MessageBubble(message: msg),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              _buildInputBar(chat),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              widget.senderName.isNotEmpty
                  ? widget.senderName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.senderName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No messages yet.\nSay hello! 👋',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatController chat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Message',
                hintStyle:
                    const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(chat),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: () => _sendMessage(chat),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDialog(
      BuildContext context, ChatController chat) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Chat?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete all messages with ${widget.senderName}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              chat.clearConversation(widget.senderId);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

// ── Date Separator ─────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ── Message Bubble ─────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 4),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEncrypted)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(Icons.lock,
                              size: 10,
                              color: isMe
                                  ? Colors.white54
                                  : AppColors.success),
                        ),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white70
                              : AppColors.textHint,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        _statusIcon(message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time,
            size: 12, color: Colors.white54);
      case MessageStatus.sent:
        return const Icon(Icons.check,
            size: 12, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all,
            size: 12, color: Colors.white);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline,
            size: 12, color: Colors.redAccent);
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}