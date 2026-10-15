import '../utils/error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Supabase-backed 1:1 chat between buyer and seller.
///
/// Threads are keyed by listing + both participants, so the same pair
/// always lands in one conversation per listing.
class ChatService {
  SupabaseClient get _client => Supabase.instance.client;

  String threadIdFor({
    required String listingId,
    required String buyerId,
    required String sellerId,
  }) {
    final sorted = [buyerId, sellerId]..sort();
    return '${listingId}_${sorted[0]}_${sorted[1]}';
  }

  Stream<List<Map<String, dynamic>>> watchThreadsForUser(String userId) {
    if (!SupabaseConfig.isConfigured || userId.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return _client
        .from('chat_threads')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((rows) {
          // RLS has already limited this initial snapshot to threads the user
          // participates in. Keep this guard for older deployments/policies.
          return rows.map(_threadFromRow).where((t) {
            return t['buyerId'] == userId || t['sellerId'] == userId;
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String threadId) {
    if (!SupabaseConfig.isConfigured) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('sent_at', ascending: true)
        .map((rows) => rows.map(_messageFromRow).toList());
  }

  Stream<int> watchUnreadCount(String userId) {
    if (!SupabaseConfig.isConfigured || userId.isEmpty) {
      return Stream<int>.value(0);
    }
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .neq('sender_id', userId)
        .map((rows) {
          return rows.where((row) {
            return row['read_at'] == null;
          }).length;
        });
  }

  Stream<Map<String, dynamic>> watchIncomingMessages(String userId) async* {
    if (!SupabaseConfig.isConfigured || userId.isEmpty) return;

    final seenIds = <String>{};
    var receivingInitialSnapshot = true;
    await for (final rows
        in _client
            .from('chat_messages')
            .stream(primaryKey: ['id'])
            .neq('sender_id', userId)) {
      if (receivingInitialSnapshot) {
        seenIds.addAll(rows.map((row) => '${row['id']}'));
        receivingInitialSnapshot = false;
        continue;
      }

      for (final row in rows) {
        final id = '${row['id']}';
        if (!seenIds.add(id)) continue;

        try {
          final thread = await _client
              .from('chat_threads')
              .select(
                'id,listing_id,listing_title,buyer_id,buyer_name,seller_id,seller_name',
              )
              .eq('id', '${row['thread_id']}')
              .maybeSingle();
          if (thread == null) continue;
          yield {
            ...thread,
            'notification_title':
                'New message from ${row['sender_name'] ?? 'Apni Gari user'}',
            'notification_body':
                'You have a new message about ${thread['listing_title'] ?? 'a listing'}.',
          };
        } catch (error) {
          debugLog('Could not load incoming chat details: $error');
        }
      }
    }
  }

  Future<int> markThreadRead({
    required String threadId,
    required String userId,
  }) async {
    if (!SupabaseConfig.isConfigured || threadId.isEmpty || userId.isEmpty) {
      return 0;
    }
    final updated = await _client
        .from('chat_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('thread_id', threadId)
        .neq('sender_id', userId)
        .isFilter('read_at', null)
        .select('id');
    return updated.length;
  }

  Future<void> sendMessage({
    required String listingId,
    required String listingTitle,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return;
    if (!SupabaseConfig.isConfigured) {
      throw StateError(SupabaseConfig.setupHint);
    }
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || currentUser.id != senderId) {
      throw StateError('Sign in again before sending a message.');
    }
    if (senderId != buyerId && senderId != sellerId) {
      throw StateError('Only a conversation participant can send messages.');
    }
    if (buyerId == sellerId) {
      throw StateError('You cannot start a chat with your own account.');
    }

    final now = DateTime.now().toUtc();
    final threadId = threadIdFor(
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
    );

    final threadFields = {
      'id': threadId,
      'listing_id': listingId,
      'listing_title': listingTitle,
      'buyer_id': buyerId,
      'buyer_name': buyerName,
      'seller_id': sellerId,
      'seller_name': sellerName,
      'last_message': body,
      'last_message_at': now.toIso8601String(),
    };

    // New threads are buyer-created by RLS. Replies update the existing
    // participant-owned row instead of using upsert, whose INSERT path can
    // reject the seller even when the UPDATE policy allows that participant.
    final existingThread = await _client
        .from('chat_threads')
        .select('id')
        .eq('id', threadId)
        .maybeSingle();
    if (existingThread == null) {
      try {
        await _client.from('chat_threads').insert(threadFields);
      } on PostgrestException catch (error) {
        // If two first messages race, one insert wins. Update the thread it
        // created when the competing insert reports the primary key conflict.
        if (error.code != '23505') rethrow;
        await _client
            .from('chat_threads')
            .update({
              'last_message': body,
              'last_message_at': now.toIso8601String(),
            })
            .eq('id', threadId);
      }
    } else {
      await _client
          .from('chat_threads')
          .update({
            'last_message': body,
            'last_message_at': now.toIso8601String(),
          })
          .eq('id', threadId);
    }

    await _client.from('chat_messages').insert({
      'thread_id': threadId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': body,
      'sent_at': now.toIso8601String(),
    });
  }

  Map<String, dynamic> _threadFromRow(Map<String, dynamic> row) => {
    'id': '${row['id']}',
    'listingId': '${row['listing_id']}',
    'listingTitle': '${row['listing_title'] ?? ''}',
    'buyerId': '${row['buyer_id']}',
    'buyerName': '${row['buyer_name'] ?? 'Buyer'}',
    'sellerId': '${row['seller_id']}',
    'sellerName': '${row['seller_name'] ?? 'Seller'}',
    'lastMessage': '${row['last_message'] ?? ''}',
    'lastMessageAt': row['last_message_at'] ?? '',
  };

  Map<String, dynamic> _messageFromRow(Map<String, dynamic> row) => {
    'id': '${row['id']}',
    'senderId': '${row['sender_id']}',
    'senderName': '${row['sender_name'] ?? ''}',
    'text': '${row['body'] ?? ''}',
    'sentAt': '${row['sent_at'] ?? ''}',
    'readAt': row['read_at'],
  };
}
