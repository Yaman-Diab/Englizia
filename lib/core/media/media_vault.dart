import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/media/hls_playlist.dart';
import 'package:englizia/core/media/media_server.dart';
import 'package:englizia/core/media/vault_cipher.dart';

/// What the app keeps of a lesson to open it with no connection: pictures,
/// clips, videos and the lesson itself, sealed in the app's own folder
/// (ADR 22). Nothing here is a file another app, a file manager or a backup
/// can use. A file is known by its address without the query, as signed
/// links change.
abstract interface class MediaVault {
  /// Whether [url]'s file is kept whole. Cheap: asked while building.
  bool has(String url);

  /// A kept picture's or clip's bytes, or null.
  Future<Uint8List?> read(String url);

  /// A kept clip's or video's address for the phone's player, which only
  /// this app can use and only while it runs; null when it isn't kept.
  Future<Uri?> playable(String url);

  bool hasJson(String name);

  Future<Map<String, Object?>?> readJson(String name);

  /// Each write returns the bytes it took on the phone.
  Future<int> put(String url, List<int> bytes, {String? contentType});

  Future<int> putJson(String name, Map<String, Object?> json);

  /// The start of the IVs of [url]'s video, the same through every try.
  Future<Uint8List> videoIvPrefix(String url);

  bool hasVideoPart(String url, String name);

  Future<int> putVideoPart(String url, HlsPart part, List<int> bytes);

  /// The playlist goes last: with it the video is whole.
  Future<int> finishVideo(String url, List<String> lines);

  /// Removes everything but [urls] and [jsonNames], files half written too.
  Future<void> keepOnly(Set<String> urls, Set<String> jsonNames);

  /// Removes everything and throws the key away.
  Future<void> clear();

  Future<int> usedBytes();
}

/// Keeps nothing: tests, and a phone whose folder can't be reached.
final class NoMediaVault implements MediaVault {
  const NoMediaVault();

  @override
  bool has(String url) => false;

  @override
  Future<Uint8List?> read(String url) async => null;

  @override
  Future<Uri?> playable(String url) async => null;

  @override
  bool hasJson(String name) => false;

  @override
  Future<Map<String, Object?>?> readJson(String name) async => null;

  @override
  Future<int> put(String url, List<int> bytes, {String? contentType}) async =>
      0;

  @override
  Future<int> putJson(String name, Map<String, Object?> json) async => 0;

  @override
  Future<Uint8List> videoIvPrefix(String url) async => Uint8List(8);

  @override
  bool hasVideoPart(String url, String name) => false;

  @override
  Future<int> putVideoPart(String url, HlsPart part, List<int> bytes) async =>
      0;

  @override
  Future<int> finishVideo(String url, List<String> lines) async => 0;

  @override
  Future<void> keepOnly(Set<String> urls, Set<String> jsonNames) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<int> usedBytes() async => 0;
}

