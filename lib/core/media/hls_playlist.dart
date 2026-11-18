import 'dart:typed_data';

enum HlsPartKind { segment, map, key }

/// One file of a video to keep: where it comes from and its name on the
/// phone.
final class HlsPart {
  const HlsPart({
    required this.source,
    required this.name,
    required this.kind,
    this.iv,
  });

  final Uri source;
  final String name;
  final HlsPartKind kind;

  /// Set when the source isn't encrypted: the phone seals the file itself
  /// with this IV. Null when the stream came sealed, or for a key.
  final Uint8List? iv;
}

/// A video's playlist, rewritten to play from the phone: every address is a
/// name beside it, and every file is sealed (HLS's AES-128), by the stream
/// itself or by the phone.
final class HlsMedia {
  const HlsMedia({required this.lines, required this.parts});

  /// The playlist to keep.
  final List<String> lines;

  /// The files to fetch, in the playlist's order.
  final List<HlsPart> parts;

  bool get sealsItself => parts.any((part) => part.iv != null);
}

/// Reads HLS playlists (RFC 8216) as far as keeping a lesson's video needs:
/// a finished stream of whole files, plain or AES-128. Anything else throws
/// a [FormatException], and the video stays a stream.
abstract final class HlsPlaylist {
  /// The name of the key the phone makes for a stream that came plain.
  static const ownKey = 'own';

  static final _uri = RegExp('URI="([^"]*)"');
  static final _method = RegExp('METHOD=([A-Z0-9-]+)');
  static final _bandwidth = RegExp(r'[:,]BANDWIDTH=(\d+)');
  static final _audio = RegExp('AUDIO="([^"]*)"');
  static final _group = RegExp('GROUP-ID="([^"]*)"');

  static List<String> _linesOf(String text) => [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  static bool isMaster(String text) => text.contains('#EXT-X-STREAM-INF');

  /// The lightest rendition whose sound is in the same files. Sound kept
  /// apart would be a second stream to keep in step.
  static Uri lightest(String text, Uri base) {
    final lines = _linesOf(text);
    final apart = {
      for (final line in lines)
        if (line.startsWith('#EXT-X-MEDIA') &&
            line.contains('TYPE=AUDIO') &&
            _uri.hasMatch(line))
          ?_group.firstMatch(line)?.group(1),
    };
    ({int bandwidth, Uri uri})? best;
    for (final (index, line) in lines.indexed) {
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
      if (apart.contains(_audio.firstMatch(line)?.group(1))) continue;
      final address = lines
          .skip(index + 1)
          .firstWhere((next) => !next.startsWith('#'), orElse: () => '');
      if (address.isEmpty) continue;
      final bandwidth =
          int.tryParse(_bandwidth.firstMatch(line)?.group(1) ?? '') ?? 0;
      if (best == null || bandwidth < best.bandwidth) {
        best = (bandwidth: bandwidth, uri: base.resolve(address));
      }
    }
    if (best == null) {
      throw const FormatException('No rendition with its sound inside');
    }
    return best.uri;
  }

  /// [ivPrefix] (8 random bytes) starts the IV of each file the phone seals.
  static HlsMedia media(String text, Uri base, {required List<int> ivPrefix}) {
    final source = _linesOf(text);
    if (source.firstOrNull != '#EXTM3U') {
      throw const FormatException('Not a playlist');
    }
    if (!source.contains('#EXT-X-ENDLIST')) {
      throw const FormatException('A live stream has no end to keep');
    }
    final lines = <String>[];
    final parts = <HlsPart>[];
    // Tags that belong to the next segment, held until its address comes.
    final held = <String>[];
    var sealedBySource = false;
    var keys = 0;
    var maps = 0;
    var segments = 0;

    Uint8List nextIv() {
      final iv = Uint8List(16)..setRange(0, 8, ivPrefix);
      ByteData.sublistView(iv).setUint64(8, parts.length);
      return iv;
    }

    String hex(Uint8List bytes) => [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();

    /// The phone's own key line, for a file the source left plain.
    Uint8List? own() {
      if (sealedBySource) return null;
      final iv = nextIv();
      lines.add('#EXT-X-KEY:METHOD=AES-128,URI="$ownKey",IV=0x${hex(iv)}');
      return iv;
    }

    for (final line in source) {
      if (line.startsWith('#EXT-X-KEY')) {
        switch (_method.firstMatch(line)?.group(1)) {
          case 'NONE':
            sealedBySource = false;
          case 'AES-128':
            final address = _uri.firstMatch(line)?.group(1);
            if (address == null) throw const FormatException('A key nowhere');
            final name = 'k${keys++}';
            parts.add(
              HlsPart(
                source: base.resolve(address),
                name: name,
                kind: HlsPartKind.key,
              ),
            );
            sealedBySource = true;
            lines.add(line.replaceFirst(_uri, 'URI="$name"'));
          case final other:
            throw FormatException('Encryption $other is not kept');
        }
      } else if (line.startsWith('#EXT-X-BYTERANGE') ||
          (line.startsWith('#EXT-X-MAP') && line.contains('BYTERANGE'))) {
        throw const FormatException('Parts of a file are not kept');
      } else if (line.startsWith('#EXT-X-MAP')) {
        final address = _uri.firstMatch(line)?.group(1);
        if (address == null) throw const FormatException('A map nowhere');
        final name = 'm${maps++}';
        final iv = own();
        parts.add(
          HlsPart(
            source: base.resolve(address),
            name: name,
            kind: HlsPartKind.map,
            iv: iv,
          ),
        );
        lines.add(line.replaceFirst(_uri, 'URI="$name"'));
      } else if (line.startsWith('#EXTINF') ||
          line.startsWith('#EXT-X-DISCONTINUITY') ||
          line.startsWith('#EXT-X-PROGRAM-DATE-TIME')) {
        held.add(line);
      } else if (line.startsWith('#')) {
        lines.add(line);
      } else {
        final name = 's${segments++}';
        final iv = own();
        parts.add(
          HlsPart(
            source: base.resolve(line),
            name: name,
            kind: HlsPartKind.segment,
            iv: iv,
          ),
        );
        lines
          ..addAll(held)
          ..add(name);
        held.clear();
      }
    }
    if (segments == 0) throw const FormatException('A playlist of nothing');
    return HlsMedia(lines: lines, parts: parts);
  }
}
