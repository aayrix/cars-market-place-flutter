import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});
  static const String _localUserId = 'local-user';

  @override
  Widget build(BuildContext context) {
    const uid = _localUserId;
    final chat = ChatService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: chat.watchThreadsForUser(uid),
      builder: (context, snap) {
        final threads = snap.data ?? const <Map<String, dynamic>>[];
        if (threads.isEmpty) {
          return const Center(child: Text('No chats yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: threads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final t = threads[i];
            final sellerId = '${t['sellerId'] ?? ''}';
            final buyerId = '${t['buyerId'] ?? ''}';
            final sellerName = '${t['sellerName'] ?? 'Seller'}';
            final buyerName = '${t['buyerName'] ?? 'Buyer'}';
            final otherName = uid == sellerId ? buyerName : sellerName;
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
              title: Text('${t['listingTitle'] ?? 'Listing'}'),
              subtitle: Text('${t['lastMessage'] ?? ''}'),
              trailing: Text(otherName),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      listingId: '${t['listingId'] ?? ''}',
                      listingTitle: '${t['listingTitle'] ?? 'Listing'}',
                      buyerId: buyerId,
                      buyerName: buyerName,
                      sellerId: sellerId,
                      sellerName: sellerName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
