import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_messages.dart';

class SafetyService {
  SupabaseClient get _db => Supabase.instance.client;

  String _errorMessage(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42P01' || error.code == 'PGRST205') {
        return 'Safety features are not installed yet. Run '
            'supabase/migrations/202610200001_trust_safety.sql in Supabase.';
      }
      if (error.code == '42501') {
        return 'Safety permissions are not installed. Rerun '
            'supabase/migrations/202610200001_trust_safety.sql in Supabase.';
      }
    }
    return ErrorMessages.from(error);
  }

  Future<String?> report({String? listingId, String? userId, required String reason, String details = ''}) async {
    try {
      final me = _db.auth.currentUser?.id;
      if (me == null) return 'Sign in to send a report.';
      if ((listingId == null) == (userId == null)) {
        return 'Choose either a listing or a user to report.';
      }
      await _db.from('reports').insert({
        'reporter_id': me,
        'target_type': listingId != null ? 'listing' : 'user',
        if (listingId != null) 'listing_id': listingId,
        if (userId != null) 'reported_user_id': userId,
        'reason': reason,
        'details': details,
      });
      return null;
    } catch (error) { return _errorMessage(error); }
  }

  Future<String?> block(String userId) async {
    try {
      final me = _db.auth.currentUser?.id;
      if (me == null) return 'Sign in to block a user.';
      if (me == userId) return 'You cannot block your own account.';
      await _db.from('blocked_users').upsert({'blocker_id': me, 'blocked_id': userId});
      return null;
    } catch (error) { return _errorMessage(error); }
  }

  Future<List<Map<String, dynamic>>> blockedUsers() async {
    try {
      final me = _db.auth.currentUser?.id;
      if (me == null) return [];
      final rows = await _db.from('blocked_users').select('blocked_id,created_at').eq('blocker_id', me);
      return List<Map<String, dynamic>>.from(rows);
    } catch (error) { throw Exception(_errorMessage(error)); }
  }

  Future<String?> unblock(String userId) async {
    try {
      final me = _db.auth.currentUser?.id;
      if (me == null) return 'Sign in to manage blocked users.';
      await _db.from('blocked_users').delete().eq('blocker_id', me).eq('blocked_id', userId);
      return null;
    } catch (error) { return _errorMessage(error); }
  }
}
