# Release

## Before the first build that leaves your machine
- [ ] Final application ID / bundle ID (currently the provisional `com.example.englizia`). Change in
      `android/app/build.gradle.kts` (`namespace`, `applicationId`), move `MainActivity.kt` to the new package,
      and set `PRODUCT_BUNDLE_IDENTIFIER` in Xcode. It cannot change after the first store upload.
- [ ] App icon and splash generated from one source (`flutter_launcher_icons`, `flutter_native_splash`).
- [ ] Crash reporter chosen and wired into `AppLogger.reporter` (provider must work for users in Syria).
- [ ] `env/prod.json` has the real `BASE_URL`.

## Android signing (once)
1. Create an upload keystore **outside the repo** and back it up off-machine:
   ```
   keytool -genkey -v -keystore C:/keys/englizia-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/key.properties.example` to `android/key.properties` (gitignored) and fill it in.
3. Enroll in Play App Signing on the first upload.

Without `key.properties`, release builds are signed with the debug key — fine locally, rejected by the Play Store.

## iOS (needs a Mac — do one build in week one)
- Localized home-screen name: add `InfoPlist.strings` to the Runner target in Xcode with
  `CFBundleDisplayName = "إنجليزيا";` (ar) and `"Englizia"` (en). `CFBundleLocalizations` is already set.
- Check every permission purpose string (microphone for shadowing/conversation from v0.4).

## Build
Bump `version:` in `pubspec.yaml` (`X.Y.Z+N`, N increases on every distributed build), then:
```
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env/prod.json
flutter build ipa --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env/prod.json
```
- Upload `build/symbols` to the crash reporter.
- Tag the commit: `git tag vX.Y.Z` and move `Unreleased` entries in `CHANGELOG.md` under the new version.

## Store compliance (before the first public upload)
- [ ] In-app account deletion (v1.0) + web deletion URL for Play.
- [ ] Privacy Policy and Terms reachable in-app and before sign-up.
- [ ] Accurate, localized purpose strings for every permission.
- [ ] Play Data safety form matches what is actually collected.
- [ ] Open-source licenses screen (`showLicensePage`).
- [ ] Written permission from the Emar series rights holder before publishing that track.
