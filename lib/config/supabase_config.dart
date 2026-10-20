/// Supabase client configuration is supplied at build time with --dart-define.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String storageBucket = 'car-images';

  /// Must match the Android application ID and the URL allow-listed in
  /// Supabase Authentication → URL Configuration → Redirect URLs.
  static const String authRedirectUrl =
      'com.apnigari.one://login-callback/';

  static bool get isConfigured =>
      url.startsWith('https://') &&
      url.contains('.supabase.co') &&
      (publishableKey.startsWith('sb_publishable_') ||
          publishableKey.startsWith('eyJ'));

  static const String setupHint =
      'App setup is incomplete. Please try again later.';
}
