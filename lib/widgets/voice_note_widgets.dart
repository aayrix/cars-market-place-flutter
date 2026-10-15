import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../services/voice_note_service.dart';
import '../utils/error_messages.dart';

typedef VoiceNoteCallback =
    Future<void> Function(Uint8List wavBytes, Duration duration);

class VoiceNoteRecorderButton extends StatefulWidget {
  const VoiceNoteRecorderButton({
    super.key,
    required this.onRecorded,
    this.disabled = false,
  });

  final VoiceNoteCallback onRecorded;
  final bool disabled;

  @override
  State<VoiceNoteRecorderButton> createState() =>
      _VoiceNoteRecorderButtonState();
}

class _VoiceNoteRecorderButtonState extends State<VoiceNoteRecorderButton> {
  final _recorder = AudioRecorder();
  final _audio = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _streamSubscription;
  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _sending = false;

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        _showError('Microphone permission is required to record a voice note.');
        return;
      }
      _audio.clear();
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 24000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _streamSubscription = stream.listen(
        _audio.add,
        onError: (Object error) =>
            _showError('Microphone recording failed: $error'),
      );
      setState(() => _recording = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final started = _startedAt;
        if (!mounted || started == null) return;
        setState(() => _elapsed = DateTime.now().difference(started));
        if (_elapsed >= const Duration(minutes: 3)) _stopAndSend();
      });
    } catch (error) {
      _showError('Could not start recording: $error');
    }
  }

  Future<void> _stopAndSend() async {
    if (!_recording || _sending) return;
    _timer?.cancel();
    final duration = _startedAt == null
        ? _elapsed
        : DateTime.now().difference(_startedAt!);
    setState(() {
      _recording = false;
      _sending = true;
    });
    try {
      await _recorder.stop();
      await _streamSubscription?.cancel();
      final pcm = _audio.takeBytes();
      if (pcm.length < 2400) {
        _showError('Record a little longer before sending.');
        return;
      }
      await widget.onRecorded(_wav(pcm), duration);
    } catch (error) {
      _showError('Could not send voice note: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Uint8List _wav(Uint8List pcm) {
    const sampleRate = 24000;
    const channels = 1;
    const bitsPerSample = 16;
    final header = ByteData(44);
    void writeTag(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        header.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeTag(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    writeTag(8, 'WAVE');
    writeTag(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(
      28,
      sampleRate * channels * bitsPerSample ~/ 8,
      Endian.little,
    );
    header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    writeTag(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamSubscription?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_recording)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            _formatDuration(_elapsed),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontFeatures: const [],
            ),
          ),
        ),
      IconButton.filled(
        tooltip: _recording ? 'Stop and send voice note' : 'Record voice note',
        onPressed: widget.disabled || _sending
            ? null
            : _recording
            ? _stopAndSend
            : _start,
        style: IconButton.styleFrom(
          backgroundColor: _recording
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: _recording
              ? Colors.white
              : Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        icon: _sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_recording ? Icons.stop : Icons.mic_none),
      ),
    ],
  );
}

class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.path,
    required this.duration,
    required this.mine,
  });
  final String path;
  final Duration duration;
  final bool mine;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  late final StreamSubscription<PlayerState> _stateSubscription;
  late final StreamSubscription<Duration> _positionSubscription;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
  }

  Future<void> _toggle() async {
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
      } else {
        if (_state == PlayerState.completed) await _player.seek(Duration.zero);
        final url = await VoiceNoteService().signedUrl(widget.path);
        await _player.play(UrlSource(url));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.from(
                error,
                fallback: 'Could not play this voice note. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    _positionSubscription.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.mine
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final maxMs = widget.duration.inMilliseconds;
    final progress = maxMs <= 0
        ? 0.0
        : (_position.inMilliseconds / maxMs).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            color: color,
            icon: Icon(
              _state == PlayerState.playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              size: 34,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  color: widget.mine
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                  backgroundColor: color.withValues(alpha: .24),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatDuration(
                      _position > widget.duration
                          ? widget.duration
                          : widget.duration - _position,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
