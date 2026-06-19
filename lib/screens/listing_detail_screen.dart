import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/mianwali_data.dart';
import '../models/car_category.dart';
import '../providers/listings_provider.dart';
import '../services/contact_service.dart';
import '../utils/listing_image.dart';
import 'chat_screen.dart';
import 'create_listing_screen.dart';

class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;
  static const String _localUserId = 'local-user';

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete listing?'),
          content: const Text(
            'This removes the advertisement from the marketplace.',
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
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = context.watch<ListingsProvider>().byId(listingId);
    const uid = _localUserId;

    if (listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: const Center(child: Text('This listing is no longer available.')),
      );
    }

    final mine = listing.sellerId != null && listing.sellerId == uid;

    final money = NumberFormat.currency(symbol: 'PKR ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(listing.category.label),
        actions: mine
            ? [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateListingScreen(editing: listing),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, listing.id),
                ),
              ]
            : null,
      ),
      body: ListView(
        children: [
          _Gallery(paths: listing.imagePaths),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  listing.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        Icons.category_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(listing.category.label),
                    ),
                    Chip(
                      avatar: Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text('${listing.locationArea}, $kCityName'),
                    ),
                  ],
                ),
                if (listing.askingPricePkr != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    money.format(listing.askingPricePkr),
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                ],
                const SizedBox(height: 20),
                _SectionTitle('Vehicle'),
                _DetailRow('Body type', listing.bodyType),
                _DetailRow('Colour', listing.color),
                if (listing.engineCc != null)
                  _DetailRow('Engine CC', '${listing.engineCc} cc'),
                if (listing.modelYear != null)
                  _DetailRow('Model year', '${listing.modelYear}'),
                _DetailRow('Registration no.', listing.registrationNumber),
                if (listing.notes != null && listing.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    listing.notes!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 24),
                _SectionTitle('Seller'),
                _DetailRow('Name', listing.sellerName),
                _DetailRow('Phone', listing.sellerPhone),
                const SizedBox(height: 24),
                if (!mine) ...[
                  FilledButton.icon(
                    onPressed: () =>
                        ContactService.dialPhone(listing.sellerPhone),
                    icon: const Icon(Icons.call),
                    label: const Text('Call seller'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: listing.sellerId == null
                        ? null
                        : () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => ChatScreen(
                                  listingId: listing.id,
                                  listingTitle: listing.title,
                                  buyerId: uid,
                                  buyerName: 'Buyer',
                                  sellerId: listing.sellerId!,
                                  sellerName: listing.sellerName,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat in app'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ContactService.openWhatsApp(listing.sellerPhone),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp seller'),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Meet in a safe public place in $kCityName. Verify documents in person before payment.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: paths.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: listingImageThumbnail(
                paths[i],
                width: 400,
                height: 300,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}
