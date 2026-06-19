# mianwali_wheels

Peer-to-peer car marketplace app for Mianwali, Pakistan.

## Local mode

No login, email, or Google account is required. Anyone can open the app and start browsing or posting cars immediately. Listings are saved on the device.

### Run on Android

```bash
flutter pub get
flutter run
```

### Run on Linux desktop

Ubuntu/Debian may be missing `ld` in `/usr/lib/llvm-21/bin`. Either install the linker:

```bash
sudo apt install lld-21
flutter run -d linux
```

Or use the included shim (no sudo):

```bash
chmod +x run_linux.sh
./run_linux.sh
```

### Run in Chrome (web)

```bash
flutter run -d chrome
```
