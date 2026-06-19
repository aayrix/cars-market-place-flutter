import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'providers/listings_provider.dart';
import 'services/listings_supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.anonKey.contains('PASTE_YOUR')) {
    debugPrint(
      'Set your Supabase anon key in lib/config/supabase_config.dart',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final listings = ListingsProvider(ListingsSupabaseService());

  try {
    await listings.init();
  } catch (e, st) {
    debugPrint('Listings init failed: $e\n$st');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: listings),
      ],
      child: const MianwaliWheelsApp(),
    ),
  );
}
