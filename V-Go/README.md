# Scooter App (V-Go)

## iOS (App Store) build & release

### Bundle identifier (iOS)
- **iOS bundle id**: `com.scooterapp.vgo` (configured in `ios/Runner.xcodeproj/project.pbxproj`).

### Versioning
- **Source of truth**: `pubspec.yaml` → `version: x.y.z+build`
- iOS uses Flutter’s generated values in `ios/Runner/Info.plist`:
  - `CFBundleShortVersionString = $(FLUTTER_BUILD_NAME)`
  - `CFBundleVersion = $(FLUTTER_BUILD_NUMBER)`

### Environment configuration (production-safe)
Defaults are production, but you can override at build time:

- **REST API**: `--dart-define=API_BASE_URL=https://your-domain/api/`
- **SignalR base**: `--dart-define=SIGNALR_BASE_URL=https://your-domain`

Example:

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://www.vgo-eg.com/api/ \
  --dart-define=SIGNALR_BASE_URL=https://www.vgo-eg.com
```

### Firebase / Push Notifications (iOS)
This repo initializes Firebase via `lib/firebase_options.dart`, but iOS requires native setup:

1. **Add `GoogleService-Info.plist`**
   - Download it from Firebase Console for the **iOS app** with bundle id **`com.scooterapp.vgo`**.
   - Place it at `ios/Runner/GoogleService-Info.plist`.
   - In Xcode, ensure it is added to the **Runner** target.

2. **Enable capabilities in Xcode**
   - Runner target → *Signing & Capabilities*:
     - Add **Push Notifications**
     - Add **Background Modes** → check **Remote notifications**

3. **APNs in Firebase**
   - Upload APNs auth key (recommended) or certificates in Firebase Console.
   - Ensure the Firebase iOS app is linked to APNs.

### iOS permissions (Info.plist)
Configured in `ios/Runner/Info.plist`:
- Photo library (gallery picker)
- Location (maps / tracking)
- Background mode includes `remote-notification` for push support

### App Icons & Launch Screen
iOS is wired to use:
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` (includes 1024 marketing slot)
- `ios/Runner/Base.lproj/LaunchScreen.storyboard` + `LaunchImage` / `LaunchBackground` asset sets

**Important:** In this repo snapshot, the referenced `.png` files inside those asset catalogs are missing. Before uploading to App Store, add the required icon and launch images so every filename referenced in those `Contents.json` files exists on disk.

### Building from macOS (required for iOS)
You must build and Archive iOS from a Mac:

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```

### Xcode manual steps (before upload)
- Set the **Team** and signing in Xcode (use proper distribution signing for App Store).
- Confirm **bundle id** matches App Store Connect + Apple Developer App ID.
- Archive in Xcode (*Product → Archive*) and upload to App Store Connect.

## Android
Android remains configured via Gradle `debug`/`release` build types.

