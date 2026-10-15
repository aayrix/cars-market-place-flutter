import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/car_listing.dart';
import '../models/user_profile.dart';
import '../providers/listings_provider.dart';
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
    final listedSeller = context.select<ListingsProvider, UserProfile?>(
      (provider) => provider.sellerOf(listing),
    );
    final seller = listedSeller;
    final thumb = listing.imagePaths.isNotEmpty
        ? listing.imagePaths.first
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final imageWidth = wide
                ? math.min(320.0, constraints.maxWidth * .34)
                : compact
                ? 112.0
                : 132.0;
            final imageHeight = wide
                ? 210.0
                : compact
                ? 92.0
                : 112.0;
            return Material(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ListingDetailScreen(listingId: listing.id),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: imageWidth,
                          height: imageHeight,
                          child: ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: thumb != null
                                ? listingImageThumbnail(
                                    context,
                                    thumb,
                                    width: imageWidth,
                                    height: imageHeight,
                                    fit: BoxFit.cover,
                                    placeholder: (_) => _placeholder(cs),
                                  )
                                : _placeholder(cs),
                          ),
                        ),
                      ),
                      SizedBox(width: wide ? 20 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.title,
                              maxLines: wide ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (listing.year != null)
                                  _infoPill(
                                    context,
                                    icon: Icons.event_outlined,
                                    text: '${listing.year}',
                                  ),
                                _infoPill(
                                  context,
                                  icon: Icons.local_gas_station_outlined,
                                  text: listing.fuel,
                                ),
                                _infoPill(
                                  context,
                                  icon: Icons.settings_outlined,
                                  text: listing.transmission,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 14,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    listing.city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                            if (listing.price != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'PKR ${_money.format(listing.price)}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                            if (seller != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundImage: seller.avatarUrl.isEmpty
                                        ? null
                                        : NetworkImage(seller.avatarUrl),
                                    child: seller.avatarUrl.isEmpty
                                        ? Icon(
                                            Icons.person_outline,
                                            size: 13,
                                            color: cs.onSurfaceVariant,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      seller.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!wide) Icon(Icons.chevron_right, color: cs.outline),
                    ],
                  ),
                ),
              ),
            );
          },
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
