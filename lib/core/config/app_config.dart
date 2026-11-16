/// Compile-time environment, injected with `--dart-define-from-file=env/<env>.json`.
abstract final class AppConfig {
  static const appEnv = String.fromEnvironment('APP_ENV');
  static const baseUrl = String.fromEnvironment('BASE_URL');

  /// Whose data mock mode shows: `kids` plays a child's account
  /// (`env/mock_kids.json`).
  static const mockAudience = String.fromEnvironment('MOCK_AUDIENCE');

  /// Google's OAuth client of the server (a "Web application" one): sign-in
  /// asks for a token made for it. Empty leaves Google sign-in failing.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Google's OAuth client of the iOS app. Android needs none here: Google
  /// finds its client by the application ID and the signing key.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Firebase, for notifications (ADR 21): the project and each platform's
  /// app. Public values, like the OAuth client IDs; empty leaves the app
  /// without notifications.
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseAndroidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const firebaseIosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
  );

  /// The iOS bundle ID, as Xcode has it.
  static const iosBundleId = 'com.engleazia.app';

  static const jsonTimeout = Duration(seconds: 20);

  static bool get isProd => appEnv == 'prod';
  static bool get isMock => appEnv == 'mock';
  static bool get isKidsMock => isMock && mockAudience == 'kids';

  static void validate() {
    if (appEnv.isEmpty || baseUrl.isEmpty) {
      throw StateError(
        'APP_ENV or BASE_URL is missing. '
        'Run with --dart-define-from-file=env/<env>.json',
      );
    }
  }
}
