import 'car_category.dart';

/// Listing shown in the marketplace.
class CarListing {
  CarListing({
    required this.id,
    this.sellerId,
    required this.category,
    required this.bodyType,
    required this.modelName,
    this.modelYear,
    required this.registrationNumber,
    required this.color,
    this.engineCc,
    required this.locationArea,
    required this.sellerName,
    required this.sellerPhone,
    this.askingPricePkr,
    this.notes,
    required this.imagePaths,
    required this.createdAt,
  });

  final String id;
  final String? sellerId;

  final CarCategory category;
  final String bodyType;
  final String modelName;
  final int? modelYear;
  final String registrationNumber;
  final String color;
  final int? engineCc;

  /// One of the fixed Mianwali areas (no map search).
  final String locationArea;
  final String sellerName;
  final String sellerPhone;
  final int? askingPricePkr;
  final String? notes;
  final List<String> imagePaths;
  final DateTime createdAt;

  String get title {
    final y = modelYear != null ? ' ($modelYear)' : '';
    return '$modelName$y';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sellerId': sellerId,
        'category': category.name,
        'bodyType': bodyType,
        'modelName': modelName,
        'modelYear': modelYear,
        'registrationNumber': registrationNumber,
        'color': color,
        'engineCc': engineCc,
        'locationArea': locationArea,
        'sellerName': sellerName,
        'sellerPhone': sellerPhone,
        'askingPricePkr': askingPricePkr,
        'notes': notes,
        'imagePaths': imagePaths,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CarListing.fromJson(Map<String, dynamic> j) {
    final cat =
        carCategoryFromString(j['category'] as String?) ?? CarCategory.sedan;
    final imgs = _imagesFromList(
      j['images'] ?? j['imageUrls'] ?? j['imagePaths'],
    );
    return CarListing(
      id: '${j['id']}',
      sellerId: j['seller_id'] as String? ?? j['sellerId'] as String?,
      category: cat,
      bodyType: j['body_type'] as String? ?? j['bodyType'] as String? ?? '',
      modelName: j['model_name'] as String? ?? j['modelName'] as String? ?? '',
      modelYear: _asNullableInt(j['model_year'] ?? j['modelYear']),
      registrationNumber: j['registration_number'] as String? ??
          j['registrationNumber'] as String? ??
          '',
      color: j['color'] as String? ?? '',
      engineCc: _asNullableInt(j['engine_cc'] ?? j['engineCc']),
      locationArea:
          j['location_area'] as String? ?? j['locationArea'] as String? ?? '',
      sellerName:
          j['seller_name'] as String? ?? j['sellerName'] as String? ?? '',
      sellerPhone:
          j['seller_phone'] as String? ?? j['sellerPhone'] as String? ?? '',
      askingPricePkr:
          _asNullableInt(j['asking_price_pkr'] ?? j['askingPricePkr']),
      notes: j['notes'] as String?,
      imagePaths: imgs,
      createdAt: DateTime.tryParse(
            j['created_at'] as String? ?? j['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }

  static List<String> _imagesFromList(Object? raw) {
    final list = raw as List<dynamic>? ?? const [];
    return list.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }

  static int? _asNullableInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    return int.tryParse(raw.toString());
  }
}
