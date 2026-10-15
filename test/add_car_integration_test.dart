// End-to-end "Add Car" tests against the LIVE Supabase project.
//
// Add Car requires a signed-in user (RLS pins seller_id to auth.uid()), so
// these tests need a real account:
//
//   SUPABASE_TEST_EMAIL=you@example.com \
//   SUPABASE_TEST_PASSWORD=... \
//   flutter test test/add_car_integration_test.dart
//
// Every car is created with a unique marker brand and removed again in
// tearDown, so the `cars` table is left exactly as it was found.

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:apni_gari/config/supabase_config.dart';
import 'package:apni_gari/models/car_category.dart';
import 'package:apni_gari/providers/listings_provider.dart';
import 'package:apni_gari/services/auth_service.dart';
import 'package:apni_gari/services/listings_supabase_service.dart';
import 'package:apni_gari/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _data[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _data.remove(key);
  }
}

SupabaseClient get client => Supabase.instance.client;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_test installs a mock HttpClient that always answers 400; these
  // tests talk to the real project, so restore the real client.
  HttpOverrides.global = null;

  final email = Platform.environment['SUPABASE_TEST_EMAIL'];  final password = Platform.environment['SUPABASE_TEST_PASSWORD'];
  final hasCreds =
      email != null && email.isNotEmpty && password != null && password.isNotEmpty;
  final skip = hasCreds
      ? false
      : 'Set SUPABASE_TEST_EMAIL and SUPABASE_TEST_PASSWORD to run the '
          'end-to-end Add Car tests.';

  final service = ListingsSupabaseService();
  final provider = ListingsProvider(service, profiles: ProfileService());
  final createdCarIds = <String>[];
  final tempDirs = <Directory>[];

  Future<void> cleanup(String carId) async {
    try {
      final rows = await client.from('car_images').select().eq('car_id', carId);
      final paths = <String>[];
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final stored = '${row['storage_path'] ?? ''}';
        if (stored.isNotEmpty) {
          paths.add(stored);
        } else {
          final derived =
              service.pathFromPublicUrl('${row['image_url'] ?? ''}');
          if (derived != null) paths.add(derived);
        }
      }
      // Image rows first: their RLS check requires the car to still exist.
      await client.from('car_images').delete().eq('car_id', carId);
      await client.from('cars').delete().eq('id', carId);
      if (paths.isNotEmpty) {
        await client.storage.from(SupabaseConfig.storageBucket).remove(paths);
      }
    } catch (e) {
      debugPrint('Cleanup of $carId failed: $e');
    }
  }

  setUpAll(() async {
    if (!hasCreds) return;
    expect(
      SupabaseConfig.isConfigured,
      isTrue,
      reason: 'SupabaseConfig must be filled in before running this test.',
    );

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAsyncStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );

    await AuthService().signIn(email: email, password: password);
    expect(
      AuthService().currentUserId,
      isNotNull,
      reason: 'The test account must sign in successfully.',
    );
  });

  tearDownAll(() async {
    for (final carId in List<String>.of(createdCarIds)) {
      await cleanup(carId);
    }
    for (final dir in tempDirs) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    if (hasCreds) {
      try {
        await AuthService().signOut();
      } catch (_) {}
    }
  });

  test(
    'Add Car WITHOUT images: row lands in cars with its category',
    () async {
      final marker = 'ZZNoImg${DateTime.now().millisecondsSinceEpoch}';

      final error = await provider.addCar(
        sellerId: AuthService().currentUserId!,
        category: CarCategory.suv,
        brand: marker,
        model: 'VerifyNoImg',
        year: 2020,
        price: 1234567,
        mileage: 42000,
        fuel: 'Petrol',
        transmission: 'Manual',
        description: 'Add Car verification without images.',
        city: 'Mianwali',
        pickedImagePaths: const <String>[],
      );

      expect(error, isNull, reason: 'Add Car without images failed: $error');

      final rows =
          await client.from('cars').select().eq('brand', marker);
      expect(rows, hasLength(1), reason: 'The new car must appear in `cars`');

      final row = Map<String, dynamic>.from(rows.first as Map);
      createdCarIds.add('${row['id']}');
      expect(row['category'], 'suv', reason: 'category must be saved');
      expect(row['model'], 'VerifyNoImg');
      expect(row['seller_id'], AuthService().currentUserId);

      // The provider's own reload must see it too (this is what the UI shows).
      expect(
        provider.listings.any((c) => c.brand == marker),
        isTrue,
        reason: 'loadListings() must return the new car',
      );
      expect(
        provider.listings.firstWhere((c) => c.brand == marker).category,
        CarCategory.suv,
        reason: 'the UI model must round-trip the category',
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'Add Car WITH images: uploads to the existing bucket, rows in car_images, '
    'photo publicly displayable',
    () async {
      final marker = 'ZZWithImg${DateTime.now().millisecondsSinceEpoch}';

      // Storage stores bytes as-is; a small JPEG header is enough.
      final dir = await Directory.systemTemp.createTemp('mw_add_car_');
      tempDirs.add(dir);
      final file = File('${dir.path}/verify.jpg');
      await file.writeAsBytes(<int>[
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
        0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
      ]);

      final error = await provider.addCar(
        sellerId: AuthService().currentUserId!,
        category: CarCategory.hatchback,
        brand: marker,
        model: 'VerifyWithImg',
        year: 2021,
        price: 2345678,
        mileage: 21000,
        fuel: 'Diesel',
        transmission: 'Automatic',
        description: 'Add Car verification with one image.',
        city: 'Mianwali',
        pickedImagePaths: <String>[file.path],
      );

      expect(error, isNull, reason: 'Add Car with images failed: $error');

      final rows = await client.from('cars').select().eq('brand', marker);
      expect(rows, hasLength(1), reason: 'The new car must appear in `cars`');
      final carId = '${(rows.first as Map)['id']}';
      createdCarIds.add(carId);
      expect((rows.first as Map)['category'], 'hatchback');

      final images =
          await client.from('car_images').select().eq('car_id', carId);
      expect(images, hasLength(1), reason: 'car_images must hold the photo');
      final image = Map<String, dynamic>.from(images.first as Map);
      expect(image['image_url'], isNotEmpty);
      expect(
        image['storage_path'],
        isNotEmpty,
        reason:
            'car_images.storage_path column is missing — run supabase/schema.sql',
      );
      expect(image['position'], 0);

      // The object really lives in the existing bucket and is served
      // publicly (bucket must be public for getPublicUrl to work).
      final url = '${image['image_url']}';
      expect(url, contains('/storage/v1/object/public/car-images/'));

      final httpClient = HttpClient();
      try {
        final response =
            await httpClient.getUrl(Uri.parse(url)).then((r) => r.close());
        expect(
          response.statusCode,
          200,
          reason: 'Public photo URL must return 200 so the app can display it '
              '(bucket must be marked public). Got ${response.statusCode}',
        );
        await response.drain<void>();
      } finally {
        httpClient.close(force: true);
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
