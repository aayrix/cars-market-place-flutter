import 'car_category.dart';

/// A car listing backed by the `cars` table.
class CarListing {
  CarListing({
    required this.id,
    this.sellerId,
    required this.brand,
    required this.model,
    this.year,
    this.price,
    this.mileage,
    this.engineCc,
    this.bikeType,
    this.variant,
    required this.fuel,
    required this.transmission,
    this.description,
    required this.city,
    required this.category,
    required this.imagePaths,
    required this.createdAt,
  });

  final String id;

  /// Authenticated Supabase user id (`auth.uid()`), never a hardcoded value.
  final String? sellerId;

  final String brand;
  final String model;
  final int? year;
  final int? price;
  final int? mileage;
  final int? engineCc;
  final String? bikeType;
  final String? variant;
  final String fuel;
  final String transmission;
  final String? description;
  final String city;
  final CarCategory category;

  /// Public URLs coming from the `car_images` table / `car-images` bucket.
  final List<String> imagePaths;
  final DateTime createdAt;

  String get title {
    final y = year != null ? ' ($year)' : '';
    final trim = variant?.trim() ?? '';
    return '$brand $model${trim.isEmpty ? '' : ' $trim'}$y'.trim();
  }

  String get priceLabel => price == null ? '' : 'PKR $price';

  factory CarListing.fromRow(
    Map<String, dynamic> row, {
    List<String> images = const [],
  }) {
    return CarListing(
      id: '${row['id']}',
      sellerId: row['seller_id'] as String?,
      brand: '${row['brand'] ?? ''}',
      model: '${row['model'] ?? ''}',
      year: _asInt(row['year']),
      price: _asInt(row['price']),
      mileage: _asInt(row['mileage']),
      engineCc: _asInt(row['engine_cc']),
      bikeType: row['bike_type'] as String?,
      variant: row['variant'] as String?,
      fuel: '${row['fuel'] ?? 'Petrol'}',
      transmission: '${row['transmission'] ?? 'Manual'}',
      description: row['description'] as String?,
      city: '${row['city'] ?? ''}',
      category:
          carCategoryFromString(row['category'] as String?) ??
          CarCategory.sedan,
      imagePaths: images,
      createdAt:
          DateTime.tryParse('${row['created_at'] ?? ''}') ?? DateTime.now(),
    );
  }

  static int? _asInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    return int.tryParse(raw.toString());
  }
}
