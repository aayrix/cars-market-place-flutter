import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/car_category.dart';
import '../models/car_listing.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/listings_provider.dart';
import '../services/chat_service.dart';
import '../services/contact_service.dart';
import '../widgets/verification_badge.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'public_profile_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  UserProfile? _fetchedSeller;
  String? _lookupStartedFor;
  bool _makingOffer = false;
  int _currentImageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSeller(CarListing listing) async {
    final profile = await context.read<ListingsProvider>().fetchSellerProfile(
      listing,
    );
    if (!mounted) return;
    setState(() => _fetchedSeller = profile);
  }

  void _contactMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callSeller(UserProfile? seller) async {
    final phone = seller?.phone.trim() ?? '';
    if (phone.isEmpty) {
      _contactMessage('The seller has not added a phone number yet.');
      return;
    }
    if (!await ContactService.dialPhone(phone) && mounted) {
      _contactMessage('Could not open the phone dialer.');
    }
  }

  Future<void> _whatsAppSeller(UserProfile? seller) async {
    final phone = seller?.phone.trim() ?? '';
    if (phone.isEmpty) {
      _contactMessage('The seller has not added a phone number yet.');
      return;
    }
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    String wa = normalized;
    if (wa.length == 10 && wa.startsWith('3')) {
      wa = '92$wa';
    } else if (wa.length == 11 && wa.startsWith('0')) {
      wa = '92${wa.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$wa');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _contactMessage('Could not open WhatsApp.');
    }
  }

  Future<void> _shareListingToWhatsApp(CarListing listing) async {
    final message = '''
🚗 *${listing.title}*
💰 ${listing.priceLabel.isNotEmpty ? listing.priceLabel : 'Price on request'}
📍 ${listing.city}

See more details on Apni Gari.
'''.trim();
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _contactMessage('Could not open WhatsApp.');
    }
  }

  void _openInAppChat({
    required BuildContext context,
    required CarListing listing,
    required String? userId,
    required bool signedIn,
    required String buyerName,
    required UserProfile? seller,
  }) {
    if (!signedIn || userId == null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final sellerId = listing.sellerId;
    if (sellerId == null || sellerId.isEmpty) {
      _contactMessage('Seller information is not available for this listing.');
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          listingId: listing.id,
          listingTitle: listing.title,
          buyerId: userId,
          buyerName: buyerName,
          sellerId: sellerId,
          sellerName: seller?.displayName ?? 'Seller',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete car?'),
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
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await context.read<ListingsProvider>().deleteCar(id);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Car deleted.')));
    }
  }

  Widget _specChip(BuildContext context, {required IconData icon, required String label, required String value}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 90,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: cs.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<ListingsProvider>();
    final listing = provider.byId(widget.listingId);
    final auth = context.watch<AuthProvider>();

    if (listing == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(title: const Text('Car'), backgroundColor: cs.surface),
        body: const Center(child: Text('This listing is no longer available.')),
      );
    }

    final seller = provider.sellerOf(listing);
    if (listing.sellerId != null &&
        seller == null &&
        _fetchedSeller == null &&
        _lookupStartedFor != listing.id) {
      _lookupStartedFor = listing.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSeller(listing));
    }
    final resolvedSeller = seller ?? _fetchedSeller;
    final isFavorited = provider.isFavorited(listing.id);
    final money = NumberFormat.currency(symbol: 'PKR ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(isFavorited ? Icons.favorite : Icons.favorite_border,
                color: Colors.white),
            onPressed: () async {
              final error = await provider.toggleFavorite(listing.id);
              if (error != null) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Image gallery
          SizedBox(
            height: 300,
            width: double.infinity,
            child: listing.imagePaths.isNotEmpty
                ? Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: listing.imagePaths.length,
                        onPageChanged: (i) => setState(() => _currentImageIndex = i),
                        itemBuilder: (_, index) => CachedNetworkImage(
                          imageUrl: listing.imagePaths[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.directions_car_filled_outlined,
                                size: 48, color: cs.outlineVariant),
                          ),
                          errorWidget: (context, url, error) => ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.directions_car_filled_outlined,
                                size: 48, color: cs.outlineVariant),
                          ),
                        ),
                      ),
                      // Image counter
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1} / ${listing.imagePaths.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                      // Page dots
                      if (listing.imagePaths.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List<Widget>.generate(
                              listing.imagePaths.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentImageIndex == index ? 20 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _currentImageIndex == index
                                      ? cs.primary
                                      : cs.onSurfaceVariant.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: Center(
                      child: Icon(Icons.directions_car_filled_outlined,
                          size: 48, color: cs.outlineVariant),
                    ),
                  ),
          ),
          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                // Title + City tag
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              listing.city,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.share_outlined, color: cs.onSurfaceVariant),
                      onPressed: () => _shareListingToWhatsApp(listing),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Price
                Text(
                  money.format(listing.price),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 20),
                // Spec chips (2 rows × 3)
                Row(
                  children: [
                    Expanded(child: _specChip(context, icon: Icons.event_outlined, label: 'Year', value: '${listing.year}')),
                    const SizedBox(width: 8),
                    Expanded(child: _specChip(context, icon: Icons.local_gas_station_outlined, label: 'Mileage', value: '${listing.mileage ?? '—'} km')),
                    Expanded(child: _specChip(context, icon: Icons.local_gas_station_outlined, label: 'Fuel', value: listing.fuel)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _specChip(context, icon: Icons.settings_outlined, label: 'Gear', value: listing.transmission)),
                    Expanded(child: _specChip(context, icon: Icons.speed_outlined, label: 'cc', value: '${listing.engineCc ?? '—'}')),
                    Expanded(child: _specChip(context, icon: Icons.directions_car_outlined, label: 'Body', value: listing.category.label)),
                  ],
                ),
                const SizedBox(height: 24),
                // Seller profile card (clickable)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: listing.sellerId == null
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => PublicProfileScreen(
                              userId: listing.sellerId!,
                              initialProfile: resolvedSeller,
                            ),
                          ),
                        ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: resolvedSeller == null ||
                                  resolvedSeller.avatarUrl.isEmpty
                              ? null
                              : CachedNetworkImageProvider(
                                  resolvedSeller.avatarUrl,
                                ),
                          child: resolvedSeller == null ||
                                  resolvedSeller.avatarUrl.isEmpty
                              ? const Icon(Icons.person_outline, size: 28)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      resolvedSeller?.displayName ?? 'Seller',
                                      style: Theme.of(context).textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (resolvedSeller?.isVerified == true) ...[
                                    const SizedBox(width: 6),
                                    const VerificationBadge(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Member since ${resolvedSeller?.city} • Private seller',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Description
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    listing.description != null &&
                            listing.description!.trim().isNotEmpty
                        ? listing.description!.trim()
                        : "Seller's description of the car's condition, history and features goes here.",
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Bottom action bar (fixed)
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: resolvedSeller == null || resolvedSeller.phone.isEmpty
                        ? null
                        : () => _callSeller(resolvedSeller),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: cs.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openInAppChat(
                      context: context,
                      listing: listing,
                      userId: auth.userId,
                      signedIn: auth.isSignedIn,
                      buyerName: auth.safeProfile.displayName,
                      seller: resolvedSeller,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: cs.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text(
                      'Chat in app',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _whatsAppSeller(resolvedSeller),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.askingPrice});

  final int? askingPrice;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.askingPrice?.toString() ?? '',
  );
  final _plan = TextEditingController(text: 'Full payment in cash');
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _plan.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Send your offer'),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share what you can pay and how you plan to pay.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Offer amount',
                prefixText: 'PKR ',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _plan,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Payment plan',
                hintText: 'Cash, bank transfer, installments…',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Pickup timing or other details',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final amount = int.tryParse(_amount.text.replaceAll(',', '').trim());
          if (amount == null || amount <= 0 || _plan.text.trim().isEmpty) {
            setState(() => _error = 'Enter a valid amount and payment plan.');
            return;
          }
          Navigator.pop(context, {
            'amount': amount.toString(),
            'plan': _plan.text.trim(),
            'note': _note.text.trim(),
          });
        },
        child: const Text('Send offer'),
      ),
    ],
  );
}
