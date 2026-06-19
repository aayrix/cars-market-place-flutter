import 'package:flutter/material.dart';

import 'create_listing_screen.dart';

/// Entry point for sellers: explains flow and opens the form.
class SellTab extends StatelessWidget {
  const SellTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Post a car',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your advert is saved on this device.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        _Bullet(
          icon: Icons.phone_android_outlined,
          text: 'Listings are local to this device.',
        ),
        _Bullet(icon: Icons.edit_note_outlined, text: 'Enter vehicle and document details.'),
        _Bullet(icon: Icons.photo_camera_outlined, text: 'Add photos of the car and documents if you wish.'),
        _Bullet(icon: Icons.category_outlined, text: 'Pick Sedan, SUV, or Hatchback — your ad appears in that section.'),
        _Bullet(icon: Icons.place_outlined, text: 'Choose your area from the Mianwali list (no map search).'),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CreateListingScreen(),
              ),
            );
          },
          icon: const Icon(Icons.post_add),
          label: const Text('Start new listing'),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
