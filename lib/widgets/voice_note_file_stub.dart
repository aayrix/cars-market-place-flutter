import 'dart:typed_data';

Future<Uint8List> readVoiceNoteFile(String path) =>
    throw UnsupportedError('Voice note files are not supported on this platform.');

Future<void> deleteVoiceNoteFile(String path) async {}

bool voiceNoteFileExists(String path) => false;
