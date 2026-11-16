import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';

/// A track with its levels, as `system/config`'s onboarding
/// (`OnboardingTrackDto`) and the catalog (`TrackCatalogItemDto`) give it;
/// contract in docs/api/tracks.md.
final class TrackModel {
  const TrackModel(this.entity, this.levels);

  /// [order] is the track's place in its list; [audience] is the onboarding
  /// group it came in, when it has no `onboardingAudience` of its own.
  factory TrackModel.fromJson(
    Map<String, Object?> json, {
    required int order,
    TrackAudience? audience,
  }) {
    final id = json.readString('id');
    if (id == null) throw const FormatException('Track without an id');
    final kidsMode = json.readBool('kidsMode') ?? false;
    final levels = json.readList('levels') ?? const [];
    return TrackModel(
      LearningTrack(
        id: id,
        title: _text(json, 'name'),
        description: _text(json, 'description'),
        order: order,
        audience: audienceOf(json.readString('onboardingAudience')) ?? audience,
        entryMethod: switch (json.readString('entryMode')) {
          'placement' => TrackEntryMethod.placementTest,
          'grade_choice' => TrackEntryMethod.gradeSelection,
          _ => TrackEntryMethod.directStart,
        },
      ),
      [
        for (final (index, level) in levels.indexed)
          ?_level(level, order: index + 1, kidsMode: kidsMode),
      ],
    );
  }

  final LearningTrack entity;

  /// In display order.
  final List<TrackLevel> levels;

  /// An unknown audience means "not suggested", the least privilege.
  static TrackAudience? audienceOf(String? value) => switch (value) {
    'adult' => TrackAudience.self,
    'child' => TrackAudience.child,
    'school_student' => TrackAudience.schoolStudent,
    _ => null,
  };

  /// `nameAr` and `nameEn`; English falls back to Arabic when missing.
  static LocalizedText _text(Map<String, Object?> json, String field) =>
      LocalizedText(
        ar: json.readString('${field}Ar') ?? '',
        en: json.readString('${field}En') ?? '',
      );

  /// A level without an id is skipped, not fatal.
  // ASSUMPTION(api): a level has no kids mode of its own, so it takes its
  // track's; it has no English name or stage either (docs/api/tracks.md).
  static TrackLevel? _level(
    Object? item, {
    required int order,
    required bool kidsMode,
  }) {
    if (item is! Map) return null;
    final json = item.cast<String, Object?>();
    final id = json.readString('id');
    if (id == null) return null;
    final stage = json.readString('stageLabelAr');
    return TrackLevel(
      id: id,
      order: order,
      name: LocalizedText(ar: json.readString('nameAr') ?? ''),
      schoolGrade: json.readInt('gradeNumber'),
      group: stage == null ? null : LocalizedText(ar: stage),
      kidsMode: kidsMode,
    );
  }
}
