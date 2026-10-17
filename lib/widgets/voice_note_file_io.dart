import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readVoiceNoteFile(String path) => File(path).readAsBytes();

Future<void> deleteVoiceNoteFile(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}

bool voiceNoteFileExists(String path) => File(path).existsSync();
