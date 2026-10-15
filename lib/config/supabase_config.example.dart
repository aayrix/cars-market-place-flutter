/// Copy this file to `supabase_config.dart` and paste your project
/// credentials.
///
/// Supabase dashboard → Project Settings → API → Project URL / publishable key
class SupabaseConfig {
  static const String url = 'https://YOUR-PROJECT-REF.supabase.co';
  static const String publishableKey = 'sb_publishable_...';

  static const String storageBucket = 'car-images';

  static bool get isConfigured =>
      url.startsWith('https://') &&
      url.contains('.supabase.co') &&
      (publishableKey.startsWith('sb_publishable_') ||
          publishableKey.startsWith('eyJ'));

  static const String setupHint =
      'Database is not configured yet. Open lib/config/supabase_config.dart '
      'and paste the Project URL and publishable key from '
      'Supabase → Project Settings → API.';
}
