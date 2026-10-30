import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:flutter/foundation.dart';

/// Who is using the app (ADR 10).
enum SessionStatus {
  /// Not read from storage yet: the splash screen shows.
  unknown,

  /// No account on this phone: welcome, onboarding and sign-in.
  signedOut,

  /// An anonymous guest account: the app works, but the progress can only
  /// be reached from this phone until the learner creates an account.
  guest,

  /// A full account.
  member,
}

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

  /// A guest or member account is in use.
  bool get hasSession =>
      _status == SessionStatus.guest || _status == SessionStatus.member;

  /// Restores the session at startup. Never throws: any failure falls back
  /// to signed out so the app always leaves the splash screen.
  Future<void> bootstrap() async {
    try {
      // iOS keeps Keychain items after uninstall; a fresh install must not
      // inherit the previous user's session.
      if (!_settings.hasLaunchedBefore) {
        await _tokens.clear();
        await _settings.markLaunched();
      }
      final tokens = await _tokens.read();
      _setStatus(_statusOf(tokens));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Session bootstrap failed');
      _setStatus(SessionStatus.signedOut);
    }
  }

  /// Starts a session with [tokens]: a guest's or a member's, as they say.
  /// False when the phone could not save them: the session still works, but
  /// only until the app closes.
  Future<bool> signIn(AuthTokens tokens) async {
    final saved = await _tokens.write(tokens);
    _setStatus(_statusOf(tokens));
    return saved;
  }

  /// Local sign-out. The auth feature calls the server logout first
  /// (best effort), then this. A guest who signs out loses the account.
  Future<void> signOut() async {
    await _tokens.clear();
    _setStatus(SessionStatus.signedOut);
  }

  static SessionStatus _statusOf(AuthTokens? tokens) => switch (tokens?.kind) {
    null => SessionStatus.signedOut,
    AccountKind.guest => SessionStatus.guest,
    AccountKind.member => SessionStatus.member,
  };

  /// Called when the server rejects the refresh token. Parallel failing
  /// requests collapse into a single sign-out.
  Future<void> expire() async {
    if (_expiring || !hasSession) return;
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
