import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';

/// JSON shape of a track; contract in docs/api/tracks.md.
// ASSUMPTION(api): every field name and enum value here is proposed, not
// confirmed by the backend team (docs/api/tracks.md).
final class TrackModel {
  const TrackModel(this.entity);

  factory TrackModel.fromJson(Map<String, Object?> json) {
    final id = json.readString('id');
    if (id == null) throw const FormatException('Track without an id');
    return TrackModel(
      LearningTrack(
        id: id,
        title: _text(json.readMap('title')),
        description: _text(json.readMap('description')),
        order: json.readInt('order') ?? 0,
        // An unknown audience means "not suggested", the least privilege.
        audience: switch (json.readString('onboardingAudience')) {
          'self' => TrackAudience.self,
          'child' => TrackAudience.child,
          'schoolStudent' => TrackAudience.schoolStudent,
          _ => null,
        },
        entryMethod: switch (json.readString('entryMethod')) {
          'placementTest' => TrackEntryMethod.placementTest,
          'gradeSelection' => TrackEntryMethod.gradeSelection,
          _ => TrackEntryMethod.directStart,
        },
      ),
    );
  }

  final LearningTrack entity;

  static LocalizedText _text(Map<String, Object?>? json) => LocalizedText(
    ar: json?.readString('ar') ?? '',
    en: json?.readString('en') ?? '',
  );
}
