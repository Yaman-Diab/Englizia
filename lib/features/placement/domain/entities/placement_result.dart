import 'package:englizia/core/l10n/localized_text.dart';
import 'package:equatable/equatable.dart';

/// One level of the track, as the ladder shows it. What it says comes from the
/// control panel.
final class PlacementLevel extends Equatable {
  const PlacementLevel({
    required this.id,
    required this.code,
    required this.name,
    required this.canDo,
  });

  final String id;

  /// CEFR code, e.g. "A2".
  final String code;
  final LocalizedText name;

  /// What a learner at this level can do; for the first level, what the first
  /// week teaches.
  final List<LocalizedText> canDo;

  @override
  List<Object?> get props => [id, code, name, canDo];
}

enum PlacementSkillKind { vocabulary, grammar, reading, listening }

/// How a skill went, relative to the others: never shown as a number.
final class PlacementSkill extends Equatable {
  const PlacementSkill({required this.kind, required this.score});

  final PlacementSkillKind kind;
  final double score;

  @override
  List<Object?> get props => [kind, score];
}

/// An estimate, not an exam mark (requirements v3.0 §12.2).
final class PlacementResult extends Equatable {
  const PlacementResult({
    required this.levels,
    required this.levelIndex,
    required this.skills,
  });

  /// The track's levels, from the first.
  final List<PlacementLevel> levels;

  /// Where the learner came out.
  final int levelIndex;
  final List<PlacementSkill> skills;

  @override
  List<Object?> get props => [levels, levelIndex, skills];
}
