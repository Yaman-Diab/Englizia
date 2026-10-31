import 'package:equatable/equatable.dart';

/// The kinds of lesson a unit is made of, each with its one icon (S §8).
enum LessonKind {
  vocabulary,
  interactiveVideo,
  grammarVideo,
  interactiveText,
  conversation,
  unitReview,

  /// One this version doesn't know.
  other,
}

/// One lesson of a unit's chain.
final class UnitStep extends Equatable {
  const UnitStep({
    required this.lessonId,
    required this.kind,
    required this.done,
  });

  final String lessonId;
  final LessonKind kind;
  final bool done;

  @override
  List<Object?> get props => [lessonId, kind, done];
}

final class UnitProgress extends Equatable {
  const UnitProgress({
    required this.number,
    required this.title,
    required this.steps,
  });

  final int number;
  final String title;
  final List<UnitStep> steps;

  /// How many in a row are done, which is how far the chain has come.
  int get doneInARow {
    final first = steps.indexWhere((step) => !step.done);
    return first < 0 ? steps.length : first;
  }

  /// With [lessonId] done, as the phone knows before the server says so.
  UnitProgress withDone(String lessonId) => UnitProgress(
    number: number,
    title: title,
    steps: [
      for (final step in steps)
        step.lessonId == lessonId
            ? UnitStep(lessonId: lessonId, kind: step.kind, done: true)
            : step,
    ],
  );

  @override
  List<Object?> get props => [number, title, steps];
}

enum NextKind { lesson, unitReview, unit }

/// What comes after this lesson. With none, the track has ended here.
final class NextStep extends Equatable {
  const NextStep({
    required this.kind,
    this.title = '',
    this.lessonId,
    this.lessonKind = LessonKind.other,
    this.unitNumber,
  });

  final NextKind kind;
  final String title;
  final String? lessonId;
  final LessonKind lessonKind;
  final int? unitNumber;

  @override
  List<Object?> get props => [kind, title, lessonId, lessonKind, unitNumber];
}

/// What the lesson's package says of its place, so its end can show it offline.
final class LessonOutline extends Equatable {
  const LessonOutline({
    this.title,
    this.replay = false,
    this.earnsXp = false,
    this.unit,
    this.next,
  });

  final String? title;

  /// The learner had already completed this lesson.
  final bool replay;

  /// Points are on, so the end has a place for them.
  final bool earnsXp;
  final UnitProgress? unit;
  final NextStep? next;

  @override
  List<Object?> get props => [title, replay, earnsXp, unit, next];
}

/// What the phone knows when the last question is done.
final class LessonSummary extends Equatable {
  const LessonSummary({
    required this.lessonId,
    required this.lessonVersion,
    required this.rightFirstTime,
    required this.counted,
    required this.pending,
    required this.seconds,
    required this.outline,
  });

  final String lessonId;
  final int lessonVersion;
  final int rightFirstTime;

  /// Questions that count: without those skipped or waiting to be judged (S §7.6).
  final int counted;

  /// Questions waiting for the server to judge them.
  final int pending;
  final int seconds;
  final LessonOutline outline;

  @override
  List<Object?> get props => [
    lessonId,
    lessonVersion,
    rightFirstTime,
    counted,
    pending,
    seconds,
    outline,
  ];
}

/// Minutes today, before this lesson and now.
final class DailyGoal extends Equatable {
  const DailyGoal({
    required this.before,
    required this.now,
    required this.target,
  });

  final int before;
  final int now;
  final int target;

  bool get met => now >= target;

  /// It was this lesson that reached it.
  bool get justMet => met && before < target;

  @override
  List<Object?> get props => [before, now, target];
}

final class StreakDays extends Equatable {
  const StreakDays({required this.before, required this.now});

  final int before;
  final int now;

  @override
  List<Object?> get props => [before, now];
}

/// What the server says of the lesson once it has the answers: the official
/// numbers. Whatever it leaves out isn't shown, or stays as the phone counted it.
final class LessonResult extends Equatable {
  const LessonResult({
    this.xp,
    this.rightFirstTime,
    this.counted,
    this.seconds,
    this.pending,
    this.wordsSaved = 0,
    this.concepts = const [],
    this.goal,
    this.streak,
    this.unit,
    this.next,
    this.replay,
  });

  final int? xp;
  final int? rightFirstTime;
  final int? counted;
  final int? seconds;
  final int? pending;
  final int wordsSaved;

  /// To review with the learner: their Arabic names from the panel.
  final List<String> concepts;
  final DailyGoal? goal;
  final StreakDays? streak;
  final UnitProgress? unit;
  final NextStep? next;
  final bool? replay;

  @override
  List<Object?> get props => [
    xp,
    rightFirstTime,
    counted,
    seconds,
    pending,
    wordsSaved,
    concepts,
    goal,
    streak,
    unit,
    next,
    replay,
  ];
}
