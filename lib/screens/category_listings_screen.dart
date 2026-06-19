import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car_category.dart';
import '../providers/listings_provider.dart';
import '../widgets/listing_card.dart';

class CategoryListingsScreen extends StatelessWidget {
  const CategoryListingsScreen({super.key, required this.category});

  final CarCategory category;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingsProvider>();
    final items = provider.byCategory(category);

    return Scaffold(
      appBar: AppBar(
        title: Text(category.label),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No ${category.label.toLowerCase()} listings yet.\nAsk neighbours to post from the Sell tab.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, i) => ListingCard(listing: items[i]),
            ),
    );
  }
}
