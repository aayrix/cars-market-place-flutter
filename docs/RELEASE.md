# Android release builds

Build the Play Store artifact with:

```sh
flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

For sideloadable, ABI-specific APKs, use:

```sh
flutter build apk --release --split-per-abi --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Configure `android/key.properties` and the upload keystore before release. APK
size depends on ABI; compare generated artifacts for the same ABI. The Agora
Flutter SDK bundles its voice engine in a native library, so excluding feature
libraries without inspecting the resolved SDK package risks breaking calls.
