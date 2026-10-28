import 'package:englizia/core/error/failure.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';
import 'package:equatable/equatable.dart';

/// What a step of "preparing" does (S §4.4).
enum PreparingStepKind {
  /// Starts the session and settles the starting level.
  level,

  /// Starts the session at the school student's grade.
  grade,

  /// Starts the session of a learner who takes the placement test first.
  plan,

  /// Loads the first unit of the level or grade.
  unit,

  /// Loads the placement test's summary.
  test,

  /// Settles the daily goal.
  goal,
}

enum PreparingStepStatus { pending, running, done, failed }

final class PreparingStep extends Equatable {
  const PreparingStep(this.kind, [this.status = PreparingStepStatus.pending]);

  final PreparingStepKind kind;
  final PreparingStepStatus status;

  @override
  List<Object?> get props => [kind, status];
}

final class PreparingState extends Equatable {
  const PreparingState({
    this.steps = const [],
    this.level,
    this.unit,
    this.test,
    this.goalMinutes,
    this.failure,
  });

  /// In the order they run; one at a time.
  final List<PreparingStep> steps;

  /// The starting level or grade, once known.
  final TrackLevel? level;

  /// The level's first unit; null when the level has none published.
  final TrackUnit? unit;
  final PlacementSummary? test;
  final int? goalMinutes;

  /// Why the failed step failed; retrying resumes from that step.
  final Failure? failure;

  bool get ready =>
      steps.isNotEmpty &&
      steps.every((step) => step.status == PreparingStepStatus.done);

  bool get failed =>
      steps.any((step) => step.status == PreparingStepStatus.failed);

  /// The learner chose the placement test: it comes next, not a lesson.
  bool get takesTest =>
      steps.any((step) => step.kind == PreparingStepKind.test);

  PreparingState withStatus(int index, PreparingStepStatus status) => copyWith(
    steps: [
      for (final (i, step) in steps.indexed)
        i == index ? PreparingStep(step.kind, status) : step,
    ],
  );

  PreparingState copyWith({
    List<PreparingStep>? steps,
    TrackLevel? level,
    TrackUnit? unit,
    PlacementSummary? test,
    int? goalMinutes,
    Failure? Function()? failure,
  }) => PreparingState(
    steps: steps ?? this.steps,
    level: level ?? this.level,
    unit: unit ?? this.unit,
    test: test ?? this.test,
    goalMinutes: goalMinutes ?? this.goalMinutes,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [steps, level, unit, test, goalMinutes, failure];
}
