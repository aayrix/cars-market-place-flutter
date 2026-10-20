import '../utils/error_messages.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  /// Ensures that the underlying `chat_threads` row exists before an upload
  /// that depends on conversation membership (such as a voice note) is
  /// attempted. Sending the first text message creates the row; this keeps
  /// a first-message voice note from being rejected by storage RLS.
  Future<void> ensureThread({
    required String listingId,
    required String listingTitle,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(SupabaseConfig.setupHint);
    }
    final currentUser = _client.auth.currentUser;
    if (currentUser == null ||
        (currentUser.id != buyerId && currentUser.id != sellerId)) {
      throw StateError('Sign in again before sending a message.');
    }
    if (buyerId == sellerId) {
      throw StateError('You cannot start a chat with your own account.');
    }

    final threadId = threadIdFor(
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
    );
    final existing = await _client
        .from('chat_threads')
        .select('id')
        .eq('id', threadId)
        .maybeSingle();
    if (existing != null) return;

    // Only the buyer may create a thread under the existing RLS. If the
    // current user is the seller, the conversation must already exist.
    if (currentUser.id != buyerId) {
      throw StateError('This conversation has not been started yet.');
    }

    final now = DateTime.now().toUtc();
    final threadFields = {
      'id': threadId,
      'listing_id': listingId,
      'listing_title': listingTitle,
      'buyer_id': buyerId,
      'buyer_name': buyerName,
      'seller_id': sellerId,
      'seller_name': sellerName,
      'last_message': '',
      'last_message_at': now.toIso8601String(),
    };
    try {
      await _client.from('chat_threads').insert(threadFields);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchThreadsForUser(String userId) {
    if (!SupabaseConfig.isConfigured || userId.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return _refreshingSnapshots(() async {
      final rows = await _client
          .from('chat_threads')
          .select()
          .order('last_message_at', ascending: false);
      // RLS limits the query to threads the user participates in. Keep this
      // guard for older deployments/policies too.
      return List<Map<String, dynamic>>.from(rows)
          .map(_threadFromRow)
          .where((t) => t['buyerId'] == userId || t['sellerId'] == userId)
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String threadId) {
    if (!SupabaseConfig.isConfigured) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return _refreshingSnapshots(() async {
      final rows = await _client
          .from('chat_messages')
          .select()
          .eq('thread_id', threadId)
          .order('sent_at', ascending: true);
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(_messageFromRow).toList();
    });
  }

  /// Re-fetches on a short interval so an interrupted Realtime socket cannot
  /// leave an open conversation stuck on its last snapshot after reconnect.
  Stream<T> _refreshingSnapshots<T>(Future<T> Function() fetch) async* {
    while (true) {
      try {
        yield await fetch();
      } catch (error) {
        debugLog('Chat refresh failed; will retry: $error');
      }
      await Future<void>.delayed(const Duration(seconds: 4));
    }
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

  /// Sends a message and returns the new message's id.
  /// Base URL of the deployed `chat-push` Supabase Edge Function.
  /// Set this after deploying the function to Supabase.
  static const chatPushFunctionUrl = String.fromEnvironment(
    'CHAT_PUSH_FUNCTION_URL',
    defaultValue: '',
  );

  /// Secret for the chat-push Edge Function webhook.
  static const chatPushWebhookSecret = String.fromEnvironment(
    'CHAT_PUSH_WEBHOOK_SECRET',
    defaultValue: '',
  );

  Future<String> sendMessage({
    required String listingId,
    required String listingTitle,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String senderId,
    required String senderName,
    required String text,
    double? latitude,
    double? longitude,
    String? locationTitle,
    DateTime? locationExpiresAt,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return '';
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

    final inserted = await _client
        .from('chat_messages')
        .insert({
          'thread_id': threadId,
          'sender_id': senderId,
          'sender_name': senderName,
          'body': body,
          'sent_at': now.toIso8601String(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (locationTitle != null) 'location_title': locationTitle,
          if (locationExpiresAt != null)
            'location_expires_at': locationExpiresAt.toUtc().toIso8601String(),
          'location_updated_at': now.toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    // Trigger push notification to the recipient via the chat-push Edge Function.
    if (chatPushFunctionUrl.isNotEmpty) {
      unawaited(
        _notifyRecipient(
          threadId: threadId,
          listingId: listingId,
          listingTitle: listingTitle,
          buyerId: buyerId,
          buyerName: buyerName,
          sellerId: sellerId,
          sellerName: sellerName,
          senderId: senderId,
          senderName: senderName,
        ),
      );
    }

    return '${inserted['id']}';
  }

  /// Calls the deployed `chat-push` Edge Function so the recipient receives a
  /// push notification about the new message. Runs fire-and-forget so it never
  /// blocks message delivery.
  Future<void> _notifyRecipient({
    required String threadId,
    required String listingId,
    required String listingTitle,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String senderId,
    required String senderName,
  }) async {
    if (chatPushFunctionUrl.isEmpty || chatPushWebhookSecret.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse(chatPushFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-webhook-secret': chatPushWebhookSecret,
        },
        body: jsonEncode({
          'type': 'INSERT',
          'table': 'chat_messages',
          'schema': 'public',
          'record': {
            'thread_id': threadId,
            'sender_id': senderId,
            'sender_name': senderName,
          },
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugLog('Push notification failed: ${response.statusCode}');
      }
    } catch (error) {
      debugLog('Push notification error: $error');
    }
  }

  /// Refreshes the location of a live-location message sent by the current user.
  Future<void> updateMessageLocation({
    required String threadId,
    required String messageId,
    required double latitude,
    required double longitude,
    required DateTime expiresAt,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(SupabaseConfig.setupHint);
    }
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('Sign in again to update your live location.');
    }
    await _client
        .from('chat_messages')
        .update({
          'latitude': latitude,
          'longitude': longitude,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
          'location_expires_at': expiresAt.toUtc().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', currentUser.id);
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
    'latitude': row['latitude'] == null
        ? null
        : double.tryParse('${row['latitude']}'),
    'longitude': row['longitude'] == null
        ? null
        : double.tryParse('${row['longitude']}'),
    'locationTitle': '${row['location_title'] ?? ''}',
    'locationExpiresAt': row['location_expires_at'] == null
        ? null
        : DateTime.tryParse('${row['location_expires_at']}'),
    'locationUpdatedAt': row['location_updated_at'] == null
        ? null
        : DateTime.tryParse('${row['location_updated_at']}'),
  };
}
