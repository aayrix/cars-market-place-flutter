import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:apni_gari/models/car_category.dart';
import 'package:apni_gari/models/car_listing.dart';
import 'package:apni_gari/providers/listings_provider.dart';
import 'package:apni_gari/screens/discover_tab.dart';

void main() {
  testWidgets('Discover tab shows the marketplace hero', (tester) async {
    final listing = CarListing(
      id: 't1',
      sellerId: 'u1',
      category: CarCategory.sedan,
      brand: 'Toyota',
      model: 'Corolla',
      year: 2020,
      price: 4500000,
      mileage: 35000,
      fuel: 'Petrol',
      transmission: 'Automatic',
      description: 'A clean test car in good condition.',
      city: 'Mianwali',
      imagePaths: const [],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ListingsProvider>(
        create: (_) => ListingsProvider.seeded([listing]),
        child: const MaterialApp(home: Scaffold(body: DiscoverTab())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.textContaining(RegExp('mianwali', caseSensitive: false)),
      findsWidgets,
    );
    expect(find.textContaining('Corolla'), findsWidgets);
  });
}
