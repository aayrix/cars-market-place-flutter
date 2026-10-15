enum CarCategory { sedan, suv, hatchback, pickup, motorcycle }

extension CarCategoryX on CarCategory {
  String get label {
    switch (this) {
      case CarCategory.sedan:
        return 'Sedan';
      case CarCategory.suv:
        return 'SUV';
      case CarCategory.hatchback:
        return 'Hatchback';
      case CarCategory.pickup:
        return 'Pickup';
      case CarCategory.motorcycle:
        return 'Motorcycle';
    }
  }

  String get assetHint {
    switch (this) {
      case CarCategory.sedan:
        return 'Comfortable saloons & executive sedans';
      case CarCategory.suv:
        return 'Family SUVs & crossovers';
      case CarCategory.hatchback:
        return 'Compact city hatchbacks';
      case CarCategory.pickup:
        return 'Pickup trucks for utility and off-road use';
      case CarCategory.motorcycle:
        return 'Motorbikes, scooters and electric two-wheelers';
    }
  }
}

CarCategory? carCategoryFromString(String? raw) {
  final v = raw?.toLowerCase().trim();
  for (final c in CarCategory.values) {
    if (c.name == v) return c;
  }
  return null;
}
