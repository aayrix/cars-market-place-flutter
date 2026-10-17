import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/car_category.dart';
import '../providers/listings_provider.dart';
import '../utils/ag_design.dart';
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
  Timer? _searchDebounce;

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<_DiscoverFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListingFilterSheet(initial: _filters),
    );
    if (filters != null && mounted) setState(() => _filters = filters);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allListings = context.watch<ListingsProvider>().listings;
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
    }).toList()
      ..sort((a, b) {
        switch (_filters.sort) {
          case _ListingSort.priceLowToHigh:
            final aPrice = a.price ?? 1 << 62;
            final bPrice = b.price ?? 1 << 62;
            return aPrice.compareTo(bPrice);
          case _ListingSort.priceHighToLow:
            final aPrice = a.price ?? -1;
            final bPrice = b.price ?? -1;
            return bPrice.compareTo(aPrice);
          case _ListingSort.newest:
          default:
            return b.createdAt.compareTo(a.createdAt);
        }
      });

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ListingsProvider>().loadListings();
        },
        color: cs.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(
                onSearch: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (mounted) setState(() => _query = value);
                    },
                  );
                },
                onFilterTap: _openFilters,
                activeFilterCount: _filters.activeCount,
              ),
            ),
            SliverToBoxAdapter(
              child: AGDesign.sectionHeader(
                context,
                'EXPLORE THE MARKET',
                action: '${allListings.length} live ads',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(
                    AGDesign.xs, AGDesign.xs, AGDesign.xs, AGDesign.xs,
                  ),
                  children: CarCategory.values
                      .map((category) => _CategoryShortcut(category: category))
                      .toList(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AGDesign.sectionHeader(
                context,
                _query.isEmpty && !_filters.isActive
                    ? 'FRESH IN MIANWALI'
                    : 'SEARCH RESULTS',
                action: listings.isEmpty ? '' : '${listings.length} found',
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
                padding: const EdgeInsets.fromLTRB(
                  AGDesign.xs, 0, AGDesign.xs, AGDesign.xxl,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: listings.length,
                  itemBuilder: (_, index) =>
                      ListingCard(listing: listings[index], compact: true),
                ),
              ),
            SliverToBoxAdapter(child: _TrustPanel()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AGDesign.xs, AGDesign.xs, AGDesign.xs, 0,
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AGDesign.radiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1F33),
            Color(0xFF123E58),
            Color(0xFF087E8B),
          ],
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
          _SearchField(
            onSearch: onSearch,
            onFilterTap: onFilterTap,
            activeFilterCount: activeFilterCount,
            isDark: isDark,
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.onSearch,
    required this.onFilterTap,
    required this.activeFilterCount,
    required this.isDark,
    required this.cs,
  });

  final ValueChanged<String> onSearch;
  final VoidCallback onFilterTap;
  final int activeFilterCount;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AGDesign.radiusMd),
        border: Border.all(
          color: isDark
              ? cs.outline.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: TextField(
        onChanged: onSearch,
        style: TextStyle(
          color: isDark ? cs.onSurface : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search make, model or body type',
          hintStyle: TextStyle(
            color: isDark
                ? cs.onSurfaceVariant.withValues(alpha: 0.7)
                : const Color(0xFF9FD8DF),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? cs.primary : const Color(0xFF087E8B),
            size: 20,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(5),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onFilterTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AGDesign.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Badge(
                  isLabelVisible: activeFilterCount > 0,
                  label: Text(
                    '$activeFilterCount',
                    style: const TextStyle(
                      color: Color(0xFF0B1F33),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF0B1F33),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          filled: true,
          fillColor: isDark
              ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.1),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AGDesign.radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AGDesign.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AGDesign.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _CategoryShortcut extends StatelessWidget {
  const _CategoryShortcut({required this.category});
  final CarCategory category;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final colors = _categoryColors(category);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AGDesign.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryListingsScreen(category: category),
          ),
        ),
        child: Ink(
          width: 100,
          height: 120,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(AGDesign.radiusMd),
            border: Border.all(
              color: isDark ? cs.outlineVariant : const Color(0xFFE5EBF0),
            ),
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
                child: Icon(_categoryIcon(category), color: colors.last, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                category.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  height: 1.15,
                  color: isDark ? cs.onSurface : const Color(0xFF142B41),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _categoryColors(CarCategory category) {
    switch (category) {
      case CarCategory.sedan:
        return const [Color(0xFFE2F2F4), Color(0xFF087E8B)];
      case CarCategory.suv:
        return const [Color(0xFFEAF0FF), Color(0xFF3564C2)];
      case CarCategory.hatchback:
        return const [Color(0xFFFFF1D6), Color(0xFFDD8214)];
      case CarCategory.pickup:
        return const [Color(0xFFECEFF3), Color(0xFF475569)];
      case CarCategory.motorcycle:
        return const [Color(0xFFFFE5E1), Color(0xFFCB4937)];
    }
  }

  IconData _categoryIcon(CarCategory category) {
    switch (category) {
      case CarCategory.sedan:
        return Icons.directions_car_filled_rounded;
      case CarCategory.suv:
        return Icons.airport_shuttle_rounded;
      case CarCategory.hatchback:
        return Icons.electric_car_rounded;
      case CarCategory.pickup:
        return Icons.local_shipping_rounded;
      case CarCategory.motorcycle:
        return Icons.two_wheeler_rounded;
    }
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
  late final TextEditingController _minPrice;
  late final TextEditingController _maxPrice;
  late CarCategory? _category;
  late _ListingSort _sort;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _minPrice = TextEditingController(
      text: widget.initial.minPrice?.toString() ?? '',
    );
    _maxPrice = TextEditingController(
      text: widget.initial.maxPrice?.toString() ?? '',
    );
    _category = widget.initial.category;
    _sort = widget.initial.sort;
  }

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
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? cs.surface : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AGDesign.radiusLg),
            topRight: Radius.circular(AGDesign.radiusLg),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AGDesign.md, AGDesign.md, AGDesign.md, AGDesign.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: AGDesign.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter listings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? cs.onSurface : null,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? cs.onSurface : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AGDesign.lg),
              Text('Vehicle type', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AGDesign.sm),
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
              const SizedBox(height: AGDesign.lg),
              Text(
                'Price range (PKR)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AGDesign.sm),
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
                  const SizedBox(width: AGDesign.sm),
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
                const SizedBox(height: AGDesign.sm),
                Text(_rangeError!, style: TextStyle(color: cs.error)),
              ],
              const SizedBox(height: AGDesign.lg),
              Text('Sort by', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AGDesign.sm),
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
              const SizedBox(height: AGDesign.xl),
              Row(
                children: [
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                  const SizedBox(width: AGDesign.sm),
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
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery, required this.hasFilters});
  final bool hasQuery;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(AGDesign.xs, 0, AGDesign.xs, AGDesign.xxl),
      padding: const EdgeInsets.all(AGDesign.lg),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(AGDesign.radiusLg),
        border: Border.all(
          color: isDark ? cs.outlineVariant : const Color(0xFFE5EBF0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 48,
            color: isDark ? cs.primary : const Color(0xFF087E8B),
          ),
          const SizedBox(height: AGDesign.sm),
          Text(
            hasQuery || hasFilters
                ? 'No matching vehicles yet'
                : 'Mianwali is ready for its first listing',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isDark ? cs.onSurface : null,
            ),
          ),
          const SizedBox(height: AGDesign.xs),
          Text(
            hasQuery || hasFilters
                ? 'Try a different search or widen your filters.'
                : 'Be first to post a vehicle and get seen by local buyers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? cs.onSurfaceVariant : const Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(AGDesign.xs, 0, AGDesign.xs, 0),
      padding: const EdgeInsets.all(AGDesign.md),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest : const Color(0xFFE0F4F4),
        borderRadius: BorderRadius.circular(AGDesign.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            child: Icon(Icons.verified_user_outlined),
          ),
          const SizedBox(width: AGDesign.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buy with confidence',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? cs.onSurface : const Color(0xFF0B1F33),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Meet locally, inspect the vehicle and verify documents before payment.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark
                        ? cs.onSurfaceVariant
                        : const Color(0xFF345260),
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
