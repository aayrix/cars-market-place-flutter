// Integration test against the LIVE Supabase project.
//
// Runs read-only queries plus one intentionally-rejected write to prove RLS
// is enforced. Requires network access.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:apni_gari/config/supabase_config.dart';
import 'package:apni_gari/services/auth_service.dart';
import 'package:apni_gari/models/car_listing.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_test's TestWidgetsFlutterBinding installs a mock HttpClient that
  // always answers 400 so unit tests cannot hit the network. This test talks
  // to the real project, so restore the real client.
  HttpOverrides.global = null;

  setUpAll(() async {
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
  });

  test('Supabase is initialised once, with a project URL (not a REST path)',
      () async {
    // The URL handed to Supabase.initialize must be the project root.
    expect(SupabaseConfig.url, contains('.supabase.co'));
    expect(SupabaseConfig.url, isNot(contains('/rest/v1/')));
    expect(SupabaseConfig.publishableKey.startsWith('sb_publishable_'), isTrue);

    // Initialisation happened exactly once and the client is live.
    final client = Supabase.instance.client;
    expect(identical(Supabase.instance.client, client), isTrue);
    final rows = await client.from('cars').select().limit(1);
    expect(rows, isA<List<dynamic>>());
  });

  test('cars table is reachable and the marketplace can load real cars',
      () async {
    final rows = await ListingsSupabaseService().fetchCars();

    expect(rows, isNotEmpty, reason: 'Expected at least one car in `cars`');

    final first = rows.first;
    final car = CarListing.fromRow(first.row, images: first.images);

    expect(car.id, isNotEmpty);
    expect(car.brand, isNotEmpty, reason: 'brand must be populated');
    expect(car.model, isNotEmpty, reason: 'model must be populated');
    expect(car.city, isNotEmpty, reason: 'city must be populated');
    expect(car.title, contains(car.brand));
  });

  test('the known seed car loads with its real column values', () async {
    final rows = await ListingsSupabaseService().fetchCars();
    final corolla = rows
        .map((r) => CarListing.fromRow(r.row, images: r.images))
        .where((c) => c.brand == 'Toyota' && c.model == 'Corolla')
        .toList();

    expect(corolla, isNotEmpty, reason: 'Seed Toyota Corolla should exist');

    final car = corolla.first;
    expect(car.year, 2022);
    expect(car.price, 5500000);
    expect(car.mileage, 35000);
    expect(car.fuel, 'Petrol');
    expect(car.transmission, 'Automatic');
    expect(car.sellerId, isNotNull, reason: 'seller_id must come from auth');
    expect(car.description, isNotEmpty);
  });

  test('profiles are readable: full_name, phone and city', () async {
    final profiles = await ProfileService().fetchAll();

    expect(profiles, isNotEmpty, reason: 'Expected at least one profile');

    final profile = profiles.values.first;
    expect(profile.id, isNotEmpty);
    expect(profile.fullName, isNotEmpty);
    expect(profile.phone, isNotEmpty);
    expect(profile.city, isNotEmpty);
  });

  test('a car can be resolved to its seller profile', () async {
    final rows = await ListingsSupabaseService().fetchCars();
    final car = CarListing.fromRow(rows.first.row, images: rows.first.images);
    final profiles = await ProfileService().fetchAll();

    expect(car.sellerId, isNotNull);
    expect(
      profiles[car.sellerId!],
      isNotNull,
      reason: 'seller_id must reference an existing profile row',
    );
  });

  test('car_images rows are readable and keyed by car_id', () async {
    final rows = await Supabase.instance.client
        .from('car_images')
        .select()
        .limit(50);

    final images = List<Map<String, dynamic>>.from(rows);
    for (final row in images) {
      expect(row['car_id'], isNotNull, reason: 'car_id must not be null');
      expect('${row['image_url']}', isNotEmpty);
    }
  });

  test('RLS blocks an unauthenticated car insert (no forged seller_id)',
      () async {
    var rejected = false;
    try {
      await Supabase.instance.client.from('cars').insert({
        'brand': 'RLS',
        'model': 'should-fail',
        'city': 'Mianwali',
        'seller_id': '00000000-0000-0000-0000-000000000000',
      });
    } on PostgrestException catch (e) {
      rejected = true;
      expect(e.code, '42501');
      expect(e.message, contains('row-level security'));
    }

    expect(
      rejected,
      isTrue,
      reason: 'RLS must reject writes from an unauthenticated client',
    );
  });

  test('RLS blocks an unauthenticated profile insert', () async {
    var rejected = false;
    try {
      await Supabase.instance.client.from('profiles').insert({
        'id': '00000000-0000-0000-0000-0000000000ff',
        'full_name': 'should-fail',
      });
    } on PostgrestException catch (e) {
      rejected = true;
      expect(e.code, '42501');
    }
    expect(rejected, isTrue);
  });

  test('Supabase Auth is reachable: bad credentials are rejected', () async {
    var rejected = false;
    try {
      await AuthService().signIn(
        email: 'no-such-user@example.com',
        password: 'WrongPass123!',
      );
    } on AuthException catch (e) {
      rejected = true;
      expect(e.message, isNotEmpty, reason: 'Server must explain the failure');
      expect(
        e.message.toLowerCase(),
        contains('invalid login credentials'),
        reason: 'Unexpected auth failure: ${e.message}',
      );
    }

    expect(rejected, isTrue, reason: 'Auth API must reject bad credentials');
    expect(
      AuthService().currentUser,
      isNull,
      reason: 'A failed sign-in must leave the app signed out',
    );
  });

  test('storage: the configured bucket exists (upload probe)', () async {
    // listBuckets() needs privileges the publishable key does not have and
    // answers [] even when buckets exist, so probe the bucket the app
    // actually uses instead. A missing bucket answers "Bucket not found";
    // an existing one is stopped by RLS before anything is written.
    expect(SupabaseConfig.storageBucket, 'car-images');

    Object? error;
    try {
      await Supabase.instance.client.storage
          .from(SupabaseConfig.storageBucket)
          .uploadBinary(
            '__bucket_probe__.txt',
            utf8.encode('bucket-existence-probe'),
            fileOptions: const FileOptions(contentType: 'text/plain'),
          );
    } catch (e) {
      error = e;
    }

    if (error == null) {
      await Supabase.instance.client.storage
          .from(SupabaseConfig.storageBucket)
          .remove(['__bucket_probe__.txt']);
      fail(
        'An anonymous upload to ${SupabaseConfig.storageBucket} succeeded — '
        'storage policies must restrict writes to signed-in users.',
      );
    }

    final msg = '$error';
    expect(
      msg,
      isNot(contains('Bucket not found')),
      reason:
          'Bucket "${SupabaseConfig.storageBucket}" does not exist. Create it '
          'once in Storage (or run supabase/schema.sql). Probe said: $msg',
    );
    expect(
      msg,
      contains('row-level security'),
      reason:
          'Expected the upload to be blocked by RLS, got instead: $msg',
    );
  });
}
