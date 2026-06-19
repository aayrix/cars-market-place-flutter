import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../models/car_category.dart';
import '../models/car_listing.dart';
import '../services/listings_supabase_service.dart';

class ListingsProvider extends ChangeNotifier {
  ListingsProvider(this._service);

  final ListingsSupabaseService _service;

  List<CarListing> _items = [];
  bool _ready = false;

  bool get isReady => _ready;

  List<CarListing> get listings => List.unmodifiable(_items);

  List<CarListing> byCategory(CarCategory c) =>
      _items.where((e) => e.category == c).toList();

  CarListing? byId(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    await loadListings();
  }

  String? _friendlyError(Object error) {
    final msg = error.toString();
    if (!SupabaseConfig.isConfigured ||
        msg.contains('Invalid API key') ||
        msg.contains('401')) {
      return SupabaseConfig.setupHint;
    }
    return msg;
  }

  Future<void> loadListings() async {
    if (!SupabaseConfig.isConfigured) {
      _items = [];
      _ready = true;
      notifyListeners();
      return;
    }

    try {
      final data = await _service.fetchListings();

      _items = data.map((e) => CarListing.fromJson(e)).toList();

      _ready = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Load error: $e');
      _items = [];
      _ready = true;
      notifyListeners();
    }
  }

  Future<String?> addListing({
    required CarCategory category,
    required String bodyType,
    required String modelName,
    int? modelYear,
    required String registrationNumber,
    required String color,
    int? engineCc,
    required String locationArea,
    required String sellerName,
    required String sellerPhone,
    int? askingPricePkr,
    String? notes,
    required List<String> pickedImagePaths,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return SupabaseConfig.setupHint;
    }

    try {
      await _service.addListing({
        'seller_id': 'local-user',
        'category': category.name,
        'body_type': bodyType,
        'model_name': modelName,
        'model_year': modelYear,
        'registration_number': registrationNumber,
        'color': color,
        'engine_cc': engineCc,
        'location_area': locationArea,
        'seller_name': sellerName,
        'seller_phone': sellerPhone,
        'asking_price_pkr': askingPricePkr,
        'notes': notes,
        'images': pickedImagePaths,
      });

      await loadListings();
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> updateListing({
    required CarListing editing,
    required CarCategory category,
    required String bodyType,
    required String modelName,
    int? modelYear,
    required String registrationNumber,
    required String color,
    int? engineCc,
    required String locationArea,
    required String sellerName,
    required String sellerPhone,
    int? askingPricePkr,
    String? notes,
    required List<String> retainedImageUrls,
    required List<String> newLocalPaths,
  }) async {
    try {
      await _service.updateListing(editing.id, {
        'category': category.name,
        'body_type': bodyType,
        'model_name': modelName,
        'model_year': modelYear,
        'registration_number': registrationNumber,
        'color': color,
        'engine_cc': engineCc,
        'location_area': locationArea,
        'seller_name': sellerName,
        'seller_phone': sellerPhone,
        'asking_price_pkr': askingPricePkr,
        'notes': notes,
        'images': [...retainedImageUrls, ...newLocalPaths],
      });

      await loadListings();
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> deleteListing(String id) async {
    try {
      await _service.deleteListing(id);
      await loadListings();
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }
}
