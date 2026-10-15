import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/group_chat_service.dart';
import '../utils/error_messages.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _service = GroupChatService();
  final _selected = <String>{};
  late final Future<List<UserProfile>> _connections = _service
      .fetchConnections();
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 2 || _selected.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final id = await _service.createGroup(
        name: _name.text,
        memberIds: _selected.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              GroupChatScreen(groupId: id, groupName: _name.text.trim()),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.from(
                error,
                fallback: 'Could not create the group. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New group')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _name,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Group name',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Choose connections',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_selected.length} selected',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<UserProfile>>(
            future: _connections,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load your connections: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data!;
              if (users.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'You need at least one accepted connection to create a group.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: users.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 68),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final checked = _selected.contains(user.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(user.id);
                      } else {
                        _selected.remove(user.id);
                      }
                    }),
                    secondary: CircleAvatar(
                      backgroundImage: user.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(user.avatarUrl),
                      child: user.avatarUrl.isEmpty
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    title: Text(user.displayName),
                    subtitle: user.city.isEmpty ? null : Text(user.city),
                    controlAffinity: ListTileControlAffinity.trailing,
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add_outlined),
                label: Text(_creating ? 'Creating…' : 'Create group'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
