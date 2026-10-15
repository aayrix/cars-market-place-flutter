import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car_listing.dart';
import '../models/user_profile.dart';
import '../providers/listings_provider.dart';
import '../services/profile_service.dart';
import '../services/social_service.dart';
import '../utils/error_messages.dart';
import '../providers/auth_provider.dart';
import '../utils/listing_image.dart';
import 'listing_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.initialProfile,
  });
  final String userId;
  final UserProfile? initialProfile;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final Future<UserProfile?> _profile = _loadProfile();
  final _social = SocialService();
  late Future<int> _connectionCount = _social.connectionCount(widget.userId);
  late Future<String?> _connectionState = _social.connectionStatus(
    widget.userId,
  );
  bool _connectionBusy = false;

  void _refreshSocial() {
    setState(() {
      _connectionCount = _social.connectionCount(widget.userId);
      _connectionState = _social.connectionStatus(widget.userId);
    });
  }

  Future<void> _connectionAction(String? status) async {
    setState(() => _connectionBusy = true);
    try {
      if (status == null) {
        await _social.requestConnection(widget.userId);
      } else if (status.startsWith('received:')) {
        await _social.respondToConnection(
          status.substring('received:'.length),
          accept: true,
        );
      }
      _refreshSocial();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.from(
                error,
                fallback: 'Could not update this connection. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connectionBusy = false);
    }
  }

  Future<UserProfile?> _loadProfile() async {
    if (widget.initialProfile != null) return widget.initialProfile;
    if (!ProfileService().isConfigured) return null;
    try {
      return (await ProfileService().fetchForUsers([
        widget.userId,
      ]))[widget.userId];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = context
        .watch<ListingsProvider>()
        .listings
        .where((e) => e.sellerId == widget.userId)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<UserProfile?>(
        future: _profile,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final myId = context.watch<AuthProvider>().userId;
          final isOwnProfile = myId == widget.userId;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundImage: profile?.avatarUrl.isNotEmpty == true
                            ? NetworkImage(profile!.avatarUrl)
                            : null,
                        child: profile?.avatarUrl.isNotEmpty == true
                            ? null
                            : const Icon(Icons.person_outline, size: 42),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile?.displayName ?? 'Apni Gari member',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (profile?.city.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            profile!.city,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      FutureBuilder<int>(
                        future: _connectionCount,
                        builder: (context, count) => FutureBuilder<String?>(
                          future: _connectionState,
                          builder: (context, state) => Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _ProfileStat(
                                    value: '${listings.length}',
                                    label: 'Active ads',
                                  ),
                                  _ProfileStat(
                                    value: '${count.data ?? 0}',
                                    label: 'Connections',
                                  ),
                                  _ProfileStat(
                                    value: profile?.city.isNotEmpty == true
                                        ? profile!.city
                                        : '—',
                                    label: 'City',
                                  ),
                                ],
                              ),
                              if (!isOwnProfile && myId != null) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: _ConnectionButton(
                                    status: state.data,
                                    busy: _connectionBusy,
                                    onPressed: () =>
                                        _connectionAction(state.data),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                  child: Text(
                    'Active ads',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (listings.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No active ads yet.'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid.builder(
                    itemCount: listings.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: .78,
                        ),
                    itemBuilder: (context, index) =>
                        _ProfileAdCard(listing: listings[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.status,
    required this.busy,
    required this.onPressed,
  });
  final String? status;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = status == 'connected'
        ? 'Connected'
        : status == 'sent'
        ? 'Request sent'
        : (status?.startsWith('received:') == true
              ? 'Accept connection'
              : 'Connect');
    return OutlinedButton.icon(
      onPressed: busy || status == 'connected' || status == 'sent'
          ? null
          : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(status == 'connected' ? Icons.check : Icons.person_add_alt_1),
      label: Text(label),
    );
  }
}

class _ProfileAdCard extends StatelessWidget {
  const _ProfileAdCard({required this.listing});
  final CarListing listing;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ListingDetailScreen(listingId: listing.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => listingImageThumbnail(
                context,
                listing.imagePaths.isEmpty ? '' : listing.imagePaths.first,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.priceLabel.isEmpty
                      ? 'Price on request'
                      : listing.priceLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
