import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/car_category.dart';
import '../providers/listings_provider.dart';
import '../widgets/listing_card.dart';
import 'category_listings_screen.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  String _query = '';
  _DiscoverFilters _filters = const _DiscoverFilters();

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<_DiscoverFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ListingFilterSheet(initial: _filters),
    );
    if (filters != null && mounted) setState(() => _filters = filters);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingsProvider>();
    final allListings = provider.listings;
    final normalizedQuery = _query.trim().toLowerCase();
    final listings = allListings.where((listing) {
      final searchableText = [
        listing.title,
        listing.brand,
        listing.model,
        listing.city,
        listing.fuel,
        listing.transmission,
        listing.category.label,
        listing.bikeType ?? '',
        listing.variant ?? '',
        listing.description ?? '',
      ].join(' ').toLowerCase();
      if (normalizedQuery.isNotEmpty &&
          !searchableText.contains(normalizedQuery)) {
        return false;
      }
      if (_filters.category != null && listing.category != _filters.category) {
        return false;
      }
      final price = listing.price;
      if (_filters.minPrice != null &&
          (price == null || price < _filters.minPrice!)) {
        return false;
      }
      if (_filters.maxPrice != null &&
          (price == null || price > _filters.maxPrice!)) {
        return false;
      }
      return true;
    }).toList();
    switch (_filters.sort) {
      case _ListingSort.newest:
        listings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _ListingSort.priceLowToHigh:
        listings.sort((a, b) {
          final aPrice = a.price ?? 1 << 62;
          final bPrice = b.price ?? 1 << 62;
          return aPrice.compareTo(bPrice);
        });
        break;
      case _ListingSort.priceHighToLow:
        listings.sort((a, b) {
          final aPrice = a.price ?? -1;
          final bPrice = b.price ?? -1;
          return bPrice.compareTo(aPrice);
        });
        break;
    }

    return RefreshIndicator(
      onRefresh: provider.loadListings,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              onSearch: (value) => setState(() => _query = value),
              onFilterTap: _openFilters,
              activeFilterCount: _filters.activeCount,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _SectionHeading(
                eyebrow: 'EXPLORE THE MARKET',
                title: 'Find your next ride',
                action: '${allListings.length} live ads',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                children: CarCategory.values
                    .map((category) => _CategoryShortcut(category: category))
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: _SectionHeading(
                eyebrow: _query.isEmpty && !_filters.isActive
                    ? 'FRESH IN MIANWALI'
                    : 'SEARCH RESULTS',
                title: _query.isEmpty && !_filters.isActive
                    ? 'Latest listings'
                    : 'Matching vehicles',
                action: listings.isEmpty ? '' : '${listings.length} found',
              ),
            ),
          ),
          if (listings.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(
                hasQuery: normalizedQuery.isNotEmpty,
                hasFilters: _filters.isActive,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList.separated(
                itemCount: listings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, index) =>
                    ListingCard(listing: listings[index]),
              ),
            ),
          SliverToBoxAdapter(child: _TrustPanel()),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.onSearch,
    required this.onFilterTap,
    required this.activeFilterCount,
  });
  final ValueChanged<String> onSearch;
  final VoidCallback onFilterTap;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F33), Color(0xFF123E58), Color(0xFF087E8B)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B1F33),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 15,
                  color: Color(0xFFFFC94A),
                ),
                SizedBox(width: 5),
                Text(
                  'MIANWALI, PAKISTAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'The smarter way to\nbuy and sell vehicles locally.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A trusted marketplace, built exclusively for your city.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .74),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: onSearch,
            style: const TextStyle(
              color: Color(0xFF0B1F33),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Search make, model or body type',
              hintStyle: const TextStyle(color: Color(0xFF718093)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF087E8B),
              ),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: Padding(
                padding: const EdgeInsets.all(5),
                child: Material(
                  color: const Color(0xFFFFB703),
                  borderRadius: BorderRadius.circular(8),
                  child: IconButton(
                    tooltip: 'Filter listings',
                    onPressed: onFilterTap,
                    icon: Badge(
                      isLabelVisible: activeFilterCount > 0,
                      label: Text('$activeFilterCount'),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF0B1F33),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryShortcut extends StatelessWidget {
  const _CategoryShortcut({required this.category});
  final CarCategory category;

  IconData get _icon => switch (category) {
    CarCategory.sedan => Icons.directions_car_filled_rounded,
    CarCategory.suv => Icons.airport_shuttle_rounded,
    CarCategory.hatchback => Icons.electric_car_rounded,
    CarCategory.pickup => Icons.local_shipping_rounded,
    CarCategory.motorcycle => Icons.two_wheeler_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = switch (category) {
      CarCategory.sedan => const [Color(0xFFE2F2F4), Color(0xFF087E8B)],
      CarCategory.suv => const [Color(0xFFEAF0FF), Color(0xFF3564C2)],
      CarCategory.hatchback => const [Color(0xFFFFF1D6), Color(0xFFDD8214)],
      CarCategory.pickup => const [Color(0xFFECEFF3), Color(0xFF475569)],
      CarCategory.motorcycle => const [Color(0xFFFFE5E1), Color(0xFFCB4937)],
    };
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryListingsScreen(category: category),
          ),
        ),
        child: Ink(
          width: 112,
          height: 106,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EBF0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.first,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: colors.last, size: 25),
              ),
              const SizedBox(height: 8),
              Text(
                category.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.15,
                  color: Color(0xFF142B41),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ListingSort { newest, priceLowToHigh, priceHighToLow }

class _DiscoverFilters {
  const _DiscoverFilters({
    this.category,
    this.minPrice,
    this.maxPrice,
    this.sort = _ListingSort.newest,
  });

  final CarCategory? category;
  final int? minPrice;
  final int? maxPrice;
  final _ListingSort sort;

  bool get isActive => activeCount > 0;

  int get activeCount =>
      (category == null ? 0 : 1) +
      (minPrice == null ? 0 : 1) +
      (maxPrice == null ? 0 : 1) +
      (sort == _ListingSort.newest ? 0 : 1);
}

class _ListingFilterSheet extends StatefulWidget {
  const _ListingFilterSheet({required this.initial});

  final _DiscoverFilters initial;

  @override
  State<_ListingFilterSheet> createState() => _ListingFilterSheetState();
}

class _ListingFilterSheetState extends State<_ListingFilterSheet> {
  late final TextEditingController _minPrice = TextEditingController(
    text: widget.initial.minPrice?.toString() ?? '',
  );
  late final TextEditingController _maxPrice = TextEditingController(
    text: widget.initial.maxPrice?.toString() ?? '',
  );
  late CarCategory? _category = widget.initial.category;
  late _ListingSort _sort = widget.initial.sort;
  String? _rangeError;

  @override
  void dispose() {
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _category = null;
      _sort = _ListingSort.newest;
      _minPrice.clear();
      _maxPrice.clear();
      _rangeError = null;
    });
  }

  void _apply() {
    final min = int.tryParse(_minPrice.text.trim());
    final max = int.tryParse(_maxPrice.text.trim());
    if ((_minPrice.text.trim().isNotEmpty && min == null) ||
        (_maxPrice.text.trim().isNotEmpty && max == null) ||
        (min != null && max != null && min > max)) {
      setState(() => _rangeError = 'Enter a valid price range.');
      return;
    }
    Navigator.of(context).pop(
      _DiscoverFilters(
        category: _category,
        minPrice: min,
        maxPrice: max,
        sort: _sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter listings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close filters',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Vehicle type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...CarCategory.values.map(
                  (category) => ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Price range (PKR)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPrice,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Minimum',
                      prefixText: 'PKR ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxPrice,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Maximum',
                      prefixText: 'PKR ',
                    ),
                  ),
                ),
              ],
            ),
            if (_rangeError != null) ...[
              const SizedBox(height: 6),
              Text(_rangeError!, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 20),
            Text('Sort by', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Newest'),
                  selected: _sort == _ListingSort.newest,
                  onSelected: (_) =>
                      setState(() => _sort = _ListingSort.newest),
                ),
                ChoiceChip(
                  label: const Text('Price: low to high'),
                  selected: _sort == _ListingSort.priceLowToHigh,
                  onSelected: (_) =>
                      setState(() => _sort = _ListingSort.priceLowToHigh),
                ),
                ChoiceChip(
                  label: const Text('Price: high to low'),
                  selected: _sort == _ListingSort.priceHighToLow,
                  onSelected: (_) =>
                      setState(() => _sort = _ListingSort.priceHighToLow),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(onPressed: _reset, child: const Text('Reset')),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check),
                    label: const Text('Show listings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.action,
  });
  final String eyebrow;
  final String title;
  final String action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: Color(0xFF087E8B),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.25,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      if (action.isNotEmpty)
        Text(
          action,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery, required this.hasFilters});
  final bool hasQuery;
  final bool hasFilters;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5EBF0)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.directions_car_outlined,
          size: 42,
          color: Color(0xFF087E8B),
        ),
        const SizedBox(height: 12),
        Text(
          hasQuery || hasFilters
              ? 'No matching vehicles yet'
              : 'Mianwali is ready for its first listing',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          hasQuery || hasFilters
              ? 'Try a different search or widen your filters.'
              : 'Be first to post a vehicle and get seen by local buyers.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      ],
    ),
  );
}

class _TrustPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFE0F4F4),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Color(0xFF087E8B),
          foregroundColor: Colors.white,
          child: Icon(Icons.verified_user_outlined),
        ),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buy with confidence',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1F33),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Meet locally, inspect the vehicle and verify documents before payment.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF345260),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
