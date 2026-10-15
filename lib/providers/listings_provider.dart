import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../utils/error_messages.dart';
import '../models/car_category.dart';
import '../models/car_listing.dart';
import '../models/user_profile.dart';
import '../services/listings_supabase_service.dart';
import '../services/profile_service.dart';

class ListingsProvider extends ChangeNotifier {
  ListingsProvider(this._service, {required this.profiles});

  final ListingsSupabaseService _service;
  final ProfileService profiles;

  /// Test-only constructor with in-memory data and no backend.
  factory ListingsProvider.seeded(List<CarListing> items) {
    final provider = ListingsProvider(
      ListingsSupabaseService(),
      profiles: ProfileService(),
    );
    provider._items = List<CarListing>.of(items);
    provider._ready = true;
    return provider;
  }

  List<CarListing> _items = [];
  Map<String, UserProfile> _profilesById = {};
  bool _ready = false;
  bool _loading = false;
  String? _loadError;
  String? _profilesLoadError;
  final Map<String, Future<UserProfile?>> _sellerLookups = {};

  bool get isReady => _ready;
  bool get isLoading => _loading;
  bool get isConfigured => SupabaseConfig.isConfigured;

  /// Non-null when the last load failed (network / RLS / missing table).
  String? get loadError => _loadError;

  /// Profile lookup failures are kept separate from listing failures so the
  /// listing can still be shown while making missing seller details visible.
  String? get profilesLoadError => _profilesLoadError;

  String? get setupMessage =>
      SupabaseConfig.isConfigured ? null : SupabaseConfig.setupHint;

  List<CarListing> get listings => List.unmodifiable(_items);

  List<CarListing> byCategory(CarCategory c) =>
      _items.where((e) => e.category == c).toList();

  CarListing? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Cars owned by [userId] — always the authenticated Supabase id.
  List<CarListing> mineFor(String? userId) {
    if (userId == null || userId.isEmpty) return const [];
    return _items.where((e) => e.sellerId == userId).toList();
  }

  /// Resolves the seller of a car from the `profiles` table.
  UserProfile? sellerOf(CarListing listing) {
    final id = listing.sellerId;
    if (id == null) return null;
    return _profilesById[id];
  }

  /// Loads a seller profile on demand when the bulk listing refresh did not
  /// return it. This keeps contact details available on the listing page.
  Future<UserProfile?> fetchSellerProfile(CarListing listing) async {
    final sellerId = listing.sellerId;
    if (sellerId == null || sellerId.isEmpty) return null;
    final cached = _profilesById[sellerId];
    if (cached != null) return cached;
    final inFlight = _sellerLookups[sellerId];
    if (inFlight != null) return inFlight;

    final lookup = () async {
      try {
        final profilesById = await profiles.fetchForUsers([sellerId]);
        final profile = profilesById[sellerId];
        if (profile != null) _profilesById[sellerId] = profile;
        _profilesLoadError = null;
        notifyListeners();
        return profile;
      } catch (error) {
        debugLog('Seller profile lookup failed for $sellerId: $error');
        _profilesLoadError = ErrorMessages.from(error);
        notifyListeners();
        return null;
      } finally {
        _sellerLookups.remove(sellerId);
      }
    }();
    _sellerLookups[sellerId] = lookup;
    return lookup;
  }

  /// Keeps the current seller's listing cards in sync after profile edits.
  void updateSellerProfile(UserProfile profile) {
    if (!_profilesById.containsKey(profile.id)) return;
    _profilesById[profile.id] = profile;
    notifyListeners();
  }

  Future<void> init() => loadListings();

