import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/chat_call_service.dart';

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({
    super.key,
    required this.call,
    required this.otherName,
    required this.isCaller,
  });

  final Map<String, dynamic> call;
  final String otherName;
  final bool isCaller;

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  static const MethodChannel _permissionChannel = MethodChannel(
    'com.apnigari.one/permissions',
  );
  final ChatCallService _calls = ChatCallService();
  RtcEngine? _engine;
  RealtimeChannel? _callChannel;
  bool _muted = false;
  bool _speaker = true;
  bool _connecting = true;
  bool _connectedToOther = false;
  bool _cameraEnabled = false;
  bool _cameraOff = false;
  bool _frontCamera = true;
  int? _remoteUid;
  bool _ending = false;
  String? _error;
  Timer? _durationTimer;
  Timer? _connectionTimer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _joinCall();
    _watchCallStatus();
  }

  Future<Map<String, dynamic>> _getAgoraAccess() async {
    final response = await Supabase.instance.client.functions.invoke(
      'agora-call-token',
      body: {'call_id': widget.call['id']},
    );
    final data = response.data;
    if (data is! Map ||
        data['app_id'] is! String ||
        data['channel_name'] is! String ||
        data['token'] is! String) {
      throw StateError(
        'Call service returned invalid Agora connection details.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> _joinCall() async {
    var stage = 'checking microphone permission';
    RtcEngine? engine;
    try {
      final recorder = AudioRecorder();
      final microphoneAllowed = await recorder.hasPermission();
      await recorder.dispose();
      if (!microphoneAllowed) {
        throw StateError('Microphone permission is required to make a call.');
      }
      if (_isVideo && defaultTargetPlatform == TargetPlatform.android) {
        stage = 'requesting camera permission';
        final cameraAllowed = await _permissionChannel.invokeMethod<bool>(
          'requestCamera',
        );
        if (cameraAllowed != true) {
          throw StateError('Camera permission is required for a video call.');
        }
      }

      stage = 'requesting secure call access';
      final access = await _getAgoraAccess();

      stage = 'initializing the Agora engine';
      engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(
        RtcEngineContext(
          appId: access['app_id'] as String,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      await engine.enableAudio();
      if (_isVideo) {
        await engine.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 1920, height: 1080),
            frameRate: 60,
            orientationMode: OrientationMode.orientationModeAdaptive,
            degradationPreference: DegradationPreference.maintainFramerate,
          ),
        );
        await engine.enableVideo();
        await engine.startPreview();
        _cameraEnabled = true;
      }
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            _connectionTimer?.cancel();
            setState(() => _connecting = false);
            unawaited(_setSpeakerRoute(engine!));
          },
          onConnectionStateChanged: (connection, state, reason) {
            debugPrint(
              'Agora connection state: ${state.name}; reason: ${reason.name}',
            );
            if (!mounted) return;
            if (state == ConnectionStateType.connectionStateConnected) {
              _connectionTimer?.cancel();
              setState(() => _connecting = false);
            } else if (state == ConnectionStateType.connectionStateFailed ||
                reason ==
                    ConnectionChangedReasonType.connectionChangedInvalidAppId ||
                reason ==
                    ConnectionChangedReasonType.connectionChangedInvalidToken ||
                reason ==
                    ConnectionChangedReasonType.connectionChangedJoinFailed) {
              _connectionTimer?.cancel();
              setState(() {
                _connecting = false;
                _error = _connectionFailure(reason);
              });
            }
          },
          onError: (errorCode, message) {
            debugPrint('Agora RTC error ${errorCode.name}: $message');
            if (!mounted || !_connecting) return;
            _connectionTimer?.cancel();
            setState(() {
              _connecting = false;
              _error = 'Agora error ${errorCode.name}: $message';
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() {
              _connectedToOther = true;
              _remoteUid = remoteUid;
            });
            _startDuration();
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (_connectedToOther) {
              _remoteUid = null;
              unawaited(_finish());
            }
          },
          onTokenPrivilegeWillExpire: (connection, token) {
            unawaited(_renewAgoraToken());
          },
        ),
      );

      stage = 'joining the Agora audio channel';
      await engine.joinChannel(
        token: access['token'] as String,
        channelId: access['channel_name'] as String,
        uid: 0,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: false,
          publishCameraTrack: false,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      _connectionTimer?.cancel();
      _connectionTimer = Timer(const Duration(seconds: 30), () {
        if (!mounted || !_connecting || _error != null) return;
        setState(() {
          _connecting = false;
          _error =
              'Agora did not connect after 30 seconds. Check the Agora App ID and matching App Certificate in Supabase, then try again on a different network.';
        });
      });
    } catch (error) {
      var errorDetails = error.toString();
      if (error is AgoraRtcException && engine != null) {
        try {
          errorDetails += ': ${await engine.getErrorDescription(error.code)}';
        } catch (_) {
          // Keep the original SDK error if its description cannot be retrieved.
        }
      }
      if (engine != null) {
        _engine = null;
        unawaited(_releaseEngine(engine));
      }
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'Call failed while $stage: $errorDetails';
      });
      debugPrint(
        'Agora voice call connection failed while $stage: $errorDetails',
      );
    }
  }

  bool get _isVideo => false;

  Future<void> _toggleCamera() async {
    final engine = _engine;
    if (!_isVideo || engine == null) return;
    final next = !_cameraOff;
    await engine.muteLocalVideoStream(next);
    if (mounted) setState(() => _cameraOff = next);
  }

  Future<void> _switchCamera() async {
    final engine = _engine;
    if (engine == null || !_isVideo) return;
    await engine.switchCamera();
    if (mounted) setState(() => _frontCamera = !_frontCamera);
  }

  Future<void> _setSpeakerRoute(RtcEngine engine) async {
    try {
      if (identical(engine, _engine)) {
        await engine.setEnableSpeakerphone(_speaker);
      }
    } catch (error) {
      debugPrint('Could not set Agora speaker route: $error');
    }
  }

  String _connectionFailure(ConnectionChangedReasonType reason) {
    switch (reason) {
      case ConnectionChangedReasonType.connectionChangedInvalidAppId:
        return 'Agora rejected the App ID. Check AGORA_APP_ID in Supabase.';
      case ConnectionChangedReasonType.connectionChangedInvalidToken:
        return 'Agora rejected the token. Check that AGORA_APP_CERTIFICATE matches this App ID.';
      case ConnectionChangedReasonType.connectionChangedJoinFailed:
        return 'Agora could not join the audio channel. Check the Agora project settings and network.';
      default:
        return 'Agora connection failed (${reason.name}). Check the internet connection and Agora project settings.';
    }
  }

  Future<void> _renewAgoraToken() async {
    final engine = _engine;
    if (engine == null || _ending) return;
    try {
      final access = await _getAgoraAccess();
      if (!_ending && identical(engine, _engine)) {
        await engine.renewToken(access['token'] as String);
      }
    } catch (error) {
      debugPrint('Could not renew Agora call token: $error');
    }
  }

  void _watchCallStatus() {
    _callChannel = Supabase.instance.client
        .channel('call-status:${widget.call['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.call['id'],
          ),
          callback: (payload) {
            final status = payload.newRecord['status'];
            if (status == 'ended' || status == 'declined') {
              unawaited(_finish(remoteEnded: true));
            }
          },
        )
        .subscribe();
  }

  void _startDuration() {
    if (_durationTimer != null) return;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _toggleMute() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_muted;
    await engine.muteLocalAudioStream(next);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _toggleSpeaker() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_speaker;
    await engine.setEnableSpeakerphone(next);
    if (mounted) setState(() => _speaker = next);
  }

  Future<void> _finish({bool remoteEnded = false}) async {
    if (_ending) return;
    _ending = true;
    _durationTimer?.cancel();
    _connectionTimer?.cancel();
    final engine = _engine;
    _engine = null;
    if (engine != null) unawaited(_releaseEngine(engine));
    final callChannel = _callChannel;
    _callChannel = null;
    if (callChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(callChannel));
    }
    if (mounted) Navigator.of(context).pop();
    if (!remoteEnded) unawaited(_markCallEnded());
  }

  Future<void> _releaseEngine(RtcEngine engine) async {
    try {
      await engine.leaveChannel();
    } catch (error) {
      debugPrint('Could not leave Agora channel cleanly: $error');
    }
    try {
      await engine.release();
    } catch (error) {
      debugPrint('Could not release Agora audio service: $error');
    }
  }

  Future<void> _markCallEnded() async {
    try {
      await _calls
          .setStatus('${widget.call['id']}', 'ended')
          .timeout(const Duration(seconds: 5));
      await _calls.recordCallEvent(
        call: widget.call,
        kind: _connectedToOther ? 'completed' : 'missed',
        durationSeconds: _duration.inSeconds,
      );
    } catch (error) {
      debugPrint('Could not save call history after hang up: $error');
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _connectionTimer?.cancel();
    final engine = _engine;
    if (engine != null) unawaited(_releaseEngine(engine));
    final callChannel = _callChannel;
    if (callChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(callChannel));
    }
    super.dispose();
  }

  String get _time {
    final mm = _duration.inMinutes.toString().padLeft(2, '0');
    final ss = (_duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status =
        _error ??
        (_connecting
            ? 'Connecting…'
            : _connectedToOther
            ? _time
            : widget.isCaller
            ? 'Calling…'
            : 'Joining call…');
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.surface, colors.surfaceContainerHighest],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      Icon(
                        _isVideo ? Icons.videocam : Icons.call,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        _isVideo ? 'VIDEO CALL' : 'VOICE CALL',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isVideo && _cameraEnabled && _error == null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_connectedToOther && _engine != null)
                              AgoraVideoView(
                                controller: VideoViewController.remote(
                                  rtcEngine: _engine!,
                                  canvas: VideoCanvas(uid: _remoteUid),
                                  connection: RtcConnection(
                                    channelId: '${widget.call['room_name']}',
                                  ),
                                ),
                              )
                            else
                              Center(
                                child: Text(
                                  _connecting
                                      ? 'Connecting video…'
                                      : 'Waiting for ${widget.otherName}…',
                                ),
                              ),
                            Positioned(
                              right: 16,
                              top: 16,
                              width: 112,
                              height: 160,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: _cameraOff
                                    ? const ColoredBox(
                                        color: Colors.black54,
                                        child: Icon(
                                          Icons.videocam_off,
                                          color: Colors.white,
                                        ),
                                      )
                                    : AgoraVideoView(
                                        controller: VideoViewController(
                                          rtcEngine: _engine!,
                                          canvas: const VideoCanvas(uid: 0),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 20,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isVideo) ...[
                                  _CallControl(
                                    icon: _cameraOff
                                        ? Icons.videocam_off
                                        : Icons.videocam,
                                    label: _cameraOff
                                        ? 'Camera on'
                                        : 'Camera off',
                                    onTap: _toggleCamera,
                                    selected: _cameraOff,
                                  ),
                                  const SizedBox(width: 18),
                                  _CallControl(
                                    icon: Icons.flip_camera_ios,
                                    label: 'Flip',
                                    onTap: _switchCamera,
                                    selected: !_frontCamera,
                                  ),
                                  const SizedBox(width: 18),
                                ],
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.primary.withValues(
                                        alpha: _connectedToOther ? 0.65 : 0.25,
                                      ),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.primary.withValues(
                                          alpha: 0.10,
                                        ),
                                        blurRadius: 34,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 68,
                                    backgroundColor: colors.secondaryContainer,
                                    foregroundColor:
                                        colors.onSecondaryContainer,
                                    child: Text(
                                      widget.otherName.isEmpty
                                          ? '?'
                                          : widget.otherName
                                                .trim()[0]
                                                .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 44,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  widget.otherName,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 13),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surface.withValues(
                                      alpha: 0.72,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_error == null &&
                                          !_connectedToOther) ...[
                                        SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 9),
                                      ] else if (_error == null) ...[
                                        Icon(
                                          Icons.graphic_eq,
                                          size: 17,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 7),
                                      ],
                                      Text(
                                        _error == null
                                            ? status
                                            : 'Call could not connect',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: _error == null
                                                  ? colors.onSurfaceVariant
                                                  : colors.error,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 18),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: colors.errorContainer.withValues(
                                        alpha: 0.55,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onErrorContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.62),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CallControl(
                            icon: _muted ? Icons.mic_off : Icons.mic,
                            label: _muted ? 'Unmute' : 'Mute',
                            onTap: _toggleMute,
                            selected: _muted,
                          ),
                          const SizedBox(width: 28),
                          _CallControl(
                            icon: _speaker ? Icons.volume_up : Icons.hearing,
                            label: _speaker ? 'Speaker' : 'Earpiece',
                            onTap: _toggleSpeaker,
                            selected: _speaker,
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: IconButton.filled(
                          tooltip: 'End call',
                          onPressed: _ending ? null : () => _finish(),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE84B4B),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.call_end, size: 32),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'End call',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 78,
    child: Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon),
          iconSize: 25,
          style: IconButton.styleFrom(
            fixedSize: const Size(62, 62),
            backgroundColor: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: selected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}
