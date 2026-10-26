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
    return TrackLevelModel(
      TrackLevel(
        id: id,
        order: json.readInt('order') ?? 0,
        name: json.readText('name') ?? _empty,
        schoolGrade: json.readInt('schoolGrade'),
        group: json.readText('displayGroup'),
      ),
    );
  }

  final TrackLevel entity;

  static const _empty = LocalizedText(ar: '');
}