  Future<void> loadListings() async {
    if (!SupabaseConfig.isConfigured) {
      _items = [];
      _profilesById = {};
      _profilesLoadError = null;
      _ready = true;
      _loadError = null;
      notifyListeners();
      return;
    }

    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      final rows = await _service.fetchCars();
      _items = rows
          .map((r) => CarListing.fromRow(r.row, images: r.images))
          .toList();
      _loadError = null;
      try {
        final sellerIds = _items
            .map((listing) => listing.sellerId)
            .whereType<String>()
            .toSet();
        _profilesById = await profiles.fetchForUsers(sellerIds);
        _profilesLoadError = null;
      } catch (e) {
        debugLog('Profiles load failed: $e');
        _profilesLoadError = ErrorMessages.from(e);
      }
    } catch (e) {
      debugLog('Load error: $e');
      _items = [];
      _loadError = ErrorMessages.from(e);
    } finally {
      _loading = false;
      _ready = true;
      notifyListeners();
    }
  }

  Future<String?> addCar({
    required String sellerId,
    required CarCategory category,
    required String brand,
    required String model,
    int? year,
    int? price,
    int? mileage,
    int? engineCc,
    String? bikeType,
    String? variant,
    required String fuel,
    required String transmission,
    String? description,
    required String city,
    required List<String> pickedImagePaths,
  }) async {
    if (!SupabaseConfig.isConfigured) return SupabaseConfig.setupHint;
    if (pickedImagePaths.length > 4) {
      return 'A car listing can have up to 4 pictures.';
    }
    if (sellerId.isEmpty) {
      return 'Sign in to post a car.';
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || currentUser.id != sellerId) {
      return 'Your sign-in session is unavailable. Sign in again to post a car.';
    }

    final carId = const Uuid().v4();
    // Insert the owner-bound car first. Storage RLS can then verify that the
    // first object path segment is a car owned by auth.uid().
    try {
      await _service.createCar(
        carId: carId,
        data: {
          'seller_id': sellerId,
          'category': category.name,
          'brand': brand,
          'model': model,
          'year': year,
          'price': price,
          'mileage': mileage,
          'engine_cc': engineCc,
          'bike_type': bikeType,
          'variant': variant,
          'fuel': fuel,
          'transmission': transmission,
          'description': description,
          'city': city,
        },
        imagePaths: pickedImagePaths,
      );
      debugLog('[addCar] B/C/D. car, images + car_images saved for $carId');
    } catch (e) {
      return _operationError(
        'B/C/D. car insert, storage upload + car_images',
        e,
      );
    }

    try {
      await loadListings();
    } catch (e) {
      debugLog('[addCar] Non-fatal: reload after insert failed: $e');
    }
    return null;
  }

  /// Logs technical detail in debug builds and returns a safe user message.
  String? _operationError(String operation, Object error) {
    final real = _describeSupabaseError(error);
    debugLog('[addCar] FAILED at $operation\n  $real');
    return _friendlyError(error);
  }

  /// Expands Postgrest / Storage errors into their raw fields the client
  /// actually received from Supabase.
  String _describeSupabaseError(Object error) {
    if (error is PostgrestException) {
      return 'SUPABASE PostgrestException: message="${error.message}" '
          'code=${error.code} details=${error.details} hint=${error.hint}';
    }
    if (error is StorageException) {
      return 'SUPABASE StorageException: message="${error.message}" '
          'statusCode=${error.statusCode} error=${error.error} '
          '(bucket="${SupabaseConfig.storageBucket}")';
    }
    return 'ERROR: ${error.runtimeType}: $error';
  }

  Future<String?> updateCar({
    required CarListing editing,
    required CarCategory category,
    required String brand,
    required String model,
    int? year,
    int? price,
    int? mileage,
    int? engineCc,
    String? bikeType,
    String? variant,
    required String fuel,
    required String transmission,
    String? description,
    required String city,
    required List<String> retainedImageUrls,
    required List<String> newLocalPaths,
  }) async {
    if (!SupabaseConfig.isConfigured) return SupabaseConfig.setupHint;
    if (retainedImageUrls.length + newLocalPaths.length > 4) {
      return 'A car listing can have up to 4 pictures.';
    }

    // C. New storage uploads.
    List<UploadedImage> newImages;
    try {
      newImages = await _service.uploadImages(editing.id, newLocalPaths);
    } catch (e) {
      return _operationError('C. storage upload (edit)', e);
    }
    final images = <UploadedImage>[
      ...retainedImageUrls
          .where((u) => u.trim().isNotEmpty)
          .map((u) => UploadedImage(url: u.trim(), path: '')),
      ...newImages,
    ];

    // B. cars UPDATE (+ D. car_images rewrite).
    try {
      await _service.updateCar(editing.id, {
        'category': category.name,
        'brand': brand,
        'model': model,
        'year': year,
        'price': price,
        'mileage': mileage,
        'engine_cc': engineCc,
        'bike_type': bikeType,
        'variant': variant,
        'fuel': fuel,
        'transmission': transmission,
        'description': description,
        'city': city,
      }, images);
    } catch (e) {
      return _operationError('B/D. cars update + car_images rewrite', e);
    }

    try {
      await loadListings();
    } catch (e) {
      debugLog('[updateCar] Non-fatal: reload after update failed: $e');
    }
    return null;
  }

  Future<String?> deleteCar(String id) async {
    if (!SupabaseConfig.isConfigured) return SupabaseConfig.setupHint;
    try {
      await _service.deleteCar(id);
      await loadListings();
      return null;
    } catch (e) {
      return _operationError('delete car', e);
    }
  }

  String? _friendlyError(Object error) => ErrorMessages.from(error);
}
