# Changelog

## 1.0.0 release groundwork

- Enabled Android R8 and resource shrinking; added Flutter/Agora/Firebase/Supabase keep rules and Android release build guidance.
- Disabled video call initiation and configured Agora call joining for microphone audio only.
- Added reporting and blocking UI plus `reports` and `blocked_users` RLS-backed tables. Reports and the admin review query are in the trust/safety migration.
- Added listing status/moderation fields, listing validation and duplicate warnings, owner “Mark as sold”, 60-day expiration, and a database-enforced three-listings-per-day limit for unverified users.
- Added SMS phone verification, verified seller badges, dealer profiles, featured listings, and pending boost requests with manual payment instructions.
- Moved Supabase project URL and publishable/anon key to `--dart-define`, added privacy and terms links, and removed any phone-state permission (none was present).

## Manual configuration

1. Apply `supabase/migrations/202610200001_trust_safety.sql` through `202610200004_voice_only.sql` in order. These migrations assume the existing `cars`, `profiles`, `chat_threads`, and `chat_messages` tables from the project's current Supabase setup. Run the admin review query in the trust migration from the Supabase SQL editor. Configure a scheduled `pg_cron` extension if listing expiration should run automatically; the migration schedules the job when `pg_cron` is already enabled.
2. Enable Phone provider/SMS delivery and configure an SMS provider in Supabase Authentication. Verify the phone change flow on a test account.
3. Replace the placeholder policy URLs with published legal pages at `https://apnigari.online/privacy` and `/terms`.
4. Build with `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Use only the project URL and anon/publishable client key; never add a `service_role` key to the app.
5. Configure the Android upload keystore in `android/key.properties`, add the final Firebase Android configuration, and complete Play Console app signing, Data safety, privacy policy, and target SDK declarations before publishing.
6. Play release command: `flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Sideload APK command: `flutter build apk --release --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.

The reported starting APK size is 99 MB. I did not produce a signed release artifact here, so the after-size has not been measured. ABI splits reduce each sideload APK to the matching architecture; R8 does not remove Agora native code, and the current Flutter Agora package uses a unified native RTC engine rather than separate optional feature `.so` files. A like-for-like release build is needed to report the final size.
