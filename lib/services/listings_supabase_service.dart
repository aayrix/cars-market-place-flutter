import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/error_messages.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Reads and writes the `cars`, `car_images` tables and the `car-images`
/// storage bucket.
class ListingsSupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  String get _bucket => SupabaseConfig.storageBucket;

  Future<List<CarRow>> fetchCars() async {
    final rows = await _client
        .from('cars')
        .select()
        .order('created_at', ascending: false);

    final cars = List<Map<String, dynamic>>.from(rows);
    final carIds = cars.map((row) => '${row['id']}').toList();
    final imagesByCar = await _fetchImages(carIds);

    return cars.map((row) {
      final id = '${row['id']}';
      return CarRow(row: row, images: imagesByCar[id] ?? const <String>[]);
    }).toList();
  }

  Future<Map<String, List<String>>> _fetchImages(List<String> carIds) async {
    final map = <String, List<String>>{};
    // Keep each IN clause small enough for PostgREST URLs while avoiding a
    // full-table image scan when the marketplace contains many old photos.
    final batches = <Future<List<dynamic>>>[];
    for (var offset = 0; offset < carIds.length; offset += 100) {
      final end = (offset + 100).clamp(0, carIds.length);
      batches.add(_fetchImageBatch(carIds.sublist(offset, end)));
    }
    for (final rows in await Future.wait(batches)) {
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final carId = '${row['car_id'] ?? ''}';
        final url = '${row['image_url'] ?? ''}'.trim();
        if (carId.isEmpty || url.isEmpty) continue;
        map.putIfAbsent(carId, () => <String>[]).add(url);
      }
    }
    return map;
  }

  Future<List<dynamic>> _fetchImageBatch(List<String> carIds) async {
    try {
      return await _client
          .from('car_images')
          .select()
          .inFilter('car_id', carIds)
          .order('position', ascending: true);
    } on PostgrestException catch (e) {
      if (!_isMissingColumn(e)) rethrow;
      return _client
          .from('car_images')
          .select()
          .inFilter('car_id', carIds)
          .order('created_at', ascending: true);
    }
  }

  /// Uploads local device files to the `car-images` bucket and returns
  /// their public URLs plus the object paths (for cleanup/rollback).
  Future<List<UploadedImage>> uploadImages(
    String carId,
    List<String> paths,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError(
        'A valid Supabase sign-in session is required to upload images.',
      );
    }
    final carRows = await _client
        .from('cars')
        .select('id,seller_id')
        .eq('id', carId)
        .limit(1);
    final isAdmin = await _client.rpc<bool>('is_admin').catchError((_) => false);
    if (carRows.isEmpty ||
        (carRows.first['seller_id'] != user.id && isAdmin != true)) {
      throw StateError('The signed-in user does not own car $carId.');
    }

    final uploaded = <UploadedImage>[];
    try {
      for (var i = 0; i < paths.length; i++) {
        final entry = paths[i].trim();
        if (entry.isEmpty) continue;
        if (entry.startsWith('http://') || entry.startsWith('https://')) {
          uploaded.add(UploadedImage(url: entry, path: '', existing: true));
          continue;
        }
        uploaded.add(await _uploadOne(carId, entry, i));
      }
    } catch (_) {
      await _removeObjects(uploaded.map((e) => e.path).toList());
      rethrow;
    }
    return uploaded;
  }

  Future<UploadedImage> _uploadOne(
    String carId,
    String filePath,
    int index,
  ) async {
    if (kIsWeb) {
      throw StateError('Photos cannot be uploaded from this platform yet.');
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in again before uploading listing photos.');
    }
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('A selected photo is no longer on this device.');
    }

    final ext = _extensionOf(filePath);
    final objectPath =
        '$userId/cars/$carId/${DateTime.now().microsecondsSinceEpoch}_$index.$ext';

    await _client.storage
        .from(_bucket)
        .uploadBinary(
          objectPath,
          await file.readAsBytes(),
          fileOptions: FileOptions(contentType: _contentTypeFor(ext)),
        );

    return UploadedImage(
      url: _client.storage.from(_bucket).getPublicUrl(objectPath),
      path: objectPath,
    );
  }

  /// Inserts the car before upload so Storage RLS can check car ownership,
  /// then inserts image rows. Any failure rolls back the car and uploaded files.
  Future<String> createCar({
    required String carId,
    required Map<String, dynamic> data,
    required List<String> imagePaths,
  }) async {
    final payload = <String, dynamic>{...data, 'id': carId};
    final images = <UploadedImage>[];

    try {
      debugLog('[createCar] B. inserting into cars: $carId');
      await _client.from('cars').insert(payload);
      debugLog('[createCar] B. cars insert OK: $carId');
    } catch (e) {
      debugLog('[createCar] B. cars insert FAILED: $carId -> $e');
      rethrow;
    }

    try {
      debugLog('[createCar] C. uploading images for $carId');
      images.addAll(await uploadImages(carId, imagePaths));
      debugLog(
        '[createCar] C. storage upload OK for $carId: '
        '${images.map((e) => e.path).where((p) => p.isNotEmpty).toList()}',
      );
      debugLog('[createCar] D. inserting car_images for $carId');
      await _insertImageRows(carId, images);
      debugLog(
        '[createCar] D. car_images insert OK: $carId '
        '(${images.where((i) => i.url.isNotEmpty).length} rows)',
      );
    } catch (e) {
      debugLog('[createCar] D. car_images insert FAILED: $carId -> $e');
      await _removeObjects(images.map((e) => e.path).toList());
      await _deleteCarRow(carId);
      rethrow;
    }

    return carId;
  }

  Future<void> _insertImageRows(
    String carId,
    List<UploadedImage> images,
  ) async {
    final images2 = <UploadedImage>[
      for (final image in images)
        if (image.url.isNotEmpty) image,
    ];
    if (images2.isEmpty) return;

    try {
      await _client.from('car_images').insert([
        for (var i = 0; i < images2.length; i++)
          {
            'car_id': carId,
            'image_url': images2[i].url,
            'storage_path': images2[i].path,
            'position': i,
          },
      ]);
    } on PostgrestException catch (e) {
      if (!_isMissingColumn(e)) rethrow;

      // `position` / `storage_path` columns were not added yet. Insert one
      // row per statement so `created_at` preserves the chosen order.
      for (final image in images2) {
        await _client.from('car_images').insert({
          'car_id': carId,
          'image_url': image.url,
        });
      }
    }
  }

  bool _isMissingColumn(PostgrestException error) =>
      error.code == '42703' ||
      (error.code == 'PGRST204' &&
          (error.message.contains("'position'") ||
              error.message.contains("'storage_path'")));

  Future<void> updateCar(
    String carId,
    Map<String, dynamic> data,
    List<UploadedImage> images,
  ) async {
    await _client.from('cars').update(data).eq('id', carId);
    await _client.from('car_images').delete().eq('car_id', carId);
    await _insertImageRows(carId, images);
  }

  Future<void> deleteCar(String carId) async {
    final objectPaths = await _storagePathsFor(carId);
    await _removeObjects(objectPaths);
    await _client.from('cars').delete().eq('id', carId);
  }

  Future<List<String>> _storagePathsFor(String carId) async {
    try {
      final rows = await _client
          .from('car_images')
          .select()
          .eq('car_id', carId);
      final paths = <String>[];
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final stored = '${row['storage_path'] ?? ''}';
        if (stored.isNotEmpty) {
          paths.add(stored);
          continue;
        }
        final derived = pathFromPublicUrl('${row['image_url'] ?? ''}');
        if (derived != null) paths.add(derived);
      }
      return paths;
    } catch (e) {
      debugLog('Could not read image paths for $carId: $e');
      return const [];
    }
  }

  /// Recovers the bucket object path from a Supabase public URL so the
  /// object can be deleted even without a `storage_path` column.
  String? pathFromPublicUrl(String url) {
    const marker = '/storage/v1/object/public/';
    final start = url.indexOf(marker);
    if (start == -1) return null;
    final rest = url.substring(start + marker.length);
    final slash = rest.indexOf('/');
    if (slash == -1) return null;
    if (rest.substring(0, slash) != _bucket) return null;
    try {
      return Uri.decodeComponent(rest.substring(slash + 1));
    } on FormatException {
      return null;
    }
  }

  Future<void> _deleteCarRow(String carId) async {
    try {
      await _client.from('cars').delete().eq('id', carId);
    } catch (e) {
      debugLog('Rollback of car $carId failed: $e');
    }
  }

  Future<void> _removeObjects(List<String> paths) async {
    final targets = paths.where((v) => v.isNotEmpty).toList();
    if (targets.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(targets);
    } catch (e) {
      debugLog('Storage cleanup failed: $e');
    }
  }

  static String _extensionOf(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return ext.isEmpty ? 'jpg' : ext;
  }

  static String _contentTypeFor(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'avif' => 'image/avif',
    _ => 'image/jpeg',
  };
}

class CarRow {
  const CarRow({required this.row, required this.images});

  final Map<String, dynamic> row;
  final List<String> images;
}

class UploadedImage {
  const UploadedImage({
    required this.url,
    required this.path,
    this.existing = false,
  });

  final String url;
  final String path;
  final bool existing;
}
