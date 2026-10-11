import 'package:englizia/core/session/auth_tokens.dart';

abstract interface class TokenStorage {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}
