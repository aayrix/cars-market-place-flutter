import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../utils/error_messages.dart';

class VoiceNoteService {
  static const bucketId = 'chat-audio';
  SupabaseClient get _db => Supabase.instance.client;

  Future<String> upload({
    required Uint8List wavBytes,
    required String conversationType,
    required String conversationId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(SupabaseConfig.setupHint);
    }
    final user = _db.auth.currentUser;
    if (user == null) throw StateError('Sign in to send a voice note.');
    if (conversationType != 'threads' && conversationType != 'groups') {
      throw ArgumentError.value(conversationType, 'conversationType');
    }
    final path =
        '$conversationType/$conversationId/${user.id}/${const Uuid().v4()}.wav';
    try {
      await _db.storage
          .from(bucketId)
          .uploadBinary(
            path,
            wavBytes,
            fileOptions: const FileOptions(
              contentType: 'audio/wav',
              cacheControl: '3600',
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      debugLog(
        'Voice note upload failed (${error.statusCode}): ${error.message} '
        'path=$path bytes=${wavBytes.length}',
      );
      rethrow;
    }
    return path;
  }

  Future<String> signedUrl(String path) async {
    final result = await _db.storage.from(bucketId).createSignedUrl(path, 3600);
    return result;
  }
}
