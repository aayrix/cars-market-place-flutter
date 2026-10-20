import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../services/group_chat_service.dart';
import '../services/voice_note_service.dart';
import '../services/location_service.dart';
import '../utils/ag_design.dart';
import '../utils/error_messages.dart';
import '../widgets/chat_location_bubble.dart';
import '../widgets/voice_note_widgets.dart';
import 'location_picker_screen.dart';
import 'location_view_screen.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });
  final String groupId;
  final String groupName;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _service = GroupChatService();
  late final Future<List<UserProfile>> _members = _service.members(
    widget.groupId,
  );
  final _message = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  int _lastCount = 0;

  // Live location sharing state.
  StreamSubscription<Position>? _liveLocationSub;
  Timer? _liveExpiryTimer;
  String? _liveMessageId;
  DateTime? _liveExpiresAt;

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    _stopLiveLocation();
    super.dispose();
  }

  void _stopLiveLocation() {
    _liveLocationSub?.cancel();
    _liveLocationSub = null;
    _liveExpiryTimer?.cancel();
    _liveExpiryTimer = null;
    _liveMessageId = null;
    _liveExpiresAt = null;
  }

  Future<void> _send() async {
    if (_sending || _message.text.trim().isEmpty) return;
    final text = _message.text;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        groupId: widget.groupId,
        text: text,
        senderName: context.read<AuthProvider>().safeProfile.displayName,
      );
      _message.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.from(
                error,
                fallback: 'Could not send your message. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendVoiceNote(Uint8List bytes, Duration duration) async {
    if (_sending) return;
    final senderName = context.read<AuthProvider>().safeProfile.displayName;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final path = await VoiceNoteService().upload(
        wavBytes: bytes,
        conversationType: 'groups',
        conversationId: widget.groupId,
      );
      await _service.sendMessage(
        groupId: widget.groupId,
        text: '🎙️ VOICE NOTE\n$path\n${duration.inMilliseconds}',
        senderName: senderName,
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.from(
                error,
                fallback: 'Could not send this voice note. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const LocationPickerScreen(),
      ),
    );
    if (!mounted || result == null) return;

    final latitude = result['latitude'] as double;
    final longitude = result['longitude'] as double;
    final title = '${result['title'] ?? 'Shared location'}';
    final isLive = result['isLive'] == true;
    final durationMinutes = result['durationMinutes'] as int?;
    final expiresAt = isLive && durationMinutes != null
        ? DateTime.now().toUtc().add(Duration(minutes: durationMinutes))
        : null;

    setState(() => _sending = true);
    try {
      final messageId = await _service.sendMessage(
        groupId: widget.groupId,
        text: title,
        senderName: context.read<AuthProvider>().safeProfile.displayName,
        latitude: latitude,
        longitude: longitude,
        locationTitle: title,
        locationExpiresAt: expiresAt,
      );
      if (isLive && messageId.isNotEmpty) {
        _startLiveLocation(messageId, durationMinutes);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.from(
                error,
                fallback: 'Location could not be shared. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startLiveLocation(String messageId, int? durationMinutes) {
    _stopLiveLocation();
    _liveMessageId = messageId;
    _liveExpiresAt = durationMinutes == null
        ? null
        : DateTime.now().toUtc().add(Duration(minutes: durationMinutes));

    _liveLocationSub = LocationService.instance.positionStream().listen(
      (position) {
        if (!mounted || _liveMessageId == null) return;
        _service.updateMessageLocation(
          groupId: widget.groupId,
          messageId: _liveMessageId!,
          latitude: position.latitude,
          longitude: position.longitude,
          expiresAt:
              _liveExpiresAt ??
              DateTime.now().toUtc().add(const Duration(days: 365)),
        );
      },
      onError: (error) {
        debugLog('Live location update failed: $error');
      },
    );

    if (durationMinutes != null) {
      _liveExpiryTimer = Timer(
        Duration(minutes: durationMinutes),
        () => setState(() => _stopLiveLocation()),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _showChatActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Share location'),
              subtitle: const Text(
                'Send your current or live location to the group',
              ),
              onTap: () => Navigator.pop(context, 'location'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'location') {
      await _shareLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().userId;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.groups_outlined,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  FutureBuilder(
                    future: _members,
                    builder: (context, snapshot) => Text(
                      '${snapshot.data?.length ?? ''} members',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.watchMessages(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Group messages could not load: ${snapshot.error}',
                    ),
                  );
                }
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const Center(child: Text('Say hello to your group.'));
                }
                if (rows.length != _lastCount) {
                  _lastCount = rows.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scroll.hasClients) {
                      _scroll.animateTo(
                        _scroll.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final mine = '${row['sender_id']}' == me;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .78,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          decoration: BoxDecoration(
                            color: mine
                                ? AGDesign.chatSentBubble
                                : AGDesign.chatReceivedBubble,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(mine ? 16 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Text(
                                  '${row['sender_name'] ?? 'Member'}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              if (row['latitude'] != null &&
                                  row['longitude'] != null)
                                ChatLocationBubble(
                                  latitude: row['latitude'] as double,
                                  longitude: row['longitude'] as double,
                                  title: '${row['location_title'] ?? ''}',
                                  mine: mine,
                                  expiresAt: row['location_expires_at'] == null
                                      ? null
                                      : DateTime.tryParse(
                                          '${row['location_expires_at']}',
                                        ),
                                  updatedAt: row['location_updated_at'] == null
                                      ? null
                                      : DateTime.tryParse(
                                          '${row['location_updated_at']}',
                                        ),
                                  onTap: () => Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => LocationViewScreen(
                                        latitude: row['latitude'] as double,
                                        longitude: row['longitude'] as double,
                                        title: '${row['location_title'] ?? ''}',
                                        senderName:
                                            '${row['sender_name'] ?? ''}',
                                      ),
                                    ),
                                  ),
                                )
                              else
                                _GroupMessageBody(
                                  text: '${row['body'] ?? ''}',
                                  mine: mine,
                                ),
                              if (row['latitude'] == null ||
                                  row['longitude'] == null)
                                const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _time('${row['sent_at'] ?? ''}'),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: mine
                                            ? Colors.white70
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_liveMessageId != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sharing live location',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (_liveExpiresAt != null)
                          Text(
                            'Expires ${_expiryTime(_liveExpiresAt!)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _sending
                        ? null
                        : () {
                            _stopLiveLocation();
                            setState(() {});
                          },
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ),
          ],
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sending ? null : _showChatActions,
                    tooltip: 'More chat actions',
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  VoiceNoteRecorderButton(
                    disabled: _sending,
                    onRecorded: _sendVoiceNote,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message group',
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _time(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _expiryTime(DateTime expiresAt) {
    final date = expiresAt.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} '
        '${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _GroupMessageBody extends StatelessWidget {
  const _GroupMessageBody({required this.text, required this.mine});
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    if (text.startsWith('🎙️ VOICE NOTE\n')) {
      final fields = text.split('\n');
      if (fields.length >= 3) {
        return VoiceNotePlayer(
          path: fields[1],
          duration: Duration(milliseconds: int.tryParse(fields[2]) ?? 0),
          mine: mine,
        );
      }
    }
    return Text(
      text,
      style: TextStyle(
        color: mine ? Colors.white : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
