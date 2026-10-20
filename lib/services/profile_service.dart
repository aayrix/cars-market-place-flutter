import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../utils/error_messages.dart';
import '../models/user_profile.dart';

/// Reads and writes the `profiles` row for the signed-in user.
class ProfileService {
  SupabaseClient get _client => Supabase.instance.client;

  bool get isConfigured => SupabaseConfig.isConfigured;

  /// Full profile list for integrations that explicitly need it.
  /// Marketplace refreshes should use [fetchForUsers] instead.
  Future<Map<String, UserProfile>> fetchAll() async {
    final rows = await _client.from('profiles').select();
    final map = <String, UserProfile>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final profile = UserProfile.fromRow(row);
      map[profile.id] = profile;
    }
    return map;
  }

  /// Public profile details, enriched with seller contact fields where allowed.
  Future<Map<String, UserProfile>> fetchForUsers(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    List<dynamic> rows;
    try {
      rows = await _client
          .from('public_user_profiles')
          .select('id,full_name,city,avatar_url')
          .inFilter('id', ids);
      try {
        final sellers = await _client
            .from('public_seller_profiles')
            .select('id,phone')
            .inFilter('id', ids);
        final phoneById = {
          for (final row in List<Map<String, dynamic>>.from(sellers))
            '${row['id']}': row,
        };
        rows = List<Map<String, dynamic>>.from(rows)
            .map((row) => {...row, ...?phoneById['${row['id']}']})
            .toList();
      } catch (_) {
        // Public profile fields work even when seller contact view is absent.
      }
    } catch (viewError) {
      try {
        rows = await _client
            .from('public_seller_profiles')
            .select('id,full_name,phone,city,avatar_url')
            .inFilter('id', ids);
        if (rows.isEmpty) rows = await _fetchProfileRows(ids);
      } catch (profileError) {
        debugLog(
          'Seller profile view failed ($viewError); direct profile lookup '
          'also failed ($profileError).',
        );
        rethrow;
      }
    }
    final map = <String, UserProfile>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final profile = UserProfile.fromRow(row);
      map[profile.id] = profile;
    }
    return map;
  }

  Future<List<dynamic>> _fetchProfileRows(List<String> ids) async {
    try {
      return await _client
          .from('profiles')
          .select('id,full_name,phone,city,avatar_url,verified_phone,account_type')
          .inFilter('id', ids);
    } on PostgrestException catch (error) {
      // Older deployments may not have added avatar_url yet; seller name and
      // phone are still useful and remain readable from the existing columns.
      if (error.code != '42703' && error.code != 'PGRST204') rethrow;
      return _client
          .from('profiles')
          .select('id,full_name,phone,city')
          .inFilter('id', ids);
    }
  }

  /// Returns the profile for [userId], creating an empty one if the row is
  /// missing (e.g. the signup trigger did not run).
  Future<UserProfile> fetchOrCreate(String userId) async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .limit(1);

    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isNotEmpty) return UserProfile.fromRow(list.first);

    final inserted = await _client
        .from('profiles')
        .insert({'id': userId, 'full_name': '', 'phone': '', 'city': ''})
        .select()
        .single();

    return UserProfile.fromRow(inserted);
  }

  /// Updates the signed-in user's profile. Returns null on success or a
  /// human readable error message.
  Future<String?> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
    required String city,
    String? avatarUrl,
    String? accountType,
  }) async {
    try {
      final payload = <String, dynamic>{
        'id': userId,
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'city': city.trim(),
      };
      if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
      if (accountType != null) payload['account_type'] = accountType;
      await _client.from('profiles').upsert(payload);
      return null;
    } on PostgrestException catch (e) {
      debugLog('Profile update failed: $e');
      return _friendly(e.message);
    } catch (e) {
      debugLog('Profile update failed: $e');
      return 'Could not save your profile. Check your connection and try again.';
    }
  }

  Future<String> uploadAvatar(String userId, XFile image) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != userId) {
      throw StateError('Sign in again before changing your profile photo.');
    }
    final ext = p.extension(image.name).replaceFirst('.', '').toLowerCase();
    final safeExt = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? ext : 'jpg';
    final path =
        '$userId/profiles/${DateTime.now().microsecondsSinceEpoch}.$safeExt';
    final contentType = switch (safeExt) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    await _client.storage
        .from('car-images')
        .uploadBinary(
          path,
          await image.readAsBytes(),
          fileOptions: FileOptions(contentType: contentType),
        );
    return _client.storage.from('car-images').getPublicUrl(path);
  }

  Future<void> removeAvatar(String url) async {
    const marker = '/storage/v1/object/public/car-images/';
    final markerAt = url.indexOf(marker);
    if (markerAt < 0) return;
    final objectPath = Uri.decodeComponent(
      url.substring(markerAt + marker.length),
    );
    final userId = _client.auth.currentUser?.id;
    if (userId == null || !objectPath.startsWith('$userId/profiles/')) return;
    await _client.storage.from('car-images').remove([objectPath]);
  }

  String _friendly(String message) {
    return ErrorMessages.from(PostgrestException(message: message));
  }
}
