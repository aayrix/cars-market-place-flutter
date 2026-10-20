import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatCallService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> startCall({
    required String threadId,
    required String callerId,
    required String calleeId,
    required String callType,
  }) async {
    final roomName = 'ag-${const Uuid().v4()}';
    final row = await _client
        .from('chat_calls')
        .insert({
          'thread_id': threadId,
          'caller_id': callerId,
          'callee_id': calleeId,
          'room_name': roomName,
          'call_type': callType,
        })
        .select()
        .single();
    return row;
  }

  Future<Map<String, dynamic>?> findRingingCall(String threadId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return _client
        .from('chat_calls')
        .select()
        .eq('thread_id', threadId)
        .eq('callee_id', userId)
        .eq('status', 'ringing')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Stream<Map<String, dynamic>> watchIncomingCalls(String userId) {
    final channel = _client.channel('incoming-calls:$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty)
              _incomingController.add(payload.newRecord);
          },
        )
        .subscribe();
    _incomingChannels[userId] = channel;
    return _incomingController.stream;
  }

  Future<Map<String, dynamic>?> findLatestRingingCall(String userId) async {
    return _client
        .from('chat_calls')
        .select()
        .eq('callee_id', userId)
        .eq('status', 'ringing')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> getCallThread(String threadId) async {
    return _client
        .from('chat_threads')
        .select(
          'listing_id,listing_title,buyer_id,buyer_name,seller_id,seller_name',
        )
        .eq('id', threadId)
        .single();
  }

  Future<Map<String, dynamic>?> findCallById(String callId) async {
    return _client.from('chat_calls').select().eq('id', callId).maybeSingle();
  }

  final StreamController<Map<String, dynamic>> _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, RealtimeChannel> _incomingChannels = {};

  Future<void> stopWatchingIncomingCalls(String userId) async {
    final channel = _incomingChannels.remove(userId);
    if (channel != null) await _client.removeChannel(channel);
  }

  Future<void> setStatus(String id, String status) async {
    await _client
        .from('chat_calls')
        .update({
          'status': status,
          if (status == 'ended' || status == 'declined')
            'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Writes a compact, idempotent call-history message into the conversation.
  Future<void> recordCallEvent({
    required Map<String, dynamic> call,
    required String kind,
    required int durationSeconds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final callId = '${call['id']}';
    final threadId = '${call['thread_id']}';
    final marker = '[[CALL_EVENT:$callId:';
    final existing = await _client
        .from('chat_messages')
        .select('id')
        .eq('thread_id', threadId)
        .like('body', '$marker%')
        .limit(1);
    if (existing.isNotEmpty) return;

    final thread = await _client
        .from('chat_threads')
        .select('buyer_id,buyer_name,seller_id,seller_name')
        .eq('id', threadId)
        .single();
    final senderName = user.id == '${thread['buyer_id']}'
        ? '${thread['buyer_name'] ?? ''}'
        : '${thread['seller_name'] ?? ''}';
    final body = '$marker$kind:$durationSeconds]]';
    final now = DateTime.now().toUtc();
    await _client.from('chat_messages').insert({
      'thread_id': threadId,
      'sender_id': user.id,
      'sender_name': senderName,
      'body': body,
      'sent_at': now.toIso8601String(),
    });
    await _client
        .from('chat_threads')
        .update({
          'last_message': _eventLabel(kind, durationSeconds),
          'last_message_at': now.toIso8601String(),
        })
        .eq('id', threadId);
  }

  static String _eventLabel(String kind, int durationSeconds) {
    if (kind == 'completed') {
      final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
      return 'Call · $minutes:$seconds';
    }
    if (kind == 'declined') return 'Declined voice call';
    return 'Missed voice call';
  }

  RealtimeChannel watchThread(
    String threadId,
    void Function(Map<String, dynamic> call) onCall,
  ) {
    final channel = _client.channel('calls:$threadId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            final row = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            if (row.isNotEmpty) onCall(row);
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> unwatch(RealtimeChannel? channel) async {
    if (channel != null) await _client.removeChannel(channel);
  }
}
