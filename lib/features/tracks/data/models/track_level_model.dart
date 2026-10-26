import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';

/// JSON shape of a level; contract in docs/api/tracks.md.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/tracks.md).
final class TrackLevelModel {
  const TrackLevelModel(this.entity);

  factory TrackLevelModel.fromJson(Map<String, Object?> json) {
    final id = json.readString('id');
    if (id == null) throw const FormatException('Level without an id');
    final group = json.readMap('displayGroup');
    return TrackLevelModel(
      TrackLevel(
        id: id,
        order: json.readInt('order') ?? 0,
        name: _text(json.readMap('name')),
        schoolGrade: json.readInt('schoolGrade'),
        group: group == null ? null : _text(group),
      ),
    );
  }

  final TrackLevel entity;

  static LocalizedText _text(Map<String, Object?>? json) => LocalizedText(
    ar: json?.readString('ar') ?? '',
    en: json?.readString('en') ?? '',
  );
}
