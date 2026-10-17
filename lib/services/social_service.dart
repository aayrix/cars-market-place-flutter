import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';

class SocialService {
  SupabaseClient get _db => Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> watchStories() {
    if (!SupabaseConfig.isConfigured) return Stream.value(const []);
    return _db.from('user_stories').stream(primaryKey: ['id']).map((rows) {
      final now = DateTime.now().toUtc();
      return rows.where((row) {
          final expiry = DateTime.tryParse('${row['expires_at'] ?? ''}');
          return expiry != null && expiry.isAfter(now);
        }).toList()
        ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    });
  }

  /// Fetches the display name for a given user from the `profiles` table.
  Future<String> fetchProfileName(String userId) async {
    final row = await _db
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();
    return '${row?['full_name'] ?? ''}'.trim();
  }

  Future<void> postStory(XFile file, {String caption = ''}) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(SupabaseConfig.setupHint);
    }
    final user = _db.auth.currentUser;
    if (user == null) throw StateError('Sign in to post a status.');
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(extension)
        ? extension
        : 'jpg';
    final path = '${user.id}/stories/${const Uuid().v4()}.$safeExtension';
    final mime = safeExtension == 'png' ? 'image/png' : 'image/jpeg';
    await _db.storage
        .from('car-images')
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    final url = _db.storage.from('car-images').getPublicUrl(path);
    final userProfile = await _db
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();
    final userName = '${userProfile?['full_name'] ?? ''}'.trim();
    await _db.from('user_stories').insert({
      'user_id': user.id,
      'user_name': userName,
      'media_url': url,
      'caption': caption.trim(),
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 24))
          .toIso8601String(),
    });
  }

  Future<int> connectionCount(String userId) async {
    if (!SupabaseConfig.isConfigured || userId.isEmpty) return 0;
    final rows = await _db
        .from('user_connections')
        .select('id')
        .eq('status', 'accepted')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId');
    return rows.length;
  }

  Future<String?> connectionStatus(String otherUserId) async {
    if (!SupabaseConfig.isConfigured) return null;
    final me = _db.auth.currentUser?.id;
    if (me == null || me == otherUserId) return null;
    final row = await _db
        .from('user_connections')
        .select('id,requester_id,addressee_id,status')
        .or(
          'and(requester_id.eq.$me,addressee_id.eq.$otherUserId),and(requester_id.eq.$otherUserId,addressee_id.eq.$me)',
        )
        .maybeSingle();
    if (row == null) return null;
    if (row['status'] == 'accepted') return 'connected';
    if (row['requester_id'] == me) return 'sent';
    return 'received:${row['id']}';
  }

  Future<void> requestConnection(String otherUserId) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(SupabaseConfig.setupHint);
    }
    final me = _db.auth.currentUser?.id;
    if (me == null) throw StateError('Sign in to connect with this person.');
    await _db.from('user_connections').insert({
      'requester_id': me,
      'addressee_id': otherUserId,
    });
  }

  Future<void> respondToConnection(
    String requestId, {
    required bool accept,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(SupabaseConfig.setupHint);
    }
    await _db
        .from('user_connections')
        .update({
          'status': accept ? 'accepted' : 'rejected',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId);
  }
}
