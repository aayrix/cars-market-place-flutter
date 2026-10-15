import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'create_listing_screen.dart';
import 'login_screen.dart';

/// Entry point for sellers: explains flow and opens the form.
class SellTab extends StatelessWidget {
  const SellTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    if (!auth.isSignedIn) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Post a vehicle',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to publish a vehicle. Your account becomes the seller, so '
            'buyers can trust the listing.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('Sign in to continue'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Post a vehicle',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Your advert will be published to the Mianwali marketplace.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _Bullet(
          icon: Icons.public_outlined,
          text: 'Your listing is visible to buyers across Mianwali.',
        ),
        _Bullet(
          icon: Icons.edit_note_outlined,
          text: 'Enter vehicle and document details.',
        ),
        _Bullet(
          icon: Icons.photo_camera_outlined,
          text: 'Add photos of the car and documents if you wish.',
        ),
        _Bullet(
          icon: Icons.category_outlined,
          text:
              'List a car or motorcycle with details tailored to that vehicle.',
        ),
        _Bullet(
          icon: Icons.place_outlined,
          text: 'Choose your area from the Mianwali list (no map search).',
        ),
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
