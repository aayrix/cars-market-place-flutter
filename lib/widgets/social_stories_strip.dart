import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/social_service.dart';
import '../utils/error_messages.dart';
import '../utils/pick_photo.dart';

class SocialStoriesStrip extends StatelessWidget {
  const SocialStoriesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().userId ?? '';
    final social = SocialService();
    return SizedBox(
      height: 112,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: social.watchStories(),
        builder: (context, snapshot) {
          final stories = snapshot.data ?? const <Map<String, dynamic>>[];
          final grouped = <String, Map<String, dynamic>>{};
          for (final story in stories) {
            grouped.putIfAbsent('${story['user_id']}', () => story);
          }
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            children: [
              _StoryCircle(
                label: 'Your status',
                imageUrl: '${grouped[userId]?['media_url'] ?? ''}',
                add: true,
                onTap: userId.isEmpty
                    ? null
                    : grouped[userId] == null
                    ? () => _createStory(context, social)
                    : () => _showStory(context, grouped[userId]!),
                onAdd: userId.isEmpty
                    ? null
                    : () => _createStory(context, social),
              ),
              ...grouped.values
                  .where((story) => '${story['user_id']}' != userId)
                  .map(
                    (story) => _StoryCircle(
                      label: '${story['caption'] ?? ''}'.trim().isEmpty
                          ? 'Status'
                          : '${story['caption']}',
                      imageUrl: '${story['media_url']}',
                      onTap: () => _showStory(context, story),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createStory(BuildContext context, SocialService social) async {
    try {
      final file = await pickPhoto(context);
      if (file == null || !context.mounted) return;
      final preview = await file.readAsBytes();
      if (!context.mounted) return;
      final caption = TextEditingController();
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add to your status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(preview, height: 170, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caption,
                maxLength: 120,
                decoration: const InputDecoration(hintText: 'Add a caption'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Post'),
            ),
          ],
        ),
      );
      // Re-open bytes asynchronously for the actual upload; previews are kept
      // deliberately simple to avoid retaining camera-sized images in memory.
      if (accepted == true && context.mounted) {
        await social.postStory(file, caption: caption.text);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status posted for 24 hours.')),
          );
        }
      }
      caption.dispose();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.from(
                error,
                fallback: 'Could not post your status. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  void _showStory(BuildContext context, Map<String, dynamic> story) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network('${story['media_url']}', fit: BoxFit.contain),
            Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: Text(
                '${story['caption'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 28,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.label,
    required this.imageUrl,
    this.add = false,
    this.onTap,
    this.onAdd,
  });
  final String label;
  final String imageUrl;
  final bool add;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: add && imageUrl.isEmpty
                        ? Theme.of(context).colorScheme.outlineVariant
                        : Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: imageUrl.isEmpty
                      ? null
                      : NetworkImage(imageUrl),
                  child: imageUrl.isEmpty
                      ? Icon(add ? Icons.add : Icons.person_outline)
                      : null,
                ),
              ),
              if (add)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 21,
                      height: 21,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
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
