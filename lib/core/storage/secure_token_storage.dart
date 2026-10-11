import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens in the platform keystore. Kept in memory after the first read
/// because the auth interceptor reads them on every request.
final class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';

  final FlutterSecureStorage _storage;
  AuthTokens? _cache;
  bool _loaded = false;

  @override
  Future<AuthTokens?> read() async {
    if (_loaded) return _cache;
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      _cache = access == null || refresh == null
          ? null
          : AuthTokens(accessToken: access, refreshToken: refresh);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Secure storage read failed');
      _cache = null;
    }
    _loaded = true;
    return _cache;
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    _cache = tokens;
    _loaded = true;
    try {
      await _storage.write(key: _accessKey, value: tokens.accessToken);
      await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Secure storage write failed');
    }
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Secure storage clear failed');
    }
  }
}
