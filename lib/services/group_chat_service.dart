import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import 'profile_service.dart';

class GroupChatService {
  SupabaseClient get _db => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> watchGroups() {
    if (!SupabaseConfig.isConfigured) return Stream.value(const []);
    return _db
        .from('group_chats')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String groupId) {
    if (!SupabaseConfig.isConfigured) return Stream.value(const []);
    return _db
        .from('group_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('sent_at');
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

  Future<void> sendMessage({
    required String groupId,
    required String text,
    required String senderName,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in to send messages.');
    await _db.from('group_chat_messages').insert({
      'group_id': groupId,
      'sender_id': uid,
      'sender_name': senderName,
      'body': body,
    });
  }
}
