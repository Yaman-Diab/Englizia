import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:englizia/core/media/hls_playlist.dart';
import 'package:englizia/core/media/media_server.dart';
import 'package:englizia/core/media/media_vault.dart';
import 'package:englizia/core/media/vault_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryKeyStore implements VaultKeyStore {
  String? key;

  @override
  Future<String?> read() async => key;

  @override
  Future<void> write(String key) async => this.key = key;

  @override
  Future<void> delete() async => key = null;
}

const _plainStream = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:6.0,
low/seg0.ts
#EXTINF:4.5,
low/seg1.ts?token=abc
#EXT-X-ENDLIST
''';

const _sealedStream = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXT-X-KEY:METHOD=AES-128,URI="https://keys.example.com/k?id=1",IV=0x00000000000000000000000000000001
#EXTINF:6.0,
seg0.ts
#EXT-X-ENDLIST
''';

const _master = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="en",URI="audio/en.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
high/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=640x360
low/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=200000,AUDIO="aud"
tiny/index.m3u8
''';

void main() {
  final base = Uri.parse('https://cdn.example.com/v/1/index.m3u8');
  const picture = 'https://cdn.example.com/p/cat.webp?sig=1';
  const video = 'https://cdn.example.com/v/1/index.m3u8';

  late Directory root;
  late MemoryKeyStore keys;
  late VaultCipher cipher;
  late MediaServer server;
  late FileMediaVault vault;

  setUp(() {
    root = Directory.systemTemp.createTempSync('vault_test_');
    keys = MemoryKeyStore();
    cipher = VaultCipher(keys);
    server = MediaServer(root: root, cipher: cipher);
    vault = FileMediaVault(root: root, cipher: cipher, server: server);
  });

  tearDown(() async {
    await server.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<(int, List<int>, HttpHeaders)> fetch(Uri uri, {String? range}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
      final response = await request.close();
      final body = await response.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      return (response.statusCode, body, response.headers);
    } finally {
      client.close();
    }
  }

  group('the cipher', () {
    test('what it seals, it opens; the key is made once', () async {
      final sealed = await cipher.seal(utf8.encode('a lesson'));
      expect(utf8.decode(await cipher.open(sealed)), 'a lesson');
      expect(utf8.decode(sealed, allowMalformed: true), isNot(contains('a l')));

      final again = VaultCipher(keys);
      expect(utf8.decode(await again.open(sealed)), 'a lesson');
    });

    test('another phone, or a changed file, is refused', () async {
      final sealed = await cipher.seal([1, 2, 3]);
      expect(
        () => VaultCipher(MemoryKeyStore()).open(sealed),
        throwsFormatException,
      );
      sealed[sealed.length - 1] ^= 1;
      expect(() => cipher.open(sealed), throwsFormatException);
      expect(() => cipher.open([1, 2]), throwsFormatException);
    });

    test('forgetting the key loses what it sealed', () async {
      final sealed = await cipher.seal([1, 2, 3]);
      await cipher.forget();
      expect(keys.key, isNull);
      expect(() => cipher.open(sealed), throwsFormatException);
    });
  });

  test('a file is known without its query', () {
    expect(
      mediaKeyOf('https://cdn.example.com/a.webp?sig=1'),
      mediaKeyOf('https://cdn.example.com/a.webp?sig=2'),
    );
    expect(
      mediaKeyOf('https://cdn.example.com/a.webp'),
      isNot(mediaKeyOf('https://cdn.example.com/b.webp')),
    );
    expect(mediaKeyOf(picture), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  group('pictures, clips and documents', () {
    test('kept sealed, read back whole', () async {
      expect(vault.has(picture), isFalse);
      expect(await vault.read(picture), isNull);

      final bytes = Uint8List.fromList(List.generate(2000, (i) => i % 251));
      final taken = await vault.put(picture, bytes, contentType: 'image/webp');

      expect(vault.has(picture), isTrue);
      expect(vault.has('https://cdn.example.com/p/cat.webp?sig=other'), isTrue);
      expect(await vault.read(picture), bytes);
      expect(taken, greaterThan(bytes.length));
      expect(await vault.usedBytes(), taken);
      // The folder says nothing of what it holds.
      final onDisk = root.listSync(recursive: true).whereType<File>().single;
      expect(onDisk.path, isNot(contains('cat')));
      expect(onDisk.readAsBytesSync(), isNot(containsAllInOrder(bytes)));
    });

    test('a document', () async {
      await vault.putJson('lesson/1', {'id': '1', 'title': 'درس'});
      expect(await vault.readJson('lesson/1'), {'id': '1', 'title': 'درس'});
      expect(await vault.readJson('lesson/2'), isNull);
    });

    test('a file from another key reads as not kept', () async {
      await vault.put(picture, [1, 2, 3]);
      final other = FileMediaVault(
        root: root,
        cipher: VaultCipher(MemoryKeyStore()),
        server: server,
      );
      expect(await other.read(picture), isNull);
    });

    test('keepOnly removes the rest, and what was half written', () async {
      await vault.put(picture, [1]);
      await vault.put('https://cdn.example.com/p/dog.webp', [2]);
      await vault.putJson('lesson/1', {'a': 1});
      await vault.putJson('lesson/2', {'a': 2});
      File('${root.path}/b/half.part').writeAsBytesSync([0]);

      await vault.keepOnly({picture}, {'lesson/1'});

      expect(vault.has(picture), isTrue);
      expect(vault.has('https://cdn.example.com/p/dog.webp'), isFalse);
      expect(await vault.readJson('lesson/1'), isNotNull);
      expect(await vault.readJson('lesson/2'), isNull);
      expect(File('${root.path}/b/half.part').existsSync(), isFalse);
    });

    test('clear removes everything and the key', () async {
      await vault.put(picture, [1, 2, 3]);
      await vault.clear();
      expect(vault.has(picture), isFalse);
      expect(await vault.usedBytes(), 0);
      expect(keys.key, isNull);
    });
  });

  group('HLS playlists', () {
    final prefix = List.filled(8, 7);

    test('a plain stream: every file gets the phone\'s key and its IV', () {
      final media = HlsPlaylist.media(_plainStream, base, ivPrefix: prefix);

      expect(media.sealsItself, isTrue);
      expect(media.parts.map((p) => p.name), ['s0', 's1']);
      expect(
        media.parts.first.source,
        Uri.parse('https://cdn.example.com/v/1/low/seg0.ts'),
      );
      expect(media.parts.last.source.query, 'token=abc');
      expect(media.parts.map((p) => p.iv), everyElement(isNotNull));
      expect(media.parts.first.iv, isNot(media.parts.last.iv));
      expect(media.lines, [
        '#EXTM3U',
        '#EXT-X-VERSION:3',
        '#EXT-X-TARGETDURATION:6',
        '#EXT-X-MEDIA-SEQUENCE:0',
        '#EXT-X-KEY:METHOD=AES-128,URI="own",'
            'IV=0x07070707070707070000000000000000',
        '#EXTINF:6.0,',
        's0',
        '#EXT-X-KEY:METHOD=AES-128,URI="own",'
            'IV=0x07070707070707070000000000000001',
        '#EXTINF:4.5,',
        's1',
        '#EXT-X-ENDLIST',
      ]);
    });

    test('a sealed stream is kept as it came, its key beside it', () {
      final media = HlsPlaylist.media(_sealedStream, base, ivPrefix: prefix);

      expect(media.sealsItself, isFalse);
      expect(media.parts.map((p) => (p.name, p.kind, p.iv)), [
        ('k0', HlsPartKind.key, null),
        ('s0', HlsPartKind.segment, null),
      ]);
      expect(
        media.parts.first.source,
        Uri.parse('https://keys.example.com/k?id=1'),
      );
      expect(
        media.lines,
        contains(
          '#EXT-X-KEY:METHOD=AES-128,URI="k0",'
          'IV=0x00000000000000000000000000000001',
        ),
      );
      expect(media.lines.join('\n'), isNot(contains('example.com')));
    });

    test('the lightest rendition with its sound inside', () {
      expect(HlsPlaylist.isMaster(_master), isTrue);
      expect(HlsPlaylist.isMaster(_plainStream), isFalse);
      expect(
        HlsPlaylist.lightest(_master, base),
        Uri.parse('https://cdn.example.com/v/1/low/index.m3u8'),
      );
    });

    test('what can\'t be kept is refused', () {
      HlsMedia read(String text) =>
          HlsPlaylist.media(text, base, ivPrefix: prefix);

      expect(() => read('hello'), throwsFormatException);
      expect(
        () => read(_plainStream.replaceFirst('#EXT-X-ENDLIST', '')),
        throwsFormatException,
      );
      expect(
        () => read(_sealedStream.replaceFirst('AES-128', 'SAMPLE-AES')),
        throwsFormatException,
      );
      expect(
        () => read(
          _plainStream.replaceFirst(
            'low/seg0.ts',
            '#EXT-X-BYTERANGE:9@0\na.ts',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => HlsPlaylist.lightest(
          '#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",URI="a.m3u8"\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1,AUDIO="a"\nv.m3u8',
          base,
        ),
        throwsFormatException,
      );
    });
  });

  group('a kept video', () {
    final segments = [
      Uint8List.fromList(List.generate(5000, (i) => (i * 7) % 256)),
      Uint8List.fromList(List.generate(321, (i) => (i * 13) % 256)),
    ];

    Future<HlsMedia> keep() async {
      final media = HlsPlaylist.media(
        _plainStream,
        base,
        ivPrefix: await vault.videoIvPrefix(video),
      );
      for (final (index, part) in media.parts.indexed) {
        await vault.putVideoPart(video, part, segments[index]);
      }
      await vault.finishVideo(video, media.lines);
      return media;
    }

    test('whole only once its playlist is there', () async {
      final media = HlsPlaylist.media(
        _plainStream,
        base,
        ivPrefix: await vault.videoIvPrefix(video),
      );
      await vault.putVideoPart(video, media.parts.first, segments.first);

      expect(vault.has(video), isFalse);
      expect(vault.hasVideoPart(video, 's0'), isTrue);
      expect(vault.hasVideoPart(video, 's1'), isFalse);
      expect(await vault.playable(video), isNull);
      // A second try seals with the same IVs.
      expect(
        await vault.videoIvPrefix(video),
        media.parts.first.iv!.sublist(0, 8),
      );
    });

    test('nothing on the phone is the video itself', () async {
      await keep();
      for (final file in root.listSync(recursive: true).whereType<File>()) {
        final bytes = file.readAsBytesSync();
        expect(bytes, isNot(containsAllInOrder(segments.first.sublist(0, 64))));
        expect(
          utf8.decode(bytes, allowMalformed: true),
          isNot(contains('#EXTM3U')),
        );
      }
    });

    test('the player gets its playlist, key and segments from this phone '
        'only, and opens them as HLS does', () async {
      final media = await keep();
      final address = (await vault.playable(video))!;

      expect(address.host, '127.0.0.1');
      expect(address.path, endsWith('/index.m3u8'));

      final (status, playlist, headers) = await fetch(address);
      expect(status, 200);
      expect(headers.contentType?.mimeType, 'application/vnd.apple.mpegurl');
      expect(utf8.decode(playlist).split('\n'), media.lines);

      final (_, key, _) = await fetch(address.resolve('own'));
      expect(key, hasLength(16));

      for (final (index, part) in media.parts.indexed) {
        final (_, sealed, _) = await fetch(address.resolve(part.name));
        expect(sealed, isNot(segments[index]));
        final opened =
            await AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty).decrypt(
              SecretBox(sealed, nonce: part.iv!, mac: Mac.empty),
              secretKey: SecretKey(key),
            );
        expect(opened, segments[index]);
      }
    });

    test('a stream that came sealed keeps its own key, sealed again', () async {
      final media = HlsPlaylist.media(
        _sealedStream,
        base,
        ivPrefix: List.filled(8, 0),
      );
      final streamKey = List.generate(16, (i) => i);
      await vault.putVideoPart(video, media.parts.first, streamKey);
      await vault.putVideoPart(video, media.parts.last, [9, 9, 9]);
      await vault.finishVideo(video, media.lines);

      final onDisk = File('${root.path}/v/${mediaKeyOf(video)}/k0');
      expect(onDisk.readAsBytesSync(), isNot(containsAllInOrder(streamKey)));

      final address = (await vault.playable(video))!;
      expect((await fetch(address.resolve('k0'))).$2, streamKey);
      expect((await fetch(address.resolve('s0'))).$2, [9, 9, 9]);
    });

    test('no secret, no file', () async {
      await keep();
      final address = (await vault.playable(video))!;
      final wrong = address.replace(
        pathSegments: ['nope', ...address.pathSegments.skip(1)],
      );

      expect((await fetch(wrong)).$1, 404);
      expect((await fetch(address.resolve('../../etc'))).$1, 404);
      expect((await fetch(address.resolve('s9'))).$1, 404);
      expect((await fetch(address.resolve('index'))).$1, isNot(200));
    });
  });

  group('a kept clip', () {
    const clip = 'https://cdn.example.com/a/hello.mp3';
    final bytes = Uint8List.fromList(List.generate(100, (i) => i));

    test('played from this phone, whole or by range', () async {
      await vault.put(clip, bytes, contentType: 'audio/mpeg');
      final address = (await vault.playable(clip))!;

      final (status, whole, headers) = await fetch(address);
      expect(status, 200);
      expect(whole, bytes);
      expect(headers.contentType?.mimeType, 'audio/mpeg');

      final (partial, middle, ranged) = await fetch(
        address,
        range: 'bytes=10-19',
      );
      expect(partial, 206);
      expect(middle, bytes.sublist(10, 20));
      expect(ranged.value(HttpHeaders.contentRangeHeader), 'bytes 10-19/100');

      expect((await fetch(address, range: 'bytes=90-')).$2, bytes.sublist(90));
      expect((await fetch(address, range: 'bytes=-5')).$2, bytes.sublist(95));
      expect((await fetch(address, range: 'bytes=200-300')).$1, 416);
    });

    test('nothing kept, nothing to play', () async {
      expect(await vault.playable(clip), isNull);
    });
  });
}
