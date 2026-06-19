import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.listingId,
    required this.listingTitle,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
  });

  final String listingId;
  final String listingTitle;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _message = TextEditingController();
  final ChatService _chat = ChatService();
  static const String _localUserId = 'local-user';
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    const senderId = _localUserId;
    setState(() => _sending = true);
    try {
      await _chat.sendMessage(
        listingId: widget.listingId,
        listingTitle: widget.listingTitle,
        buyerId: widget.buyerId,
        buyerName: widget.buyerName,
        sellerId: widget.sellerId,
        sellerName: widget.sellerName,
        senderId: senderId,
        senderName: 'User',
        text: _message.text,
      );
      _message.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const uid = _localUserId;
    final threadId = _chat.threadIdFor(
      listingId: widget.listingId,
      buyerId: widget.buyerId,
      sellerId: widget.sellerId,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.listingTitle)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chat.watchMessages(threadId),
              builder: (context, snap) {
                final items = snap.data ?? const <Map<String, dynamic>>[];
                if (items.isEmpty) {
                  return const Center(child: Text('Start conversation here.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final mine = m['senderId'] == uid;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${m['senderName'] ?? 'User'}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            Text('${m['text'] ?? ''}'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
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
                    decoration: const InputDecoration(
                      hintText: 'Type message',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