/// A kept file's name: its address without the query, hashed, so the folder
/// says nothing of what it holds.
String mediaKeyOf(String url) {
  final uri = Uri.tryParse(url);
  final plain = uri == null || !uri.hasScheme
      ? url
      : uri.replace(query: '', fragment: '').toString();
  final hash = const DartSha256().hashSync(utf8.encode(plain));
  return [
    for (final byte in hash.bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// [MediaVault] on files under [root], the app's support folder: not the
/// cache, which the system empties, and not shared storage.
///
/// `b/<key>` a sealed picture or clip · `d/<key>` a sealed document ·
/// `v/<key>/` a video: its sealed playlist `index`, sealed keys, and the
/// segments as HLS's AES-128 has them, which the player opens itself.
final class FileMediaVault implements MediaVault {
  FileMediaVault({
    required Directory root,
    required VaultCipher cipher,
    MediaServer? server,
  }) : _root = root,
       _cipher = cipher,
       _server = server ?? MediaServer(root: root, cipher: cipher);

  static const _part = '.part';
  static const index = 'index';
  static const _ivFile = 'iv';

  final Directory _root;
  final VaultCipher _cipher;
  final MediaServer _server;

  var _writes = 0;

  /// Each video's own key while it is being kept.
  final _ownKeys = <String, Uint8List>{};

  File _blob(String url) => File('${_root.path}/b/${mediaKeyOf(url)}');

  File _doc(String name) => File('${_root.path}/d/${mediaKeyOf(name)}');

  Directory _video(String url) =>
      Directory('${_root.path}/v/${mediaKeyOf(url)}');

  File _videoFile(String url, String name) => File('${_video(url).path}/$name');

  /// Written beside its place, then moved: a file is whole or absent. Each
  /// write has its own name, so two of the same file can't cross.
  Future<int> _write(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final part = File('${file.path}.${_writes++}$_part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(file.path);
    return bytes.length;
  }

  Future<Uint8List?> _open(File file) async {
    if (!file.existsSync()) return null;
    try {
      return await _cipher.open(await file.readAsBytes());
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'A kept file could not be opened');
      return null;
    }
  }

  @override
  bool has(String url) =>
      _blob(url).existsSync() || _videoFile(url, index).existsSync();

  @override
  Future<Uint8List?> read(String url) async {
    final plain = await _open(_blob(url));
    if (plain == null) return null;
    try {
      return SealedBlob.parse(plain).bytes;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<Uri?> playable(String url) async {
    final key = mediaKeyOf(url);
    if (_videoFile(url, index).existsSync()) return _server.videoUri(key);
    if (_blob(url).existsSync()) return _server.blobUri(key);
    return null;
  }

  @override
  bool hasJson(String name) => _doc(name).existsSync();

  @override
  Future<Map<String, Object?>?> readJson(String name) async {
    final plain = await _open(_doc(name));
    if (plain == null) return null;
    try {
      final json = jsonDecode(utf8.decode(plain));
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<int> put(String url, List<int> bytes, {String? contentType}) async =>
      _write(
        _blob(url),
        await _cipher.seal(
          SealedBlob(
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
            contentType,
          ).toBytes(),
        ),
      );

  @override
  Future<int> putJson(String name, Map<String, Object?> json) async =>
      _write(_doc(name), await _cipher.seal(utf8.encode(jsonEncode(json))));

  @override
  Future<Uint8List> videoIvPrefix(String url) async {
    final file = _videoFile(url, _ivFile);
    if (file.existsSync()) {
      final saved = await file.readAsBytes();
      if (saved.length == 8) return saved;
    }
    final made = _cipher.randomBytes(8);
    await _write(file, made);
    return made;
  }

  @override
  bool hasVideoPart(String url, String name) =>
      _videoFile(url, name).existsSync();

  Future<Uint8List> _ownKey(String url) async {
    if (_ownKeys[url] case final key?) return key;
    final file = _videoFile(url, HlsPlaylist.ownKey);
    final saved = await _open(file);
    if (saved != null && saved.length == 16) return _ownKeys[url] = saved;
    final made = _cipher.randomBytes(16);
    await _write(file, await _cipher.seal(made));
    return _ownKeys[url] = made;
  }

  @override
  Future<int> putVideoPart(String url, HlsPart part, List<int> bytes) async {
    final file = _videoFile(url, part.name);
    if (part.kind == HlsPartKind.key) {
      return _write(file, await _cipher.seal(bytes));
    }
    final iv = part.iv;
    // The stream's own sealing is kept as it came.
    if (iv == null) return _write(file, bytes);
    return _write(
      file,
      await sealHlsSegment(bytes, key: await _ownKey(url), iv: iv),
    );
  }

  @override
  Future<int> finishVideo(String url, List<String> lines) async {
    _ownKeys.remove(url);
    return _write(
      _videoFile(url, index),
      await _cipher.seal(utf8.encode(lines.join('\n'))),
    );
  }

  @override
  Future<void> keepOnly(Set<String> urls, Set<String> jsonNames) async {
    final keys = {for (final url in urls) mediaKeyOf(url)};
    final docs = {for (final name in jsonNames) mediaKeyOf(name)};
    for (final (folder, wanted) in [('b', keys), ('d', docs), ('v', keys)]) {
      final directory = Directory('${_root.path}/$folder');
      if (!directory.existsSync()) continue;
      await for (final entry in directory.list()) {
        final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (wanted.contains(name)) {
          if (entry is Directory) await _dropParts(entry);
          continue;
        }
        await _delete(entry);
      }
    }
  }

  Future<void> _dropParts(Directory directory) async {
    await for (final entry in directory.list()) {
      if (entry.path.endsWith(_part)) await _delete(entry);
    }
  }

  Future<void> _delete(FileSystemEntity entry) async {
    try {
      await entry.delete(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'A kept file could not be removed');
    }
  }

  @override
  Future<void> clear() async {
    _ownKeys.clear();
    await _server.close();
    if (_root.existsSync()) await _delete(_root);
    await _cipher.forget();
  }

  @override
  Future<int> usedBytes() async {
    if (!_root.existsSync()) return 0;
    var total = 0;
    await for (final entry in _root.list(recursive: true)) {
      if (entry is File) total += await entry.length();
    }
    return total;
  }
}

/// A picture or a clip with what it is, as one sealed file.
/// `type length (1) | type | bytes`.
final class SealedBlob {
  const SealedBlob(this.bytes, this.contentType);

  factory SealedBlob.parse(Uint8List plain) {
    if (plain.isEmpty || plain.length < 1 + plain[0]) {
      throw const FormatException('Not a kept file');
    }
    final length = plain[0];
    return SealedBlob(
      Uint8List.sublistView(plain, 1 + length),
      length == 0 ? null : utf8.decode(plain.sublist(1, 1 + length)),
    );
  }

  final Uint8List bytes;
  final String? contentType;

  Uint8List toBytes() {
    final type = utf8.encode(contentType ?? '');
    final kept = type.length > 255 ? const <int>[] : type;
    return (BytesBuilder(copy: false)
          ..addByte(kept.length)
          ..add(kept)
          ..add(bytes))
        .takeBytes();
  }
}
