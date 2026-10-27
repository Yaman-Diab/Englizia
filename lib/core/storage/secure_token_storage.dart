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
  static const _kindKey = 'auth.account_kind';
  static const _accessExpiryKey = 'auth.access_expires_at';
  static const _refreshExpiryKey = 'auth.refresh_expires_at';

  final FlutterSecureStorage _storage;
  AuthTokens? _cache;
  bool _loaded = false;

  @override
  Future<AuthTokens?> read() async {
    if (_loaded) return _cache;
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      final kind = await _storage.read(key: _kindKey);
      final accessExpiry = await _storage.read(key: _accessExpiryKey);
      final refreshExpiry = await _storage.read(key: _refreshExpiryKey);
      _cache = access == null || refresh == null
          ? null
          : AuthTokens(
              accessToken: access,
              refreshToken: refresh,
              // Tokens stored before guest accounts existed are members'.
              kind: kind == AccountKind.guest.name
                  ? AccountKind.guest
                  : AccountKind.member,
              accessExpiresAt: DateTime.tryParse(accessExpiry ?? ''),
              refreshExpiresAt: DateTime.tryParse(refreshExpiry ?? ''),
            );
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
      await _storage.write(key: _kindKey, value: tokens.kind.name);
      await _writeTime(_accessExpiryKey, tokens.accessExpiresAt);
      await _writeTime(_refreshExpiryKey, tokens.refreshExpiresAt);
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
      await _storage.delete(key: _kindKey);
      await _storage.delete(key: _accessExpiryKey);
      await _storage.delete(key: _refreshExpiryKey);
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Secure storage clear failed');
    }
  }

  Future<void> _writeTime(String key, DateTime? time) => time == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: time.toUtc().toIso8601String());
}
