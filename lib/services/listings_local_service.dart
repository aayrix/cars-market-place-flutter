import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/car_category.dart';
import '../models/car_listing.dart';

/// On-device listing store. No login or email required — works for everyone.
class ListingsLocalService {
  ListingsLocalService() {
    _initFuture = _loadFromDisk();
  }

  static const String _fileName = 'mianwali_wheels_listings.json';
  static const String _imagesSubdir = 'listing_images';
  static const String _localUserId = 'local-user';

  final Uuid _uuid = const Uuid();
  final StreamController<List<CarListing>> _streamController =
      StreamController<List<CarListing>>.broadcast();
  final List<CarListing> _items = <CarListing>[];
  late final Future<void> _initFuture;

  Stream<List<CarListing>> watchAll() {
    return Stream.fromFuture(_initFuture).asyncExpand((_) {
      return _streamController.stream.startWith(List<CarListing>.unmodifiable(_items));
    });
  }

  Future<void> createListing({
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
    await _initFuture;
    final permanentImages = <String>[];
    for (final path in pickedImagePaths) {
      permanentImages.add(await _persistImage(path));
    }

    final listing = CarListing(
      id: _uuid.v4(),
      sellerId: _localUserId,
      category: category,
      bodyType: bodyType,
      modelName: modelName,
      modelYear: modelYear,
      registrationNumber: registrationNumber,
      color: color,
      engineCc: engineCc,
      locationArea: locationArea,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      askingPricePkr: askingPricePkr,
      notes: notes,
      imagePaths: permanentImages,
      createdAt: DateTime.now(),
    );
    _items.insert(0, listing);
    await _saveToDisk();
    _emit();
  }

  Future<void> updateListing({
    required String listingId,
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
    required List<String> existingImageUrls,
    required List<String> newLocalImagePaths,
  }) async {
    await _initFuture;
    final index = _items.indexWhere((e) => e.id == listingId);
    if (index == -1) throw StateError('Listing not found.');
    final current = _items[index];
    if (current.sellerId != _localUserId) {
      throw StateError('You can only edit your own listings.');
    }

    final merged = <String>[...existingImageUrls];
    for (final path in newLocalImagePaths) {
      merged.add(await _persistImage(path));
    }

    _items[index] = CarListing(
      id: current.id,
      sellerId: current.sellerId,
      category: category,
      bodyType: bodyType,
      modelName: modelName,
      modelYear: modelYear,
      registrationNumber: registrationNumber,
      color: color,
      engineCc: engineCc,
      locationArea: locationArea,
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      askingPricePkr: askingPricePkr,
      notes: notes,
      imagePaths: merged,
      createdAt: current.createdAt,
    );
    await _saveToDisk();
    _emit();
  }

  Future<void> deleteListing(String listingId) async {
    await _initFuture;
    _items.removeWhere((e) => e.id == listingId && e.sellerId == _localUserId);
    await _saveToDisk();
    _emit();
  }

  Future<File> _jsonFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<Directory> _imagesDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final sub = Directory(p.join(dir.path, _imagesSubdir));
    if (!await sub.exists()) {
      await sub.create(recursive: true);
    }
    return sub;
  }

  Future<void> _loadFromDisk() async {
    final file = await _jsonFile();
    if (!await file.exists()) {
      _emit();
      return;
    }
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          list.map(
            (e) => CarListing.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    } catch (_) {
      _items.clear();
    }
    _emit();
  }

  Future<void> _saveToDisk() async {
    final file = await _jsonFile();
    final encoded = const JsonEncoder.withIndent('  ').convert(
      _items.map((e) => e.toJson()).toList(),
    );
    await file.writeAsString(encoded);
  }

  Future<String> _persistImage(String sourcePath) async {
    if (sourcePath.startsWith('http://') || sourcePath.startsWith('https://')) {
      return sourcePath;
    }
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;

    final imagesDir = await _imagesDirectory();
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final dest = p.join(imagesDir.path, '${_uuid.v4()}$ext');
    await source.copy(dest);
    return dest;
  }

  void _emit() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _streamController.add(List<CarListing>.unmodifiable(_items));
  }
}

extension<T> on Stream<T> {
  Stream<T> startWith(T initialValue) async* {
    yield initialValue;
    yield* this;
  }
}
