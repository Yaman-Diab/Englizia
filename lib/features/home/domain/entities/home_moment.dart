import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:equatable/equatable.dart';

/// What home celebrates on coming back from a lesson: the day before it and
/// after it, and how today and the streak moved.
sealed class HomeMoment extends Equatable {
  const HomeMoment({
    required this.before,
    required this.after,
    required this.minutesFrom,
    required this.minutesTo,
    required this.goal,
    required this.streakFrom,
    required this.streakTo,
  });

  final HomeSnapshot before;
  final HomeSnapshot after;
  final int minutesFrom;
  final int minutesTo;
  final int goal;
  final int streakFrom;
  final int streakTo;

  /// Today's goal was reached by this lesson.
  bool get goalReached => minutesFrom < goal && minutesTo >= goal;

  @override
  List<Object?> get props => [
    before,
    after,
    minutesFrom,
    minutesTo,
    goal,
    streakFrom,
    streakTo,
  ];
}

/// A lesson of the current unit done, the unit not yet (M5).
final class LessonDoneMoment extends HomeMoment {
  const LessonDoneMoment({
    required super.before,
    required super.after,
    required this.lesson,
    required this.next,
    required super.minutesFrom,
    required super.minutesTo,
    required super.goal,
    required super.streakFrom,
    required super.streakTo,
  });

  /// The index of the lesson done (the current one before).
  final int lesson;

  /// The current lesson now.
  final int next;

  @override
  List<Object?> get props => [...super.props, lesson, next];
}

/// The current unit's last lesson done (M6), and maybe the level (M7).
final class UnitDoneMoment extends HomeMoment {
  const UnitDoneMoment({
    required super.before,
    required super.after,
    required this.unit,
    required this.nextUnit,
    required this.levelDone,
    required super.minutesFrom,
    required super.minutesTo,
    required super.goal,
    required super.streakFrom,
    required super.streakTo,
  });

  /// The index of the unit finished.
  final int unit;

  /// The index of the new current unit; null when [after] has none: the
  /// level's end, or a server not reached yet.
  final int? nextUnit;

  /// The level was completed by it: M7 follows M6.
  final bool levelDone;

  @override
  List<Object?> get props => [...super.props, unit, nextUnit, levelDone];
}
