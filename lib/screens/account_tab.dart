import 'package:flutter/material.dart';

import '../data/mianwali_data.dart';
import 'my_listings_screen.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          'Account',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.person_outlined)),
          title: const Text('Mianwali Wheels User'),
          subtitle: const Text('Local session'),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const MyListingsScreen(),
              ),
            );
          },
          icon: const Icon(Icons.list_alt_outlined),
          label: const Text('My listings'),
        ),
        const SizedBox(height: 12),
        Text(
          'Listings stay on this device in local mode '
          '($kCityName, $kCountryHint).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
