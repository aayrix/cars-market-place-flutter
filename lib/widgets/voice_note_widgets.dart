import 'dart:async';
import 'dart:typed_data';

import 'voice_note_file_stub.dart'
    if (dart.library.io) 'voice_note_file_io.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../services/voice_note_service.dart';
import '../utils/error_messages.dart';

typedef VoiceNoteCallback =
    Future<void> Function(Uint8List wavBytes, Duration duration);

const _recordConfig = RecordConfig(
  encoder: AudioEncoder.wav,
  sampleRate: 16000,
  numChannels: 1,
  autoGain: true,
  echoCancel: true,
  noiseSuppress: true,
);

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

class _VoiceNoteRecorderButtonState extends State<VoiceNoteRecorderButton>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  final _audio = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _streamSubscription;
  Timer? _timer;
  late final AnimationController _pulseController;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String? _recordingPath;
  bool _recording = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        _showError('Microphone permission is required to record a voice note.');
        return;
      }
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      if (kIsWeb) {
        _audio.clear();
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
            autoGain: true,
            echoCancel: true,
            noiseSuppress: true,
          ),
        );
        _streamSubscription = stream.listen(
          _audio.add,
          onError: (Object error) =>
              _showError('Microphone recording failed: $error'),
        );
      } else {
        final dir = await getTemporaryDirectory();
        _recordingPath = '${dir.path}/vn_${const Uuid().v4()}.wav';
        await _recorder.start(_recordConfig, path: _recordingPath!);
      }
      setState(() => _recording = true);
      _pulseController.repeat(reverse: true);
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
    _pulseController
      ..stop()
      ..reset();
    try {
      late final Uint8List bytes;
      if (kIsWeb) {
        await _recorder.stop();
        await _streamSubscription?.cancel();
        final pcm = _audio.takeBytes();
        if (pcm.length < 2400) {
          _showError('Record a little longer before sending.');
          return;
        }
        bytes = _wavFromPcm(pcm);
      } else {
        final stoppedPath = await _recorder.stop();
        final filePath = stoppedPath ?? _recordingPath;
        if (filePath == null || !voiceNoteFileExists(filePath)) {
          _showError('Recording was lost. Please try again.');
          return;
        }
        bytes = await readVoiceNoteFile(filePath);
        unawaited(deleteVoiceNoteFile(filePath));
      }
      if (duration < const Duration(milliseconds: 500)) {
        _showError('Record a little longer before sending.');
        return;
      }
      await widget.onRecorded(bytes, duration);
    } catch (error) {
      _showError('Could not send voice note: $error');
    } finally {
      _recordingPath = null;
      if (mounted) setState(() => _sending = false);
    }
  }

  Uint8List _wavFromPcm(Uint8List pcm) {
    const sampleRate = 16000;
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
    final bytes = Uint8List(44 + pcm.length);
    bytes.setRange(0, 44, header.buffer.asUint8List());
    if (pcm.isNotEmpty) {
      bytes.setRange(44, bytes.length, pcm);
    }
    return bytes;
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
    _pulseController.dispose();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recordingColor = scheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_recording) ...[
          _RecordingIndicator(
            controller: _pulseController,
            color: recordingColor,
          ),
          const SizedBox(width: 6),
          Text(
            _formatDuration(_elapsed),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: recordingColor,
              fontWeight: FontWeight.w700,
              fontFeatures: const [],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Recording',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: recordingColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        ScaleTransition(
          scale: Tween<double>(begin: 1, end: 1.08).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
          ),
          child: IconButton.filled(
            tooltip: _recording
                ? 'Stop and send voice note'
                : 'Record voice note',
            onPressed: widget.disabled || _sending
                ? null
                : _recording
                ? _stopAndSend
                : _start,
            style: IconButton.styleFrom(
              backgroundColor: recordingColor,
              foregroundColor: Colors.white,
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
          ),
        ),
      ],
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          final start = index * 0.12;
          final end = (start + 0.55).clamp(0.0, 1.0);
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(
                controller.value >= start && controller.value <= end
                    ? (controller.value - start) / (end - start)
                    : controller.value < start
                    ? 0
                    : 1,
              );
              final height =
                  6 + (14 * (0.35 + 0.65 * (1 - (t - 0.5).abs() * 2)));
              return Container(
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
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
  AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  String? _cachedSignedUrl;
  DateTime? _signedUrlCachedAt;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  void _bindPlayer(AudioPlayer player) {
    _stateSubscription = player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _positionSubscription = player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
  }

  Future<String> _signedUrl() async {
    final cachedAt = _signedUrlCachedAt;
    final now = DateTime.now();
    if (_cachedSignedUrl != null &&
        cachedAt != null &&
        now.difference(cachedAt) < const Duration(minutes: 50)) {
      return _cachedSignedUrl!;
    }
    final url = await VoiceNoteService().signedUrl(widget.path);
    _cachedSignedUrl = url;
    _signedUrlCachedAt = now;
    return url;
  }

  @override
  void initState() {
    super.initState();
    _bindPlayer(_player);
  }

  Future<void> _toggle() async {
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
      } else {
        if (_state == PlayerState.completed) {
          // A finished voice note cannot be replayed reliably on the same
          // AudioPlayer instance across every platform. Release it and start
          // with a fresh instance so the user can repeat the voice note.
          await _player.release();
          await _stateSubscription?.cancel();
          await _positionSubscription?.cancel();
          if (!mounted) return;
          _player = AudioPlayer();
          _bindPlayer(_player);
        }
        final url = await _signedUrl();
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
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
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
                      : Theme.of(context).colorScheme.secondary,
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
