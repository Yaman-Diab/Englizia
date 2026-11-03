/// Compile-time environment, injected with `--dart-define-from-file=env/<env>.json`.
abstract final class AppConfig {
  static const appEnv = String.fromEnvironment('APP_ENV');
  static const baseUrl = String.fromEnvironment('BASE_URL');

  /// Whose data mock mode shows: `kids` plays a child's account
  /// (`env/mock_kids.json`).
  static const mockAudience = String.fromEnvironment('MOCK_AUDIENCE');

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
