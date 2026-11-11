# Release

## Before the first build that leaves your machine
- [x] Application ID / bundle ID: `com.engleazia.app` (Android `namespace` and `applicationId`, iOS
      `PRODUCT_BUNDLE_IDENTIFIER`). It cannot change after the first store upload.
- [ ] App icon and splash generated from one source (`flutter_launcher_icons`, `flutter_native_splash`).
- [ ] Crash reporter chosen and wired into `AppLogger.reporter` (provider must work for users in Syria).
- [ ] `env/prod.json` has the real `BASE_URL`.

## Google sign-in (once, then per signing key)
In the app's Google Cloud project (one project for every client):
1. Google Auth Platform → Branding (name, support email, logo, links to the privacy policy and the terms),
   Audience: External, and **In production** before testers outside the test list sign in. Data access:
   `openid`, `email`, `profile` only.
2. Clients:
   - **Web application** (no redirect URIs): its ID is `GOOGLE_SERVER_CLIENT_ID` in `env/<env>.json`, and the
     backend checks tokens against the same ID. Its secret is not needed anywhere.
   The project is `engleazia`; the Web, iOS and one debug-key Android client exist (STATUS D-110).
   - **Android**, package `com.engleazia.app`, one client per signing key's SHA-1: each developer's debug key
     (`cd android && ./gradlew signingReport`), the upload key, and Play App Signing's key (Play Console → App
     integrity, after the first upload). A missing one makes Google's sheet close as if it were canceled.
   - **iOS**, bundle ID `com.engleazia.app`: its ID is `GOOGLE_IOS_CLIENT_ID`, and its reversed ID
     (`com.googleusercontent.apps.…`) goes in `ios/Runner/Info.plist` as a `CFBundleURLTypes` URL scheme.
3. Sign in on a phone against each environment's server before a build leaves your machine.

## Android signing (once)
1. Create an upload keystore **outside the repo** and back it up off-machine:
   ```
   keytool -genkey -v -keystore C:/keys/engleazia-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/key.properties.example` to `android/key.properties` (gitignored) and fill it in.
3. Enroll in Play App Signing on the first upload.

Without `key.properties`, release builds are signed with the debug key — fine locally, rejected by the Play Store.

## iOS (needs a Mac — do one build in week one)
- Localized home-screen name: add `InfoPlist.strings` to the Runner target in Xcode with
  `CFBundleDisplayName = "إنجليزيا";` (ar) and `"Engleazia"` (en). `CFBundleLocalizations` is already set.
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
