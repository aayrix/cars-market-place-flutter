import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/chat_call_service.dart';
import '../services/voice_note_service.dart';
import '../services/location_service.dart';
import '../utils/ag_design.dart';
import '../utils/number_formatters.dart';
import '../widgets/chat_location_bubble.dart';
import '../widgets/voice_note_widgets.dart';
import '../utils/error_messages.dart';
import 'location_picker_screen.dart';
import 'location_view_screen.dart';
import 'public_profile_screen.dart';
import 'voice_call_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.listingId,
    required this.listingTitle,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
  });

  final String listingId;
  final String listingTitle;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _message = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ChatService _chat = ChatService();
  bool _sending = false;
  bool _threadReady = false;
  bool _markReadQueued = false;
  int _seenMessages = 0;
  final ChatCallService _calls = ChatCallService();
  String? _activeCallId;

  // Live location sharing state.
  StreamSubscription<Position>? _liveLocationSub;
  Timer? _liveExpiryTimer;
  String? _liveMessageId;
  DateTime? _liveExpiresAt;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    _stopLiveLocation();
    super.dispose();
  }

  String get _threadId => _chat.threadIdFor(
    listingId: widget.listingId,
    buyerId: widget.buyerId,
    sellerId: widget.sellerId,
  );

  Future<void> _startVoiceCall() async {
    if (_activeCallId != null) return;
    final userId = context.read<AuthProvider>().userId ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to make a call.')));
      return;
    }
    final isBuyer = userId == widget.buyerId;
    final otherUserId = isBuyer ? widget.sellerId : widget.buyerId;
    final otherName = isBuyer ? widget.sellerName : widget.buyerName;
    try {
      await _chat.ensureThread(
        listingId: widget.listingId,
        listingTitle: widget.listingTitle,
        buyerId: widget.buyerId,
        buyerName: widget.buyerName,
        sellerId: widget.sellerId,
        sellerName: widget.sellerName,
      );
      final call = await _calls.startCall(
        threadId: _threadId,
        callerId: userId,
        calleeId: otherUserId,
        callType: 'voice',
      );
      _activeCallId = '${call['id']}';
      await _openCall(call, isCaller: true, otherName: otherName);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start the call: $error')),
        );
      }
    } finally {
      _activeCallId = null;
    }
  }

  Future<void> _openCall(
    Map<String, dynamic> call, {
    required bool isCaller,
    required String otherName,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VoiceCallScreen(
          call: call,
          otherName: otherName,
          isCaller: isCaller,
        ),
      ),
    );
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
    await _deliver(_message.text, clearComposer: true);
  }

  Future<void> _sendVoiceNote(Uint8List bytes, Duration duration) async {
    if (_sending) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      if (!_threadReady) {
        await _chat.ensureThread(
          listingId: widget.listingId,
          listingTitle: widget.listingTitle,
          buyerId: widget.buyerId,
          buyerName: widget.buyerName,
          sellerId: widget.sellerId,
          sellerName: widget.sellerName,
        );
        _threadReady = true;
      }
      final path = await VoiceNoteService().upload(
        wavBytes: bytes,
        conversationType: 'threads',
        conversationId: _chat.threadIdFor(
          listingId: widget.listingId,
          buyerId: widget.buyerId,
          sellerId: widget.sellerId,
        ),
      );
      await _chat.sendMessage(
        listingId: widget.listingId,
        listingTitle: widget.listingTitle,
        buyerId: widget.buyerId,
        buyerName: widget.buyerName,
        sellerId: widget.sellerId,
        sellerName: widget.sellerName,
        senderId: auth.userId ?? '',
        senderName: auth.safeProfile.displayName,
        text: '🎙️ VOICE NOTE\n$path\n${duration.inMilliseconds}',
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

  Future<void> _deliver(String text, {bool clearComposer = false}) async {
    if (_sending) return;
    if (text.trim().isEmpty) return;
    final senderId = context.read<AuthProvider>().userId ?? '';
    setState(() => _sending = true);
    try {
      await _chat.sendMessage(
        listingId: widget.listingId,
        listingTitle: widget.listingTitle,
        buyerId: widget.buyerId,
        buyerName: widget.buyerName,
        sellerId: widget.sellerId,
        sellerName: widget.sellerName,
        senderId: senderId,
        senderName: context.read<AuthProvider>().safeProfile.displayName,
        text: text,
      );
      _threadReady = true;
      if (clearComposer) _message.clear();
    } catch (e) {
      if (mounted) {
        final signedIn = context.read<AuthProvider>().isSignedIn;
        final String message;
        if (!signedIn) {
          message = 'Sign in to send messages.';
        } else {
          message = ErrorMessages.from(
            e,
            fallback: 'Message could not be sent. Please try again.',
          );
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
              leading: const Icon(Icons.local_offer_outlined),
              title: const Text('Make a price offer'),
              subtitle: const Text('Send an offer to this person'),
              onTap: () => Navigator.pop(context, 'offer'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('Share vehicle details'),
              subtitle: Text(
                widget.listingTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(context, 'listing'),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Share location'),
              subtitle: const Text('Send your current or live location'),
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
    } else if (action == 'listing') {
      await _deliver(
        '🚗 VEHICLE DETAILS\nListing: ${widget.listingTitle}\nListing ID: ${widget.listingId}',
      );
    } else if (action == 'offer') {
      await _makePriceOffer();
    }
  }

  Future<void> _makePriceOffer() async {
    final amount = TextEditingController();
    final amountFocus = FocusNode();
    amountFocus.addListener(() {
      if (amountFocus.hasFocus) {
        amount.selection = TextSelection(
          baseOffset: 0,
          extentOffset: amount.text.length,
        );
      }
    });
    final note = TextEditingController();
    var paymentPlan = 'Cash';
    final offer = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Make a price offer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                focusNode: amountFocus,
                keyboardType: TextInputType.number,
                inputFormatters: const [CommaSeparatedNumberInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Offer amount (PKR)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentPlan,
                decoration: const InputDecoration(labelText: 'Payment plan'),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(
                    value: 'Bank transfer',
                    child: Text('Bank transfer'),
                  ),
                  DropdownMenuItem(
                    value: 'Installments',
                    child: Text('Installments'),
                  ),
                ],
                onChanged: (value) =>
                    refresh(() => paymentPlan = value ?? 'Cash'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (amount.text.trim().isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  '💰 PRICE OFFER\nOffer: PKR ${amount.text.trim()}\nPayment plan: $paymentPlan\nNote: ${note.text.trim()}',
                );
              },
              child: const Text('Send offer'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    amountFocus.dispose();
    note.dispose();
    if (offer != null && mounted) await _deliver(offer);
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
      final messageId = await _chat.sendMessage(
        listingId: widget.listingId,
        listingTitle: widget.listingTitle,
        buyerId: widget.buyerId,
        buyerName: widget.buyerName,
        sellerId: widget.sellerId,
        sellerName: widget.sellerName,
        senderId: context.read<AuthProvider>().userId ?? '',
        senderName: context.read<AuthProvider>().safeProfile.displayName,
        text: title,
        latitude: latitude,
        longitude: longitude,
        locationTitle: title,
        locationExpiresAt: expiresAt,
      );
      _threadReady = true;

      if (isLive && messageId.isNotEmpty) {
        _startLiveLocation(messageId, durationMinutes);
      }
    } catch (e) {
      if (mounted) {
        final signedIn = context.read<AuthProvider>().isSignedIn;
        final String message;
        if (!signedIn) {
          message = 'Sign in to send messages.';
        } else {
          message = ErrorMessages.from(
            e,
            fallback: 'Location could not be shared. Please try again.',
          );
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
        _chat.updateMessageLocation(
          threadId: _chat.threadIdFor(
            listingId: widget.listingId,
            buyerId: widget.buyerId,
            sellerId: widget.sellerId,
          ),
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

  void _markIncomingMessagesRead(String userId) {
    if (_markReadQueued) return;
    _markReadQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final updatedCount = await _chat.markThreadRead(
          threadId: _chat.threadIdFor(
            listingId: widget.listingId,
            buyerId: widget.buyerId,
            sellerId: widget.sellerId,
          ),
          userId: userId,
        );
        debugLog('Marked $updatedCount incoming chat messages as read.');
      } catch (error) {
        debugLog('Could not mark chat messages as read: $error');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(ErrorMessages.from(error))));
        }
      } finally {
        _markReadQueued = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().userId ?? '';
    final isBuyer = uid == widget.buyerId;
    final otherName = isBuyer ? widget.sellerName : widget.buyerName;
    final threadId = _chat.threadIdFor(
      listingId: widget.listingId,
      buyerId: widget.buyerId,
      sellerId: widget.sellerId,
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Text(otherName.isEmpty ? '?' : otherName[0].toUpperCase()),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Apni Gari member',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Voice call',
              onPressed: _activeCallId == null ? _startVoiceCall : null,
              icon: const Icon(Icons.call_outlined),
            ),
            IconButton(
              tooltip: 'View profile',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(
                    userId: isBuyer ? widget.sellerId : widget.buyerId,
                  ),
                ),
              ),
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                Icon(
                  Icons.directions_car_filled_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle enquiry',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        widget.listingTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chat.watchMessages(threadId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        ErrorMessages.from(
                          snap.error!,
                          fallback: 'Chat could not load. Please try again.',
                        ),
                      ),
                    ),
                  );
                }
                final items = snap.data ?? const <Map<String, dynamic>>[];
                if (items.any(
                  (message) =>
                      message['senderId'] != uid && message['readAt'] == null,
                )) {
                  _markIncomingMessagesRead(uid);
                }
                if (items.isEmpty) {
                  return const Center(child: Text('Start conversation here.'));
                }
                if (items.length != _seenMessages) {
                  _seenMessages = items.length;
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
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final mine = m['senderId'] == uid;
                    final text = '${m['text'] ?? ''}';
                    if (text.startsWith('[[CALL_EVENT:')) {
                      final parts = text
                          .substring(13)
                          .replaceAll(']]', '')
                          .split(':');
                      final kind = parts.length > 1 ? parts[1] : 'missed';
                      final seconds = parts.length > 2
                          ? int.tryParse(parts[2]) ?? 0
                          : 0;
                      return _CallHistoryTile(
                        kind: kind,
                        seconds: seconds,
                        time: _messageTime('${m['sentAt'] ?? ''}'),
                      );
                    }
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
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
                              if (m['latitude'] != null &&
                                  m['longitude'] != null)
                                ChatLocationBubble(
                                  latitude: m['latitude'] as double,
                                  longitude: m['longitude'] as double,
                                  title: '${m['locationTitle'] ?? ''}',
                                  mine: mine,
                                  expiresAt: m['locationExpiresAt'],
                                  updatedAt: m['locationUpdatedAt'],
                                  onTap: () => Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => LocationViewScreen(
                                        latitude: m['latitude'] as double,
                                        longitude: m['longitude'] as double,
                                        title: '${m['locationTitle'] ?? ''}',
                                        senderName: '${m['senderName'] ?? ''}',
                                      ),
                                    ),
                                  ),
                                )
                              else
                                DefaultTextStyle.merge(
                                  style: TextStyle(
                                    color: mine
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                  child: _ChatMessageBody(
                                    text: '${m['text'] ?? ''}',
                                    mine: mine,
                                  ),
                                ),
                              if (m['latitude'] == null ||
                                  m['longitude'] == null)
                                const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _messageTime('${m['sentAt'] ?? ''}'),
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
          Padding(
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
                    decoration: InputDecoration(
                      hintText: 'Message',
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
        ],
      ),
    );
  }

  String _expiryTime(DateTime expiresAt) {
    final date = expiresAt.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} '
        '${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _messageTime(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _CallHistoryTile extends StatelessWidget {
  const _CallHistoryTile({
    required this.kind,
    required this.seconds,
    required this.time,
  });

  final String kind;
  final int seconds;
  final String time;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = kind == 'completed';
    final title = completed
        ? 'Voice call · ${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}'
        : kind == 'declined'
        ? 'Declined voice call'
        : 'Missed voice call';
    final accent = completed ? colors.primary : colors.error;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              completed ? Icons.call : Icons.call_missed,
              color: accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            if (time.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                time,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatMessageBody extends StatelessWidget {
  const _ChatMessageBody({required this.text, required this.mine});

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
    if (!text.startsWith('💰 PRICE OFFER\n')) return Text(text);
    final fields = <String, String>{};
    for (final line in text.split('\n').skip(1)) {
      final separator = line.indexOf(':');
      if (separator > 0) {
        fields[line.substring(0, separator)] = line
            .substring(separator + 1)
            .trim();
      }
    }
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRICE OFFER',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fields['Offer'] ?? '',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Payment: ${fields['Payment plan'] ?? ''}'),
          if (fields['Note']?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text('Note: ${fields['Note']}'),
          ],
        ],
      ),
    );
  }
}
