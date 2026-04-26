import 'package:flutter/material.dart';
import '../data/firstaid_responses.dart';
import '../../../core/theme/app_theme.dart';

class FirstAidChatbotScreen extends StatefulWidget {
  const FirstAidChatbotScreen({super.key});

  @override
  State<FirstAidChatbotScreen> createState() =>
      _FirstAidChatbotScreenState();
}

class _FirstAidChatbotScreenState extends State<FirstAidChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // Welcome message
    _addBotMessage(
      FirstAidResponses.getResponse('hello')!,
    );
  }

  void _addBotMessage(FirstAidResponse response) {
    setState(() {
      _messages.add(_ChatMessage(response: response, isUser: false));
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(userText: text, isUser: true));
    });
    _controller.clear();
    _scrollToBottom();

    // Process after short delay for natural feel
    Future.delayed(const Duration(milliseconds: 500), () {
      final response = FirstAidResponses.getResponse(text) ??
          FirstAidResponses.getUnknownResponse(text);
      _addBotMessage(response);
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.success,
        title: const Row(
          children: [
            Icon(Icons.medical_services, size: 20),
            SizedBox(width: 8),
            Text('First Aid Bot'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_off, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick topic chips
          _buildQuickTopics(),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return msg.isUser
                    ? _buildUserBubble(msg.userText ?? '')
                    : _buildBotBubble(msg.response!);
              },
            ),
          ),

          // Input
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildQuickTopics() {
    final topics = [
      'Burns', 'Bleeding', 'CPR', 'Fracture',
      'Snake Bite', 'Choking',
    ];
    return Container(
      height: 44,
      color: AppColors.success.withValues(alpha: 0.05),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: topics.map((topic) => GestureDetector(
          onTap: () {
            _controller.text = topic;
            _sendMessage();
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Text(
              topic,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.all(12),
        // ignore: prefer_const_constructors
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildBotBubble(FirstAidResponse response) {
    final severityColor = _severityColor(response.severity);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
              color: severityColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      response.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: severityColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      response.severity,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Steps
                  if (response.steps.isNotEmpty) ...[
                    const Text('STEPS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 6),
                    ...response.steps.asMap().entries.map((e) {
                      final isStep = !e.value.startsWith('•') &&
                          !e.value.startsWith('  ') &&
                          !e.value.startsWith('I ') &&
                          !e.value.startsWith('Type');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isStep)
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(
                                    right: 8, top: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 28),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Warnings
                  if (response.warnings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('⚠️ WARNINGS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 6),
                    ...response.warnings.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• $w',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                            ),
                          ),
                        )),
                  ],

                  // Call Emergency
                  if (response.callEmergency.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🚨 CALL 112 IF:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                                letterSpacing: 1,
                              )),
                          const SizedBox(height: 4),
                          ...response.callEmergency.map((c) =>
                              Text(
                                '• $c',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask about burns, CPR, bleeding...',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.success,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return Colors.orange;
      default:
        return AppColors.success;
    }
  }
}

class _ChatMessage {
  final bool isUser;
  final String? userText;
  final FirstAidResponse? response;

  _ChatMessage({required this.isUser, this.userText, this.response});
}