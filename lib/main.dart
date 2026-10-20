import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'utils/error_messages.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/listings_provider.dart';
import 'providers/theme_settings.dart';
import 'services/auth_service.dart';
import 'services/listings_supabase_service.dart';
import 'services/profile_service.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase is initialized exactly once, with the project URL and
  // publishable key only — never a REST path and never a secret key.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: true,
      ),
    );
  } else {
    debugLog(SupabaseConfig.setupHint);
  }

  final auth = AuthProvider(AuthService(), ProfileService());
  final listings = ListingsProvider(
    ListingsSupabaseService(),
    profiles: ProfileService(),
  );
  final appearance = ThemeSettings();
  await appearance.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ListingsProvider>.value(value: listings),
        ChangeNotifierProvider<ThemeSettings>.value(value: appearance),
      ],
      child: const ApniGariApp(),
    ),
  );

  // Render Flutter immediately. Restore the session and fetch marketplace
  // data while the launch animation is playing instead of blocking first paint.
  unawaited(_initializeAppServices(auth, listings));
}

Future<void> _initializeAppServices(
  AuthProvider auth,
  ListingsProvider listings,
) async {
  try {
    await PushNotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugLog('Push initialization failed: $error\n$stackTrace');
  }

  try {
    await Future.wait([auth.init(), listings.init()]);
  } catch (error, stackTrace) {
    debugLog('App data initialization failed: $error\n$stackTrace');
  }
}
