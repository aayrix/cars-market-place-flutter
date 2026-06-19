import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/listings_provider.dart';
import '../widgets/listing_card.dart';
import 'create_listing_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});
  static const String _localUserId = 'local-user';

  @override
  Widget build(BuildContext context) {
    const uid = _localUserId;
    final listings = context.watch<ListingsProvider>().listings;
    final mine = listings.where((l) => l.sellerId == uid).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      body: mine.isEmpty
          ? const Center(child: Text('You have no active listings.'))
          : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) {
                    final l = mine[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListingCard(listing: l),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => CreateListingScreen(
                                          editing: l,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _confirmDelete(
                                    context,
                                    l.id,
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: mine.length,
                ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete listing?'),
          content: const Text(
            'This removes the advertisement and its photos permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (ok != true || !context.mounted) return;
    final err = await context.read<ListingsProvider>().deleteListing(id);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}
