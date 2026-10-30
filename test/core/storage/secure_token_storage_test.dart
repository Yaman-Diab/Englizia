import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/secure_token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A keystore in memory that can fail, as a locked one does.
class _Keystore extends Fake implements FlutterSecureStorage {
  final values = <String, String>{};
  bool failing = false;

  void _check() {
    if (failing) throw StateError('keystore unavailable');
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _check();
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _check();
    values[key] = value!;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _check();
    values.remove(key);
  }
}

void main() {
  final tokens = AuthTokens(
    accessToken: 'a',
    refreshToken: 'r',
    kind: AccountKind.guest,
    accessExpiresAt: DateTime.utc(2026, 11),
    refreshExpiresAt: DateTime.utc(2026, 12),
  );

  late _Keystore keystore;
  setUp(() => keystore = _Keystore());

  test('what is written is read back after the app reopens', () async {
    expect(await SecureTokenStorage(keystore).write(tokens), isTrue);
    expect(await SecureTokenStorage(keystore).read(), tokens);
  });

  test('a failed write says so, and keeps the session for this run', () async {
    keystore.failing = true;
    final storage = SecureTokenStorage(keystore);
    expect(await storage.write(tokens), isFalse);
    expect(await storage.read(), tokens);
  });

  test('a failed read is tried again on the next one', () async {
    await SecureTokenStorage(keystore).write(tokens);
    final reopened = SecureTokenStorage(keystore);

    keystore.failing = true;
    expect(await reopened.read(), isNull);

    keystore.failing = false;
    expect(await reopened.read(), tokens);
  });

  test('a successful read is not repeated', () async {
    await SecureTokenStorage(keystore).write(tokens);
    final reopened = SecureTokenStorage(keystore);
    await reopened.read();

    keystore.failing = true;
    expect(await reopened.read(), tokens);
  });

  test('clearing forgets everything', () async {
    final storage = SecureTokenStorage(keystore);
    await storage.write(tokens);
    await storage.clear();
    expect(await storage.read(), isNull);
    expect(keystore.values, isEmpty);
  });
}
