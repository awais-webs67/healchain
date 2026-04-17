/// ─────────────────────────────────────────────────────────────────────────────
/// ChatbotScreen — AI assistant with real Gemini/OpenRouter integration
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/chat_message_model.dart';
import '../../services/ai_chatbot_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  bool _isTyping = false;
  final _uuid = const Uuid();
  final _ai = AiChatbotService.instance;
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _addBotMessage(
      'Hello! 👋 I\'m your HealChain AI assistant. I can help you:\n\n'
      '• Find blood donors near you\n'
      '• Check blood group compatibility\n'
      '• Answer health questions about donation\n'
      '• Guide you through the app\n\n'
      'How can I help you today?',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  void _addBotMessage(String content) {
    setState(() {
      _messages.add(ChatMessageModel(
        id: _uuid.v4(),
        role: 'assistant',
        content: content,
      ));
    });
    _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _messageController.clear();

    setState(() {
      _messages.add(ChatMessageModel(
        id: _uuid.v4(),
        role: 'user',
        content: text,
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await _ai.sendMessage(text, _messages);
      if (!mounted) return;
      setState(() => _isTyping = false);
      _addBotMessage(response);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTyping = false);
      _addBotMessage(
        'Sorry, I encountered an error. Please try again. 🔄\n\n'
        '_Error: ${e.toString().length > 80 ? '${e.toString().substring(0, 80)}...' : e}_',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isTyping
                      ? Text('typing...', key: const ValueKey('typing'), style: TextStyle(fontSize: 11, color: AppTheme.success))
                      : Text('online', key: const ValueKey('online'), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _TypingIndicator(animation: _dotController);
                }
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),

          // Quick suggestions (only show at start)
          if (_messages.length <= 1) _quickSuggestions(isDark),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Ask me anything...',
                        filled: true,
                        fillColor: isDark ? AppTheme.darkCard : AppTheme.lightBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isTyping ? null : _sendMessage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: _isTyping ? null : AppTheme.heroGradient,
                        color: _isTyping
                            ? (isDark ? AppTheme.darkCard : AppTheme.lightBorder)
                            : null,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        size: 22,
                        color: _isTyping
                            ? (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickSuggestions(bool isDark) {
    final suggestions = [
      '🩸 Blood compatibility',
      '✅ Am I eligible?',
      '🔍 Find donors near me',
      '📋 How to donate',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: suggestions.map((s) {
          return GestureDetector(
            onTap: () {
              _messageController.text = s.replaceAll(RegExp(r'^[^\s]+ '), '');
              _sendMessage();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Text(s,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textSecondary : AppTheme.textDarkSecondary,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Chat Bubble
// ═══════════════════════════════════════════════════════════════════════════════
class _ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser ? AppTheme.heroGradient : null,
          color: isUser
              ? null
              : isDark
                  ? AppTheme.darkCard
                  : AppTheme.lightCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 0.5,
                ),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? AppTheme.primaryRed.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildRichText(
          message.content,
          isUser
              ? Colors.white
              : isDark
                  ? AppTheme.textPrimary
                  : AppTheme.textDark,
        ),
      ),
    );
  }

  /// Simple markdown-like bold text rendering
  Widget _buildRichText(String text, Color color) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, height: 1.5, color: color),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Animated Typing Indicator
// ═══════════════════════════════════════════════════════════════════════════════
class _TypingIndicator extends StatelessWidget {
  final AnimationController animation;
  const _TypingIndicator({required this.animation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 0.5,
          ),
        ),
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i * 0.33;
              final t = ((animation.value + delay) % 1.0);
              final scale = 0.5 + (t < 0.5 ? t : 1.0 - t) * 1.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8 * scale,
                height: 8 * scale,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.4 + scale * 0.3),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
