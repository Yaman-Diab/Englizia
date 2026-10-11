import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.tokens]);

  AuthTokens? tokens;
  bool throwOnRead = false;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<AuthTokens?> read() async {
    if (throwOnRead) throw StateError('keystore unavailable');
    return tokens;
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    this.tokens = tokens;
    writeCount++;
  }

  @override
  Future<void> clear() async {
    tokens = null;
    clearCount++;
  }
}

class FakeTokenRefresher implements TokenRefresher {
  FakeTokenRefresher(this._onRefresh);

  final Future<AuthTokens> Function(AuthTokens current) _onRefresh;
  int calls = 0;

  @override
  Future<AuthTokens> refresh(AuthTokens current) {
    calls++;
    return _onRefresh(current);
  }
}
