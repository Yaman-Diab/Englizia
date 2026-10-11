import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:flutter/foundation.dart';

enum SessionStatus { unknown, guest, authenticated }

/// Who is using the app. GoRouter listens to it (`refreshListenable`), so
/// every status change re-runs the route guard.
class AppSessionController extends ChangeNotifier {
  AppSessionController({
    required TokenStorage tokens,
    required SettingsStorageService settings,
  }) : _tokens = tokens,
       _settings = settings;

  final TokenStorage _tokens;
  final SettingsStorageService _settings;

  SessionStatus _status = SessionStatus.unknown;
  bool _expiring = false;

  SessionStatus get status => _status;

  bool get isAuthenticated => _status == SessionStatus.authenticated;

  /// Restores the session at startup. Never throws: any failure falls back
  /// to guest so the app always leaves the splash screen.
  Future<void> bootstrap() async {
    try {
      // iOS keeps Keychain items after uninstall; a fresh install must not
      // inherit the previous user's session.
      if (!_settings.hasLaunchedBefore) {
        await _tokens.clear();
        await _settings.markLaunched();
      }
      final tokens = await _tokens.read();
      _setStatus(
        tokens == null ? SessionStatus.guest : SessionStatus.authenticated,
      );
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Session bootstrap failed');
      _setStatus(SessionStatus.guest);
    }
  }

  Future<void> signIn(AuthTokens tokens) async {
    await _tokens.write(tokens);
    _setStatus(SessionStatus.authenticated);
  }

  /// Local sign-out. The auth feature calls the server logout first
  /// (best effort), then this.
  Future<void> signOut() async {
    await _tokens.clear();
    _setStatus(SessionStatus.guest);
  }

  /// Called when the server rejects the refresh token. Parallel failing
  /// requests collapse into a single sign-out.
  Future<void> expire() async {
    if (_expiring || _status != SessionStatus.authenticated) return;
    _expiring = true;
    try {
      AppLogger.info('Session expired');
      await signOut();
    } finally {
      _expiring = false;
    }
  }

  void _setStatus(SessionStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }
}
