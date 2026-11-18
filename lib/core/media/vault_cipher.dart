import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the vault's key lives: the phone's Keystore or Keychain, which no
/// file manager, backup or other app reads.
abstract interface class VaultKeyStore {
  Future<String?> read();

  Future<void> write(String key);

  Future<void> delete();
}

final class SecureVaultKeyStore implements VaultKeyStore {
  const SecureVaultKeyStore([this._storage = const FlutterSecureStorage()]);

  static const _name = 'media.vault_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String key) => _storage.write(key: _name, value: key);

  @override
  Future<void> delete() => _storage.delete(key: _name);
}

/// Seals what the vault keeps with AES-256-GCM under a key made on this
/// phone, so a file copied off it is noise, and one tampered with is refused.
/// A sealed file is `nonce (12) | ciphertext | tag (16)`.
final class VaultCipher {
  VaultCipher(this._keys, {Random? random})
    : _random = random ?? Random.secure();

  static const _nonceLength = 12;
  static const _tagLength = 16;
  static const _keyLength = 32;

  final VaultKeyStore _keys;
  final Random _random;
  final _gcm = AesGcm.with256bits();
  SecretKey? _key;

  /// Random bytes from the phone's secure source.
  Uint8List randomBytes(int length) => Uint8List.fromList([
    for (var i = 0; i < length; i++) _random.nextInt(256),
  ]);

  Future<SecretKey> _secret() async {
    if (_key case final key?) return key;
    final saved = await _keys.read();
    if (saved != null) {
      try {
        final bytes = base64Decode(saved);
        if (bytes.length == _keyLength) return _key = SecretKey(bytes);
      } on FormatException {
        // An unreadable key is replaced: what it sealed is lost with it.
      }
    }
    final made = randomBytes(_keyLength);
    await _keys.write(base64Encode(made));
    return _key = SecretKey(made);
  }

  Future<Uint8List> seal(List<int> plain) async {
    final box = await _gcm.encrypt(
      plain,
      secretKey: await _secret(),
      nonce: randomBytes(_nonceLength),
    );
    return Uint8List.fromList(box.concatenation());
  }

  /// Throws a [FormatException] for anything this phone's key didn't seal.
  Future<Uint8List> open(List<int> sealed) async {
    if (sealed.length < _nonceLength + _tagLength) {
      throw const FormatException('Too short to be a sealed file');
    }
    try {
      final plain = await _gcm.decrypt(
        SecretBox.fromConcatenation(
          sealed,
          nonceLength: _nonceLength,
          macLength: _tagLength,
        ),
        secretKey: await _secret(),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const FormatException('Not sealed by this phone');
    }
  }

  /// Throws the key away: everything it sealed can never be opened again.
  Future<void> forget() async {
    _key = null;
    await _keys.delete();
  }
}

/// A video segment as HLS's own AES-128 wants it (CBC, PKCS7), which the
/// phone's player opens by itself with the key the app hands it. Off the
/// main isolate: this cipher runs in Dart, and a segment is megabytes.
Future<Uint8List> sealHlsSegment(
  List<int> plain, {
  required List<int> key,
  required List<int> iv,
}) => Isolate.run(() async {
  final box = await AesCbc.with128bits(
    macAlgorithm: MacAlgorithm.empty,
  ).encrypt(plain, secretKey: SecretKey(key), nonce: iv);
  return Uint8List.fromList(box.cipherText);
});
