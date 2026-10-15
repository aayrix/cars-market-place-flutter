import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/mianwali_data.dart';
import '../models/car_category.dart';
import '../models/car_listing.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/listings_provider.dart';
import '../services/contact_service.dart';
import '../services/chat_service.dart';
import '../utils/listing_image.dart';
import 'chat_screen.dart';
import 'create_listing_screen.dart';
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

  Future<void> _loadSeller(CarListing listing) async {
    final profile = await context.read<ListingsProvider>().fetchSellerProfile(
      listing,
    );
    if (!mounted) return;
    setState(() => _fetchedSeller = profile);
  }

  void _contactMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    if (!await ContactService.openWhatsApp(phone) && mounted) {
      _contactMessage('Could not open WhatsApp for this number.');
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

  Future<void> _makeOffer({
    required CarListing listing,
    required String? userId,
    required bool signedIn,
    required String buyerName,
    required UserProfile? seller,
  }) async {
    if (_makingOffer) return;
    if (!signedIn || userId == null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final sellerId = listing.sellerId;
    if (sellerId == null || sellerId.isEmpty || sellerId == userId) return;
    setState(() => _makingOffer = true);
    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => _OfferDialog(askingPrice: listing.price),
      );
      if (result == null || !mounted) return;
      final amount = int.tryParse(result['amount']!.replaceAll(',', ''))!;
      final message = [
        '💰 PRICE OFFER',
        'Offer: PKR ${NumberFormat('#,###').format(amount)}',
        'Payment plan: ${result['plan']}',
        if (result['note']!.isNotEmpty) 'Note: ${result['note']}',
      ].join('\n');
      await ChatService().sendMessage(
        listingId: listing.id,
        listingTitle: listing.title,
        buyerId: userId,
        buyerName: buyerName,
        sellerId: sellerId,
        sellerName: seller?.displayName ?? 'Seller',
        senderId: userId,
        senderName: buyerName,
        text: message,
      );
      if (!mounted) return;
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
    } catch (error) {
      if (mounted) _contactMessage('Offer could not be sent: $error');
    } finally {
      if (mounted) setState(() => _makingOffer = false);
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Car deleted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingsProvider>();
    final listing = provider.byId(widget.listingId);
    final auth = context.watch<AuthProvider>();
    final uid = auth.userId;

    if (listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car')),
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
    final mine = uid != null && listing.sellerId == uid;
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
                      label: Text('${listing.city}, $kCountryHint'),
                    ),
                  ],
                ),
                if (listing.price != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    money.format(listing.price),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _SectionTitle('Vehicle'),
                if (listing.year != null) _DetailRow('Year', '${listing.year}'),
                if (listing.mileage != null)
                  _DetailRow(
                    'Mileage',
                    '${_number.format(listing.mileage)} km',
                  ),
                if (listing.engineCc != null)
                  _DetailRow('Engine', '${listing.engineCc} cc'),
                if (listing.variant?.isNotEmpty == true)
                  _DetailRow('Variant', listing.variant!),
                if (listing.bikeType?.isNotEmpty == true)
                  _DetailRow('Bike type', listing.bikeType!),
                _DetailRow('Fuel', listing.fuel),
                _DetailRow('Transmission', listing.transmission),
                _DetailRow('City', listing.city),
                if (listing.description != null &&
                    listing.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    listing.description!.trim(),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 24),
                _SectionTitle('Seller'),
                const SizedBox(height: 8),
                if (resolvedSeller == null && listing.sellerId != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.profilesLoadError == null
                                ? 'Seller contact details are not available for this listing.'
                                : 'Seller contact lookup failed: ${provider.profilesLoadError}',
                          ),
                        ),
                        TextButton(
                          onPressed: () => _loadSeller(listing),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(14),
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
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundImage:
                            resolvedSeller == null ||
                                resolvedSeller.avatarUrl.isEmpty
                            ? null
                            : NetworkImage(resolvedSeller.avatarUrl),
                        child:
                            resolvedSeller == null ||
                                resolvedSeller.avatarUrl.isEmpty
                            ? const Icon(Icons.person_outline, size: 28)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolvedSeller?.displayName ?? 'Not available',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (resolvedSeller?.city.isNotEmpty == true)
                              Text(
                                resolvedSeller!.city,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _DetailRow('Phone', resolvedSeller?.phone ?? 'Not available'),
                const SizedBox(height: 24),
                if (!mine) ...[
                  FilledButton.icon(
                    onPressed:
                        resolvedSeller == null || resolvedSeller.phone.isEmpty
                        ? null
                        : () => _callSeller(resolvedSeller),
                    icon: const Icon(Icons.call),
                    label: const Text('Call seller'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _makingOffer
                        ? null
                        : () => _makeOffer(
                            listing: listing,
                            userId: uid,
                            signedIn: auth.isSignedIn,
                            buyerName: auth.safeProfile.displayName,
                            seller: resolvedSeller,
                          ),
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('Make an offer'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _openInAppChat(
                      context: context,
                      listing: listing,
                      userId: uid,
                      signedIn: auth.isSignedIn,
                      buyerName: auth.safeProfile.displayName,
                      seller: resolvedSeller,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat in app'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        resolvedSeller == null || resolvedSeller.phone.isEmpty
                        ? null
                        : () => _whatsAppSeller(resolvedSeller),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp seller'),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Meet in a safe public place in $kCityName. Verify documents '
                  'in person before payment.',
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

final _number = NumberFormat('#,###', 'en');

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

class _Gallery extends StatefulWidget {
  const _Gallery({required this.paths});

  final List<String> paths;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final PageController _pageController;
  int _currentPage = 0;

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

  @override
  Widget build(BuildContext context) {
    if (widget.paths.isEmpty) {
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
    final width = MediaQuery.sizeOf(context).width - 24;
    // Match the landscape image frame used by the home listing cards (104×88).
    final height = width * 88 / 104;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: height,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.paths.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: listingImageThumbnail(
                    context,
                    widget.paths[index],
                    width: width,
                    height: height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.paths.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                widget.paths.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _currentPage ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == _currentPage
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
