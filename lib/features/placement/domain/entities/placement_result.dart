import 'package:englizia/core/l10n/localized_text.dart';
import 'package:equatable/equatable.dart';

/// One step of the ladder, Pre-A1 to B2. Its name is the track's level when
/// the learner may start there; what it says a learner can do is the app's
/// own (docs/api/placement.md).
final class PlacementLevel extends Equatable {
  const PlacementLevel({
    required this.id,
    required this.code,
    required this.cefr,
    required this.name,
  });

  /// The track's level to start from; empty for a step the learner can't
  /// start at.
  final String id;

  /// As shown, e.g. "Pre-A1", "A2".
  final String code;

  /// As the server names it, e.g. "pre_a1", "a2": what a learner at this
  /// step can do is told by it.
  final String cefr;
  final LocalizedText name;

  @override
  List<Object?> get props => [id, code, cefr, name];
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
    this.canLower = false,
  });

  /// The ladder, from the first step.
  final List<PlacementLevel> levels;

  /// Where the learner came out.
  final int levelIndex;
  final List<PlacementSkill> skills;

  /// The track has a level below the result to start from instead.
  final bool canLower;

  @override
  List<Object?> get props => [levels, levelIndex, skills, canLower];
}
