import 'package:englizia/core/session/auth_tokens.dart';

abstract interface class TokenStorage {
  Future<AuthTokens?> read();

  /// Keeps [tokens] for this run, and on the phone for the next. False when
  /// the phone could not save them: the session works until the app closes.
  Future<bool> write(AuthTokens tokens);

  Future<void> clear();
}
