import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/group_chat_service.dart';
import '../utils/error_messages.dart';
import '../widgets/social_stories_strip.dart';
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
          return matches && matchesRole && otherId.isNotEmpty;
        }).toList();

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
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Messages',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
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
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyChats(hasChats: threads.isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 82, endIndent: 16),
                      itemBuilder: (context, i) {
                        final t = visible[i];
                        final sellerId = '${t['sellerId'] ?? ''}';
                        final buyerId = '${t['buyerId'] ?? ''}';
                        final sellerName = '${t['sellerName'] ?? 'Seller'}';
                        final buyerName = '${t['buyerName'] ?? 'Buyer'}';
                        final isSeller = uid == sellerId;
                        final otherName = isSeller ? buyerName : sellerName;
                        final preview = '${t['lastMessage'] ?? ''}';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 5,
                          ),
                          leading: CircleAvatar(
                            radius: 27,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              _initials(otherName),
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
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
            color: Theme.of(context).colorScheme.primary,
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
