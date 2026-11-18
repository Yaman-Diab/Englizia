import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/media/media_vault.dart';
import 'package:englizia/core/media/vault_cipher.dart';

/// Hands the phone's own player what the vault keeps, as the player only
/// plays from an address. It listens on this phone alone (127.0.0.1), on a
/// port the system picks, and every address starts with a secret made when
/// it starts, so no other app can ask.
///
/// A video's segments leave as they are kept, still sealed: the player opens
/// them itself with the key it asks for here. A clip is opened in memory.
/// Nothing is ever written to the phone unsealed.
final class MediaServer {
  MediaServer({required Directory root, required VaultCipher cipher})
    : _root = root,
      _cipher = cipher;

  static const _playlistType = 'application/vnd.apple.mpegurl';

  final Directory _root;
  final VaultCipher _cipher;
  HttpServer? _server;
  Future<HttpServer>? _starting;
  String _secret = '';

  Future<HttpServer> _start() => _starting ??= () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _secret = base64Url.encode(_cipher.randomBytes(24));
    _server = server;
    unawaited(_serve(server));
    return server;
  }();

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _answer(request);
      } on Object catch (error, stackTrace) {
        AppLogger.error(error, stackTrace, 'A kept file could not be served');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } on Object {
          // The player went away: nothing to tell it.
        }
      }
    }
  }

  Future<Uri> _uri(List<String> path) async {
    final server = await _start();
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      pathSegments: [_secret, ...path],
    );
  }

  Future<Uri> videoUri(String key) => _uri(['v', key, 'index.m3u8']);

  Future<Uri> blobUri(String key) => _uri(['b', key]);

  Future<void> close() async {
    final server = _server;
    _server = null;
    _starting = null;
    await server?.close(force: true);
  }

  static final _name = RegExp(r'^[a-z0-9]+$');

  /// A video's keys (the stream's `k0`…, or the phone's own) and its files
  /// (`s0`…, `m0`…): nothing else in its folder is the player's to ask for.
  static final _videoKey = RegExp(r'^(k\d+|own)$');
  static final _videoFile = RegExp(r'^[sm]\d+$');

  Future<void> _answer(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.pathSegments;
    final known =
        request.method == 'GET' &&
        path.length >= 3 &&
        path.first == _secret &&
        path.skip(1).take(2).every(_name.hasMatch);
    if (!known) return _refuse(response);
    switch (path) {
      case [_, 'b', final key]:
        await _blob(request, File('${_root.path}/b/$key'));
      case [_, 'v', final key, 'index.m3u8']:
        final lines = await _opened(
          File('${_root.path}/v/$key/${FileMediaVault.index}'),
        );
        if (lines == null) return _refuse(response);
        response.headers.contentType = ContentType.parse(_playlistType);
        response.add(lines);
        await response.close();
      // A key is kept sealed and opened for the player.
      case [_, 'v', final key, final name] when _videoKey.hasMatch(name):
        final opened = await _opened(File('${_root.path}/v/$key/$name'));
        if (opened == null) return _refuse(response);
        response.headers.contentType = ContentType.binary;
        response.add(opened);
        await response.close();
      // A segment goes as it is kept, for the player to open.
      case [_, 'v', final key, final name] when _videoFile.hasMatch(name):
        final file = File('${_root.path}/v/$key/$name');
        if (!file.existsSync()) return _refuse(response);
        response.headers.contentType = ContentType.binary;
        response.contentLength = await file.length();
        await response.addStream(file.openRead());
        await response.close();
      default:
        await _refuse(response);
    }
  }

  Future<Uint8List?> _opened(File file) async {
    if (!file.existsSync()) return null;
    try {
      return await _cipher.open(await file.readAsBytes());
    } on FormatException {
      return null;
    }
  }

  /// A clip, whole or the range the player asks for.
  Future<void> _blob(HttpRequest request, File file) async {
    final response = request.response;
    final plain = await _opened(file);
    if (plain == null) return _refuse(response);
    final SealedBlob blob;
    try {
      blob = SealedBlob.parse(plain);
    } on FormatException {
      return _refuse(response);
    }
    final bytes = blob.bytes;
    response.headers
      ..contentType = ContentType.parse(
        blob.contentType ?? ContentType.binary.mimeType,
      )
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    final range = RegExp(
      r'^bytes=(\d*)-(\d*)$',
    ).firstMatch(request.headers.value(HttpHeaders.rangeHeader) ?? '');
    if (range == null || bytes.isEmpty) {
      response
        ..contentLength = bytes.length
        ..add(bytes);
      return response.close();
    }
    final last = bytes.length - 1;
    final from = int.tryParse(range.group(1)!);
    final to = int.tryParse(range.group(2)!);
    // "-N" is the last N bytes.
    final start = from ?? (bytes.length - (to ?? 0)).clamp(0, last);
    final end = from == null ? last : (to ?? last).clamp(0, last);
    if (start > end) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      return response.close();
    }
    response
      ..statusCode = HttpStatus.partialContent
      ..headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${bytes.length}',
      )
      ..contentLength = end - start + 1
      ..add(bytes.sublist(start, end + 1));
    return response.close();
  }

  Future<void> _refuse(HttpResponse response) async {
    response.statusCode = HttpStatus.notFound;
    await response.close();
  }
}
