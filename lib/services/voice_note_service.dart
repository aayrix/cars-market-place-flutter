import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';

class VoiceNoteService {
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
    await _db.storage
        .from('chat-audio')
        .uploadBinary(
          path,
          wavBytes,
          fileOptions: const FileOptions(contentType: 'audio/wav'),
        );
    return path;
  }

  Future<String> signedUrl(String path) async {
    final result = await _db.storage
        .from('chat-audio')
        .createSignedUrl(path, 3600);
    return result;
  }
}
