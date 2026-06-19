import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mianwali_wheels/models/car_category.dart';
import 'package:mianwali_wheels/models/car_listing.dart';
import 'package:mianwali_wheels/providers/listings_provider.dart';
import 'package:mianwali_wheels/screens/discover_tab.dart';

void main() {
  testWidgets('Discover tab shows local marketplace heading', (tester) async {
    final listing = CarListing(
      id: 't1',
      sellerId: 'u1',
      category: CarCategory.sedan,
      bodyType: 'Sedan',
      modelName: 'Test Car',
      modelYear: 2020,
      registrationNumber: 'REG-1',
      color: 'White',
      locationArea: 'PAF ROAD',
      sellerName: 'Seller',
      sellerPhone: '03001234567',
      askingPricePkr: 1000000,
      notes: null,
      imagePaths: const [],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ListingsProvider>(
        create: (_) => ListingsProvider.seeded([listing]),
        child: const MaterialApp(home: DiscoverTab()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Mianwali'), findsWidgets);
  });
}
