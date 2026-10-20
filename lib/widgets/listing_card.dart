import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/car_listing.dart';
import '../models/user_profile.dart';
import '../providers/listings_provider.dart';
import '../screens/listing_detail_screen.dart';
import '../utils/listing_image.dart';
import 'verification_badge.dart';

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
    final isFavorited = context.select<ListingsProvider, bool>(
      (provider) => provider.isFavorited(listing.id),
    );
    final seller = listedSeller;
    final thumb = listing.imagePaths.isNotEmpty
        ? listing.imagePaths.first
        : null;

    final imageWidth = compact ? null : 132.0;
    final imageHeight = compact ? null : 112.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Material(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ListingDetailScreen(listingId: listing.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: compact
                ? _buildCompact(context, cs, seller, isFavorited, thumb)
                : _buildWide(
                    context,
                    cs,
                    seller,
                    isFavorited,
                    thumb,
                    imageWidth,
                    imageHeight,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    ColorScheme cs,
    UserProfile? seller,
    bool isFavorited,
    String? thumb,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: thumb != null
                      ? listingImageThumbnail(
                          context,
                          thumb,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.directions_car_filled_outlined,
                          color: cs.outline,
                          size: 32,
                        ),
                ),
                if (listing.isFeatured)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Featured',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (seller != null && seller.hasVerifiedPhone)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: VerificationBadge(),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () async {
                      final error = await context
                          .read<ListingsProvider>()
                          .toggleFavorite(listing.id);
                      if (error != null) {
                        try {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        } catch (_) {
                          // Context may be stale if card was removed from tree.
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: isFavorited ? Colors.red : cs.onSurface,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Title
        Text(
          listing.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        // Price + city row
        Row(
          children: [
            if (listing.price != null) ...[
              Expanded(
                child: Text(
                  'PKR ${_money.format(listing.price)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.place_outlined, size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      listing.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Spec pills
        Wrap(
          spacing: 6,
          runSpacing: 4,
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
          ],
        ),
        if (seller != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundImage: seller.avatarUrl.isEmpty
                    ? null
                    : CachedNetworkImageProvider(seller.avatarUrl),
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
                child: Row(
                  children: [
                    Text(
                      seller.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (seller.hasVerifiedPhone) ...[
                      const SizedBox(width: 6),
                      const VerificationBadge(),
                    ],
                    if (seller.accountType == 'dealer') ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.storefront,
                        size: 14,
                        color: Colors.blueGrey,
                      ),
                      const Text(
                        'Dealer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildWide(
    BuildContext context,
    ColorScheme cs,
    UserProfile? seller,
    bool isFavorited,
    String? thumb,
    double? imageWidth,
    double? imageHeight,
  ) {
    return Row(
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
                      width: imageWidth!,
                      height: imageHeight!,
                      fit: BoxFit.cover,
                      placeholder: (_) => _placeholder(cs),
                    )
                  : _placeholder(cs),
            ),
          ),
        ),
        SizedBox(width: MediaQuery.sizeOf(context).width >= 720 ? 20 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.title,
                maxLines: MediaQuery.sizeOf(context).width >= 720 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
                  Icon(Icons.place_outlined, size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      listing.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (listing.price != null) ...[
                const SizedBox(height: 6),
                Text(
                  'PKR ${_money.format(listing.price)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                          : CachedNetworkImageProvider(seller.avatarUrl),
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
                      child: Row(
                        children: [
                          Text(
                            seller.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (seller.hasVerifiedPhone) ...[
                            const SizedBox(width: 6),
                            const VerificationBadge(),
                          ],
                          if (seller.accountType == 'dealer') ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.storefront,
                              size: 14,
                              color: Colors.blueGrey,
                            ),
                            const Text(
                              'Dealer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: isFavorited ? 'Remove from favorites' : 'Add to favorites',
          icon: Icon(
            isFavorited ? Icons.favorite : Icons.favorite_border,
            color: isFavorited ? Colors.red : cs.outline,
          ),
          onPressed: () async {
            final error = await context.read<ListingsProvider>().toggleFavorite(
              listing.id,
            );
            if (error != null) {
              try {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error)));
              } catch (_) {
                // Context may be stale if card was removed from tree.
              }
            }
          },
        ),
      ],
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
