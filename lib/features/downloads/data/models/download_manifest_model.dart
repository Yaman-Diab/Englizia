import 'package:englizia/core/network/json_reader.dart';

enum ManifestFileKind { picture, clip, video }

/// One file of a lesson to keep.
final class ManifestFile {
  const ManifestFile({
    required this.url,
    required this.kind,
    required this.bytes,
    this.contentType,
  });

  /// The address the lesson itself names, and where the file is fetched.
  final String url;
  final ManifestFileKind kind;

  /// Its size; a video's is the server's estimate of its lightest rendition.
  final int bytes;
  final String? contentType;
}

/// What a lesson needs to open with no connection; contract in
/// docs/api/downloads.md.
// ASSUMPTION(api): every field here is proposed, not confirmed.
final class DownloadManifestModel {
  const DownloadManifestModel({
    required this.lessonId,
    required this.version,
    required this.lesson,
    required this.files,
  });

  factory DownloadManifestModel.fromJson(Map<String, Object?> json) {
    final lessonId = json.readString('lessonId');
    final lesson = json.readMap('lesson');
    if (lessonId == null || lesson == null) {
      throw const FormatException('A manifest without its lesson');
    }
    return DownloadManifestModel(
      lessonId: lessonId,
      version: json.readInt('lessonVersion') ?? 0,
      lesson: lesson,
      files: [
        for (final item in json.readList('files') ?? const <Object?>[])
          ?_file(item),
      ],
    );
  }

  final String lessonId;
  final int version;

  /// The lesson as `GET /api/v1/app/lessons/{id}` gives it.
  final Map<String, Object?> lesson;
  final List<ManifestFile> files;

  int get bytes => files.fold(0, (sum, file) => sum + file.bytes);

  /// A file with no address or of a kind the app doesn't know is left out:
  /// the lesson then opens without it, as it does when a file fails online.
  static ManifestFile? _file(Object? item) {
    if (item is! Map) return null;
    final json = item.cast<String, Object?>();
    final url = json.readString('url');
    final kind = switch (json.readString('kind')) {
      'picture' => ManifestFileKind.picture,
      'clip' => ManifestFileKind.clip,
      'video' => ManifestFileKind.video,
      _ => null,
    };
    if (url == null || kind == null || Uri.tryParse(url) == null) return null;
    final bytes = json.readInt('bytes') ?? 0;
    return ManifestFile(
      url: url,
      kind: kind,
      bytes: bytes < 0 ? 0 : bytes,
      contentType: json.readString('contentType'),
    );
  }
}
