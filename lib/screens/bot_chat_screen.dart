import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/bot_service.dart';
import '../utils/error_messages.dart';

/// AI-powered assistant chat backed by the `car-assistant` Supabase Edge
/// Function (Gemini). Messages live in memory while the screen is open — no
/// database tables are created and no API keys are embedded in the client.
class BotChatScreen extends StatefulWidget {
  const BotChatScreen({super.key});

  @override
  State<BotChatScreen> createState() => _BotChatScreenState();
}

class _BotChatScreenState extends State<BotChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _message = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  final BotService _botService = BotService.instance;
  bool _sending = false;
  String? _error;
  bool _supabaseReady = false;

  static const _botId = 'apni-gari-assistant';
  static const _botName = 'Apni Gari Assistant';
  static const int _maxMessageLength = 2000;

  // Cached theme values to avoid repeated lookups during list builds.
  late ColorScheme _cs;
  late double _maxBubbleWidth;

  @override
  void initState() {
    super.initState();
    _checkSupabaseReady();
    _addBotMessage(
      "Hello! I'm your Apni Gari assistant — your AI car-buying helper for "
      'Mianwali, Pakistan. Ask me about vehicle recommendations, fuel economy, '
      'price comparisons, or advice for first-time buyers.',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cs = Theme.of(context).colorScheme;
    _maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.88;
  }

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkSupabaseReady() async {
    final ready = SupabaseConfig.isConfigured;
    if (!mounted) return;
    setState(() => _supabaseReady = ready);
    if (!ready) {
      debugLog('Supabase not configured — assistant will not work.');
    }
  }

  void _addBotMessage(String text, {bool error = false}) {
    _messages.add(_ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: _botId,
      senderName: _botName,
      text: text,
      sentAt: DateTime.now().toUtc().toIso8601String(),
      isBot: true,
      isError: error,
    ));
  }

  void _addUserMessage(String text) {
    final user = Supabase.instance.client.auth.currentUser;
    _messages.add(_ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: user?.id ?? 'me',
      senderName:
          user?.userMetadata?['full_name'] ?? user?.email ?? 'You',
      text: text,
      sentAt: DateTime.now().toUtc().toIso8601String(),
      isBot: false,
    ));
  }

  Future<void> _send(String raw) async {
    if (!_supabaseReady) {
      _showError(
        'Supabase is not configured. Please check your app settings.',
      );
      return;
    }

    final text = raw.trim();
    if (_sending || text.isEmpty) return;
    if (text.length > _maxMessageLength) {
      _showError('Message is too long. Please shorten it and try again.');
      return;
    }

    _addUserMessage(text);
    _message.clear();
    _scrollToBottom();

    final typingId = 'typing-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(_ChatMessage(
        id: typingId,
        senderId: _botId,
        senderName: _botName,
        text: '',
        sentAt: DateTime.now().toUtc().toIso8601String(),
        isBot: true,
        isTyping: true,
      ));
    });
    _scrollToBottom();

    try {
      final reply = await _botService.askAssistant(text);

      if (!mounted) return;

      setState(() {
        _messages.removeWhere((m) => m.id == typingId);
        _addBotMessage(reply);
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == typingId);
        _sending = false;
      });
      _scrollToBottom();

      final msg = _assistantErrorMessage(e);
      debugLog('Assistant error: $e');
      setState(() {
        _error = msg;
      });
      _addBotMessage(msg, error: true);
    }
  }

  void _retryLast() {
    final lastUser = _messages.lastWhere(
      (m) => !m.isBot,
      orElse: () => _ChatMessage.empty(),
    );
    if (lastUser.id.isNotEmpty) {
      _send(lastUser.text);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _cs.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.position.hasPixels) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _assistantErrorMessage(Object e) {
    final message = e.toString().toLowerCase();

    if (message.contains('429') ||
        message.contains('rate limit') ||
        message.contains('too many') ||
        message.contains('quota')) {
      return 'The assistant is busy right now. Please wait a moment and try again.';
    }
    if (message.contains('401') || message.contains('unauthorized')) {
      return 'Sign in to use the AI assistant.';
    }
    if (message.contains('403') || message.contains('forbidden')) {
      return 'You are not allowed to use the assistant.';
    }
    if (message.contains('404') || message.contains('not found')) {
      return 'The assistant function is not deployed. Please contact support.';
    }
    if (message.contains('503') || message.contains('unavailable')) {
      return 'The assistant is temporarily unavailable. Please try again shortly.';
    }
    if (message.contains('timeout') || message.contains('timed out')) {
      return 'The request timed out. Please try again.';
    }
    if (message.contains('network') ||
        message.contains('connection') ||
        message.contains('fetch failed')) {
      return 'Check your internet connection and try again.';
    }
    if (message.contains('500') || message.contains('internal error')) {
      return 'The assistant encountered an error. Please try again later.';
    }
    return 'The assistant could not respond. Please try again.';
  }

  Widget _buildMessage(_ChatMessage m) {
    final mine = !m.isBot;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxBubbleWidth),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (m.isError) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _cs.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _cs.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.text,
                        style: TextStyle(
                          color: _cs.onErrorContainer,
                          fontSize: 13,
                        ),
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _sending ? null : _retryLast,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (!m.isTyping && !m.isError) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mine ? _cs.primary : _cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mine) ...[
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: _cs.primaryContainer,
                            child: Icon(
                              Icons.help,
                              color: _cs.primary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m.senderName,
                              style: TextStyle(
                                color: mine ? Colors.white : _cs.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      m.text,
                      style: TextStyle(
                        color: mine ? Colors.white : _cs.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
            if (m.isTyping) ...[
              // Simple, non-animated typing indicator — avoids the "bbbb"
              // rendering glitch caused by per-frame opacity animations.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: const Radius.circular(4),
                    bottomRight: const Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _cs.primaryContainer,
                      child: Icon(
                        Icons.help,
                        color: _cs.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Apni Gari Assistant is typing',
                      style: TextStyle(
                        color: _cs.onSurface,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!m.isTyping && !m.isError) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _messageTime(m.sentAt),
                  style: TextStyle(
                    color: mine ? Colors.white70 : _cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _messageTime(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.help, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _botName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'AI Assistant • '
                    '${!_supabaseReady ? 'offline' : _sending ? 'thinking…' : 'online'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: !_supabaseReady
                          ? cs.error
                          : _sending
                              ? cs.primary
                              : cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_supabaseReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: cs.errorContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Supabase not configured — AI assistant unavailable.',
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              cacheExtent: 500,
              itemBuilder: (_, i) => _buildMessage(_messages[i]),
            ),
          ),
          if (_error != null && _error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: cs.error,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Ask about cars, prices, fuel economy…',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _sending || !_supabaseReady
                        ? null
                        : (t) => _send(t),
                    enabled: !_sending && _supabaseReady,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending || !_supabaseReady
                      ? null
                      : () => _send(_message.text),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    required this.isBot,
    this.isTyping = false,
    this.isError = false,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String sentAt;
  final bool isBot;
  final bool isTyping;
  final bool isError;

  const _ChatMessage.empty()
      : id = '',
        senderId = '',
        senderName = '',
        text = '',
        sentAt = '',
        isBot = false,
        isTyping = false,
        isError = false;
}
