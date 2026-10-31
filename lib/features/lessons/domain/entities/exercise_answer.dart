import 'package:equatable/equatable.dart';

/// The answer as it stands, before checking. One per way of answering, not per
/// template: every choice template answers the same way.
sealed class ExerciseDraft extends Equatable {
  const ExerciseDraft();

  /// Enough of it to check.
  bool get isComplete;
}

final class ChoiceDraft extends ExerciseDraft {
  const ChoiceDraft(this.optionId);

  final String optionId;

  @override
  bool get isComplete => true;

  @override
  List<Object?> get props => [optionId];
}

/// What checking found on the phone: instant, and final only for what the
/// learner sees. The server marks it again, and its result is the official one.
sealed class Evaluation extends Equatable {
  const Evaluation();

  bool get correct;
}

final class ChoiceEvaluation extends Evaluation {
  const ChoiceEvaluation({required this.chosenId, required this.rightId});

  final String chosenId;
  final String rightId;

  @override
  bool get correct => chosenId == rightId;

  @override
  List<Object?> get props => [chosenId, rightId];
}

/// An answer checked, on its way to the server. [hinted] makes a right answer
/// an assisted success, not an independent one (S §7.1).
final class ExerciseAttempt extends Equatable {
  const ExerciseAttempt({
    required this.lessonId,
    required this.lessonVersion,
    required this.questionId,
    required this.draft,
    required this.hinted,
  });

  final String lessonId;
  final int lessonVersion;
  final String questionId;
  final ExerciseDraft draft;
  final bool hinted;

  @override
  List<Object?> get props => [
    lessonId,
    lessonVersion,
    questionId,
    draft,
    hinted,
  ];
}

/// Where a lesson's exercises stand on this phone. By question, not position,
/// so a newer version of the lesson or a hidden question can't misplace it.
final class ExerciseProgress extends Equatable {
  const ExerciseProgress({this.done = const {}, this.hinted = const {}});

  /// Questions checked: the learner carries on from the first one left.
  final Set<String> done;

  /// Questions whose hint was opened.
  final Set<String> hinted;

  bool get isEmpty => done.isEmpty && hinted.isEmpty;

  @override
  List<Object?> get props => [done, hinted];
}
