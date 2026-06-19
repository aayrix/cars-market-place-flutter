import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/car_listing.dart';
import '../screens/listing_detail_screen.dart';
import '../utils/listing_image.dart';

final _money = NumberFormat('#,###', 'en');

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, this.compact = false});

  final CarListing listing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thumb = listing.imagePaths.isNotEmpty
        ? listing.imagePaths.first
        : null;

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ListingDetailScreen(listingId: listing.id),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: compact ? 88 : 104,
                height: compact ? 72 : 88,
                child: thumb != null
                    ? listingImageThumbnail(
                        thumb,
                        width: compact ? 88 : 104,
                        height: compact ? 72 : 88,
                        fit: BoxFit.cover,
                        placeholder: (_) => _placeholder(cs),
                      )
                    : _placeholder(cs),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _infoPill(
                        context,
                        icon: Icons.palette_outlined,
                        text: listing.color,
                      ),
                      if (listing.modelYear != null)
                        _infoPill(
                          context,
                          icon: Icons.event_outlined,
                          text: '${listing.modelYear}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.locationArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (listing.askingPricePkr != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'PKR ${_money.format(listing.askingPricePkr)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.outline),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.directions_car_filled_outlined, color: cs.outline),
    );
  }

  Widget _infoPill(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
