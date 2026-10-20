/// Build with --dart-define=SUPABASE_URL=... and
/// --dart-define=SUPABASE_ANON_KEY=... (publishable/anon key only).
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String storageBucket = 'car-images';

  static bool get isConfigured =>
      url.startsWith('https://') &&
      url.contains('.supabase.co') &&
      (publishableKey.startsWith('sb_publishable_') ||
          publishableKey.startsWith('eyJ'));

  static const String setupHint =
      'App setup is incomplete. Please try again later.';
}
