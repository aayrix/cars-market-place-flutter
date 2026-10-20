import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/group_chat_service.dart';
import '../services/profile_service.dart';
import '../utils/error_messages.dart';
import '../widgets/social_stories_strip.dart';
import 'bot_chat_screen.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final _search = TextEditingController();
  int _filter = 0;
  String? _profileIdsKey;
  Future<Map<String, UserProfile>>? _profilesFuture;

  void _loadParticipantProfiles(Set<String> ids) {
    final sortedIds = ids.toList()..sort();
    final key = sortedIds.join('|');
    if (key == _profileIdsKey) return;
    _profileIdsKey = key;
    _profilesFuture = sortedIds.isEmpty
        ? Future.value(const <String, UserProfile>{})
        : ProfileService().fetchForUsers(sortedIds);
  }

  Future<void> _deleteChat({
    required Map<String, dynamic> thread,
    required String userId,
    required String otherName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: Text('This removes your conversation with $otherName from your inbox.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ChatService().hideThreadForUser(
        threadId: '${thread['id'] ?? ''}',
        userId: userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted from your inbox.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.from(error, fallback: 'Could not delete this chat.'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().userId ?? '';
    final chat = ChatService();
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: chat.watchThreadsForUser(uid),
      builder: (context, snap) {
        final threads = snap.data ?? const <Map<String, dynamic>>[];
        final participantIds = <String>{};
        for (final thread in threads) {
          final sellerId = '${thread['sellerId'] ?? ''}';
          final buyerId = '${thread['buyerId'] ?? ''}';
          participantIds.add(uid == sellerId ? buyerId : sellerId);
        }
        participantIds.remove('');
        _loadParticipantProfiles(participantIds);
        final query = _search.text.trim().toLowerCase();
        final byPerson = <String, Map<String, dynamic>>{};
        for (final thread in threads) {
          final otherId = uid == '${thread['sellerId']}'
              ? '${thread['buyerId']}'
              : '${thread['sellerId']}';
          // The newest listing enquiry represents this person's conversation
          // in the inbox, so multiple vehicle threads do not duplicate rows.
          byPerson.putIfAbsent(otherId, () => thread);
        }
        final visible = byPerson.values.where((t) {
          final otherId = uid == '${t['sellerId']}'
              ? '${t['buyerId']}'
              : '${t['sellerId']}';
          final name = uid == '${t['sellerId']}'
              ? '${t['buyerName']}'
              : '${t['sellerName']}';
          final matches = '$name ${t['listingTitle']} ${t['lastMessage']}'
              .toLowerCase()
              .contains(query);
          final isBuying = uid == '${t['buyerId']}';
          final matchesRole =
              _filter == 0 ||
              (_filter == 1 && isBuying) ||
              (_filter == 2 && !isBuying);
          final hiddenAt = uid == '${t['buyerId']}'
              ? t['buyerHiddenAt']
              : t['sellerHiddenAt'];
          return matches && matchesRole && otherId.isNotEmpty && hiddenAt == null;
        }).toList();
        final inboxHasChats = byPerson.values.any((t) {
          final hiddenAt = uid == '${t['buyerId']}'
              ? t['buyerHiddenAt']
              : t['sellerHiddenAt'];
          return hiddenAt == null;
        });

        if (uid.isEmpty) {
          return const Center(child: Text('Sign in to see your chats.'));
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              ErrorMessages.from(
                snap.error!,
                fallback: 'Chats could not load. Please try again.',
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            const SocialStoriesStrip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Messages',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.4,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Your conversations with buyers and sellers',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateGroupScreen(),
                      ),
                    ),
                    tooltip: 'Create group',
                    icon: const Icon(Icons.group_add_outlined),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const BotChatScreen(),
                      ),
                    ),
                    tooltip: 'Ask Assistant',
                    icon: const Icon(Icons.help_outline),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search people or conversations',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: .55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                children: [
                  _ChatFilter(
                    label: 'All',
                    selected: _filter == 0,
                    onTap: () => setState(() => _filter = 0),
                  ),
                  const SizedBox(width: 8),
                  _ChatFilter(
                    label: 'Buying',
                    selected: _filter == 1,
                    onTap: () => setState(() => _filter = 1),
                  ),
                  const SizedBox(width: 8),
                  _ChatFilter(
                    label: 'Selling',
                    selected: _filter == 2,
                    onTap: () => setState(() => _filter = 2),
                  ),
                ],
              ),
            ),
            const _GroupsStrip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Row(
                children: [
                  Text(
                    'RECENT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: .55),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, UserProfile>>(
                future: _profilesFuture,
                builder: (context, profileSnapshot) {
                  final profiles =
                      profileSnapshot.data ?? const <String, UserProfile>{};
                  if (visible.isEmpty) {
                    return _EmptyChats(hasChats: inboxHasChats);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, i) {
                      final t = visible[i];
                      final sellerId = '${t['sellerId'] ?? ''}';
                      final buyerId = '${t['buyerId'] ?? ''}';
                      final sellerName = '${t['sellerName'] ?? 'Seller'}';
                      final buyerName = '${t['buyerName'] ?? 'Buyer'}';
                      final isSeller = uid == sellerId;
                      final otherName = isSeller ? buyerName : sellerName;
                      final otherId = isSeller ? buyerId : sellerId;
                      final avatarUrl = profiles[otherId]?.avatarUrl ?? '';
                      final preview = '${t['lastMessage'] ?? ''}';
                      return Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: .28),
                          ),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 5,
                          ),
                          leading: _ConversationAvatar(
                            name: otherName,
                            imageUrl: avatarUrl,
                            radius: 25,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  otherName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _chatTime('${t['lastMessageAt'] ?? ''}'),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Chat options',
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteChat(thread: t, userId: uid, otherName: otherName);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'delete', child: Row(children: [
                                Icon(Icons.delete_outline, color: Colors.red),
                                SizedBox(width: 10), Text('Delete chat'),
                              ])),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preview.isEmpty
                                      ? 'Start a conversation'
                                      : preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car_outlined,
                                      size: 14,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${t['listingTitle'] ?? 'Vehicle enquiry'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(
                                listingId: '${t['listingId'] ?? ''}',
                                listingTitle:
                                    '${t['listingTitle'] ?? 'Vehicle enquiry'}',
                                buyerId: buyerId,
                                buyerName: buyerName,
                                sellerId: sellerId,
                                sellerName: sellerName,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _chatTime(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _GroupsStrip extends StatelessWidget {
  const _GroupsStrip();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 88,
    child: StreamBuilder<List<Map<String, dynamic>>>(
      stream: GroupChatService().watchGroups(),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <Map<String, dynamic>>[];
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          children: [
            _GroupChip(
              label: 'New group',
              icon: Icons.add,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateGroupScreen(),
                ),
              ),
            ),
            ...groups.map(
              (group) => _GroupChip(
                label: '${group['name'] ?? 'Group'}',
                icon: Icons.groups_outlined,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => GroupChatScreen(
                      groupId: '${group['id']}',
                      groupName: '${group['name'] ?? 'Group'}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(icon),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}

class _ChatFilter extends StatelessWidget {
  const _ChatFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.name,
    required this.imageUrl,
    required this.radius,
  });

  final String name;
  final String imageUrl;
  final double radius;

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget fallback() => ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: colors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.secondaryContainer,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: imageUrl.isEmpty
              ? fallback()
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback(),
                  errorWidget: (_, _, _) => fallback(),
                ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.hasChats});
  final bool hasChats;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 14),
          Text(
            hasChats
                ? 'No conversations match'
                : 'Your conversations live here',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            hasChats
                ? 'Try another name or filter.'
                : 'Message a seller from any vehicle listing to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
