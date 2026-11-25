import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:equatable/equatable.dart';

/// Where a unit's test stands for the learner (the map's `units[].test`).
enum UnitTestState {
  /// The unit's lessons aren't all done yet.
  locked,
  available,

  /// Failed: another try opens at its time.
  cooldown,
  passed,
}

/// A unit's test as the map and the test itself say it stands.
final class UnitTestStatus extends Equatable {
  const UnitTestStatus({
    required this.state,
    required this.questionCount,
    required this.passPercent,
    this.bestPercent,
    this.retryAt,
  });

  final UnitTestState state;
  final int questionCount;
  final int passPercent;

  /// The best try so far; none before the first.
  final int? bestPercent;

  /// When another try opens, on the server's clock, while in cooldown.
  final DateTime? retryAt;

  @override
  List<Object?> get props => [
    state,
    questionCount,
    passPercent,
    bestPercent,
    retryAt,
  ];
}

/// A unit's test, its questions with no keys: the server marks it, the whole
/// of it sent at once (the backend's note B-33b). The options come in the
/// order the server gives, which is the learner's own.
final class UnitTest extends Equatable {
  const UnitTest({
    required this.id,
    required this.unitId,
    required this.versionId,
    required this.status,
    required this.questions,
  });

  final String id;
  final String unitId;

  /// The version answered: the answers go with it.
  final String versionId;
  final UnitTestStatus status;
  final List<Exercise> questions;

  @override
  List<Object?> get props => [id, unitId, versionId, status, questions];
}

/// A level by its names, as a result or a suggestion shows it.
final class LevelName extends Equatable {
  const LevelName({required this.id, required this.label, required this.name});

  final String id;

  /// «A2», or a grade's name.
  final String label;
  final String name;

  @override
  List<Object?> get props => [id, label, name];
}

/// After the first unit's test that follows the placement test: the server
/// suggests the level above or below, once, until the learner chooses.
final class LevelSuggestion extends Equatable {
  const LevelSuggestion({
    required this.id,
    required this.up,
    required this.percent,
    required this.level,
    required this.suggested,
  });

  final String id;

  /// The level above; else the one below.
  final bool up;
  final int percent;

  /// Where the learner is.
  final LevelName level;
  final LevelName suggested;

  @override
  List<Object?> get props => [id, up, percent, level, suggested];
}

/// What the server marked of a test sent.
final class UnitTestResult extends Equatable {
  const UnitTestResult({
    required this.correct,
    required this.questionCount,
    required this.percent,
    required this.passed,
    required this.passPercent,
    this.bestPercent,
    this.retryAt,
    this.marks = const [],
    this.suggestion,
  });

  final int correct;
  final int questionCount;
  final int percent;
  final bool passed;
  final int passPercent;
  final int? bestPercent;

  /// When another try opens, after a fail.
  final DateTime? retryAt;

  /// Right or wrong for each question, in the test's order; never the answer.
  final List<bool> marks;
  final LevelSuggestion? suggestion;

  @override
  List<Object?> get props => [
    correct,
    questionCount,
    percent,
    passed,
    passPercent,
    bestPercent,
    retryAt,
    marks,
    suggestion,
  ];
}
