import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import '../utils/error_messages.dart';
import 'profile_service.dart';

class GroupChatService {
  SupabaseClient get _db => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> watchGroups() {
    if (!SupabaseConfig.isConfigured) return Stream.value(const []);
    return _refreshingSnapshots(() async {
      final rows = await _db
          .from('group_chats')
          .select()
          .order('last_message_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    });
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String groupId) {
    if (!SupabaseConfig.isConfigured) return Stream.value(const []);
    return _refreshingSnapshots(() async {
      final rows = await _db
          .from('group_chat_messages')
          .select()
          .eq('group_id', groupId)
          .order('sent_at');
      return List<Map<String, dynamic>>.from(rows);
    });
  }

  /// Polling recovers the visible chat after a network interruption, even if
  /// the Realtime websocket does not reconnect on its own.
  Stream<T> _refreshingSnapshots<T>(Future<T> Function() fetch) async* {
    while (true) {
      try {
        yield await fetch();
      } catch (error) {
        // Keep the stream alive while offline; the next interval retries.
        debugLog('Group chat refresh failed; will retry: $error');
      }
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }

  Future<List<UserProfile>> fetchConnections() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in to create a group.');
    final rows = await _db
        .from('user_connections')
        .select('requester_id,addressee_id')
        .eq('status', 'accepted')
        .or('requester_id.eq.$uid,addressee_id.eq.$uid');
    final ids = <String>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final a = '${row['requester_id']}';
      final b = '${row['addressee_id']}';
      ids.add(a == uid ? b : a);
    }
    final profiles = await ProfileService().fetchForUsers(ids);
    return profiles.values.toList()..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  }

  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final result = await _db.rpc(
      'create_group_chat',
      params: {'p_name': name.trim(), 'p_member_ids': memberIds},
    );
    return '$result';
  }

  Future<List<UserProfile>> members(String groupId) async {
    final rows = await _db
        .from('group_chat_members')
        .select('user_id')
        .eq('group_id', groupId);
    final ids = List<Map<String, dynamic>>.from(
      rows,
    ).map((r) => '${r['user_id']}').toList();
    final profiles = await ProfileService().fetchForUsers(ids);
    return ids.map((id) => profiles[id] ?? UserProfile(id: id)).toList();
  }

  /// Sends a message and returns the new message's id.
  Future<String> sendMessage({
    required String groupId,
    required String text,
    required String senderName,
    double? latitude,
    double? longitude,
    String? locationTitle,
    DateTime? locationExpiresAt,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return '';
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in to send messages.');
    final now = DateTime.now().toUtc();
    final inserted = await _db
        .from('group_chat_messages')
        .insert({
          'group_id': groupId,
          'sender_id': uid,
          'sender_name': senderName,
          'body': body,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (locationTitle != null) 'location_title': locationTitle,
          if (locationExpiresAt != null)
            'location_expires_at': locationExpiresAt.toIso8601String(),
          'location_updated_at': now.toIso8601String(),
        })
        .select('id')
        .single();
    return '${inserted['id']}';
  }

  /// Refreshes the location of a live-location message sent by the current user.
  Future<void> updateMessageLocation({
    required String groupId,
    required String messageId,
    required double latitude,
    required double longitude,
    required DateTime expiresAt,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in to update your live location.');
    await _db
        .from('group_chat_messages')
        .update({
          'latitude': latitude,
          'longitude': longitude,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
          'location_expires_at': expiresAt.toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', uid);
  }
}
