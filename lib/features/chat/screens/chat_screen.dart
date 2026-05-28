import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/chat_controller.dart';
import '../../bluetooth/screens/bluetooth_screen.dart';
import 'individual_chat_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chat, _) {
        final conversations = chat.conversations;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chats',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text('End-to-end encrypted',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
              ],
            ),
            actions: [
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.bluetooth_searching,
                        color: AppColors.primary),
                    if (chat.isBluetoothConnected)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BluetoothScreen()),
                ),
                tooltip: 'Bluetooth',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildConnectionBanner(chat),
              Expanded(
                child: conversations.isEmpty
                    ? _buildEmptyState(context, chat)
                    : ListView.separated(
                        itemCount: conversations.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 72,
                            color: AppColors.border),
                        itemBuilder: (context, index) {
                          final convo = conversations[index];
                          return _ConversationTile(
                            conversation: convo,
                            onTap: () {
                              chat.markAsRead(convo.senderId);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => IndividualChatScreen(
                                    senderId: convo.senderId,
                                    senderName: convo.senderName,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionBanner(ChatController chat) {
    Color color;
    String text;

    if (chat.isBluetoothConnected) {
      color = AppColors.bluetoothActive;
      text =
          '🔵 Bluetooth Connected  •  Connected to ${chat.connectedDeviceName}';
    } else {
      color = AppColors.warning;
      text = '⚠️ Not Connected  •  Go to Bluetooth tab to connect';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: color.withValues(alpha: 0.12),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ChatController chat) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 56, color: AppColors.textHint),
            ),
            const SizedBox(height: 20),
            const Text(
              'No conversations yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect to a nearby device\nand start chatting!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textHint),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BluetoothScreen()),
              ),
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Find Nearby Devices'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conversation Tile ──────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final isConnected = conversation.isConnectedNow;

    return ListTile(
      onTap: onTap,
      tileColor: AppColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              conversation.senderName.isNotEmpty
                  ? conversation.senderName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          if (isConnected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.senderName,
              style: TextStyle(
                fontWeight:
                    hasUnread ? FontWeight.bold : FontWeight.w600,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            _formatTime(conversation.lastMessageTime),
            style: TextStyle(
              fontSize: 11,
              color: hasUnread
                  ? AppColors.primary
                  : AppColors.textHint,
              fontWeight:
                  hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          if (conversation.lastMessageIsMe)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.done_all,
                  size: 14, color: AppColors.textHint),
            ),
          Expanded(
            child: Text(
              conversation.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: conversation.lastMessage ==
                        'Tap to start chatting 💬'
                    ? AppColors.primary
                    : hasUnread
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                fontStyle: conversation.lastMessage ==
                        'Tap to start chatting 💬'
                    ? FontStyle.italic
                    : FontStyle.normal,
                fontWeight:
                    hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(
                  color: AppColors.background,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    } else {
      return '${time.day}/${time.month}/${time.year % 100}';
    }
  }
}