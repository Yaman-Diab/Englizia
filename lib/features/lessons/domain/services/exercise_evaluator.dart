import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';

/// Marks an answer on the phone, for instant feedback even offline (S §7.1).
Evaluation evaluate(Exercise exercise, ExerciseDraft draft) =>
    switch ((exercise, draft)) {
      (final ChoiceExercise exercise, final ChoiceDraft draft) =>
        ChoiceEvaluation(chosenId: draft.optionId, rightId: exercise.answerId),
      (final FillChoicesExercise exercise, final SlotsDraft draft) =>
        SlotsEvaluation([
          for (final (i, blank) in exercise.blanks.indexed)
            draft.chips[i] != null && blank.accepts(draft.chips[i]!.text),
        ]),
      (final WordOrderExercise exercise, final SequenceDraft draft) => _order(
        exercise,
        draft,
      ),
      (MatchingExercise(), final PairsDraft draft) => PairsEvaluation(
        mistakes: draft.mistakes,
      ),
      _ => throw ArgumentError.value(draft, 'draft', 'Not for this exercise'),
    };

SequenceEvaluation _order(WordOrderExercise exercise, SequenceDraft draft) {
  final built = plainWords(draft.chips.map((chip) => chip.text).join(' '));
  final right = [
    exercise.answer,
    ...exercise.alternatives,
  ].any((sentence) => plainWords(sentence) == built);
  final expected = [for (final word in exercise.answerWords) plainWords(word)];
  return SequenceEvaluation(
    correct: right,
    needsReview:
        !right &&
        exercise.reviewable.any((sentence) => plainWords(sentence) == built),
    words: [
      for (final (i, chip) in draft.chips.indexed)
        right || (i < expected.length && plainWords(chip.text) == expected[i]),
    ],
  );
}

/// [text] as compared: no case, punctuation or extra spaces (S §7.4).
String plainWords(String text) => text
    .toLowerCase()
    .replaceAll('\u2019', "'")
    .replaceAll(RegExp("[^a-z0-9' ]+"), ' ')
    .replaceAll(RegExp(' +'), ' ')
    .trim();
