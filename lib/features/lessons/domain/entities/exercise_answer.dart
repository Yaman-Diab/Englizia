import 'package:englizia/features/lessons/domain/entities/exercise.dart';
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

/// Words in blanks, each blank holding one or none.
final class SlotsDraft extends ExerciseDraft {
  const SlotsDraft(this.chips);

  final List<WordChip?> chips;

  @override
  bool get isComplete => chips.every((chip) => chip != null);

  @override
  List<Object?> get props => [chips];
}

/// Words in the order they were placed.
final class SequenceDraft extends ExerciseDraft {
  const SequenceDraft(this.chips, {required this.needed});

  final List<WordChip> chips;

  /// How many words the answer has.
  final int needed;

  @override
  bool get isComplete => chips.length >= needed;

  @override
  List<Object?> get props => [chips, needed];
}

/// The pairs found so far, and those with a mistake on the way.
final class PairsDraft extends ExerciseDraft {
  const PairsDraft({
    required this.total,
    this.matched = const {},
    this.mistakes = const {},
  });

  final int total;

  /// Pair ids.
  final Set<String> matched;
  final Set<String> mistakes;

  @override
  bool get isComplete => matched.length >= total;

  @override
  List<Object?> get props => [total, matched, mistakes];
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

/// Each blank's verdict, in order.
final class SlotsEvaluation extends Evaluation {
  const SlotsEvaluation(this.slots);

  final List<bool> slots;

  @override
  bool get correct => slots.every((right) => right);

  @override
  List<Object?> get props => [slots];
}

/// Each placed word's verdict, in order. Right as a whole may also mean another
/// accepted order, whose words all count as right.
final class SequenceEvaluation extends Evaluation {
  const SequenceEvaluation({
    required this.words,
    required this.correct,
    this.needsReview = false,
  });

  final List<bool> words;

  @override
  final bool correct;

  /// Not right as far as the phone knows, but for the server to judge.
  final bool needsReview;

  @override
  List<Object?> get props => [words, correct, needsReview];
}

/// An order the phone can't judge: the server is looking at it, so no verdict
/// yet, and no «التالي» either.
final class ReviewPending extends Evaluation {
  const ReviewPending();

  @override
  bool get correct => false;

  @override
  List<Object?> get props => const [];
}

/// The server couldn't judge it now. It will later, and it won't count as wrong
/// (S §16.3).
final class ReviewLater extends Evaluation {
  const ReviewLater();

  @override
  bool get correct => false;

  @override
  List<Object?> get props => const [];
}

/// All the pairs found: each was checked in its own time.
final class PairsEvaluation extends Evaluation {
  const PairsEvaluation({required this.mistakes});

  final Set<String> mistakes;

  @override
  bool get correct => true;

  @override
  List<Object?> get props => [mistakes];
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

/// What a learner can report about a question (S §18).
enum ProblemReason { alsoRight, audio, question, translation, other }

/// A learner's report, sent with its context: the question, its version and the
/// answer. The app's version and platform go in every request's headers.
final class ExerciseReport extends Equatable {
  const ExerciseReport({
    required this.lessonId,
    required this.lessonVersion,
    required this.questionId,
    required this.reason,
    this.draft,
  });

  final String lessonId;
  final int lessonVersion;
  final String questionId;
  final ProblemReason reason;
  final ExerciseDraft? draft;

  @override
  List<Object?> get props => [
    lessonId,
    lessonVersion,
    questionId,
    reason,
    draft,
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
