import 'package:englizia/core/text/plain_words.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';

/// Marks an answer on the phone, for instant feedback even offline (S §7.1).
Evaluation evaluate(Exercise exercise, ExerciseDraft draft) => switch ((
  exercise,
  draft,
)) {
  (final ChoiceExercise exercise, final ChoiceDraft draft) => ChoiceEvaluation(
    chosenId: draft.optionId,
    rightId: exercise.answerId,
  ),
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
  (final SentenceOrderExercise exercise, final SlotsDraft draft) =>
    SlotsEvaluation([
      for (final (i, sentence) in exercise.sentences.indexed)
        draft.chips[i]?.text == sentence,
    ]),
  (final SpellingExercise exercise, final SlotsDraft draft) => SlotsEvaluation([
    for (var i = 0; i < exercise.word.length; i++)
      draft.chips[i]?.text == exercise.word[i],
  ]),
  (final TypedExercise exercise, final TextDraft draft) => _typed(
    exercise,
    draft.text,
  ),
  (final RepeatSentenceExercise exercise, final SpeechDraft draft) =>
    SpeechEvaluation(
      heard: draft.heard,
      correct:
          draft.heard.where((word) => word).length * 100 >=
          exercise.passPercent * draft.heard.length,
    ),
  (final ErrorCorrectionExercise exercise, final CorrectionDraft draft) =>
    CorrectionEvaluation(
      wordRight: draft.tokenId == exercise.wrongTokenId,
      correctionRight: draft.replacement == exercise.correction,
    ),
  // Only the server's AI can judge the learner's own words.
  (SpeakAnswerExercise(), SpokenDraft()) => const ReviewPending(),
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

TextEvaluation _typed(TypedExercise exercise, String text) {
  final typed = plainWords(text);
  final exact = [
    for (final form in exercise.accepted) plainWords(form),
  ].indexOf(typed);
  if (exact >= 0) return TextEvaluation(correct: true, acceptedIndex: exact);
  final minLetters = exercise.typoMinLetters;
  if (minLetters != null) {
    final words = typed.split(' ');
    for (final (i, form) in exercise.accepted.indexed) {
      final expected = plainWords(form).split(' ');
      if (expected.length != words.length) continue;
      final different = [
        for (var w = 0; w < words.length; w++)
          if (words[w] != expected[w]) w,
      ];
      if (different.length == 1 &&
          expected[different.single].length >= minLetters &&
          _oneEditApart(words[different.single], expected[different.single])) {
        return TextEvaluation(
          correct: true,
          acceptedIndex: i,
          fixedWord: different.single,
        );
      }
    }
  }
  return const TextEvaluation(correct: false);
}

/// One letter changed, added or removed.
bool _oneEditApart(String a, String b) {
  if ((a.length - b.length).abs() > 1) return false;
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  if (a.length == b.length) return a.substring(i + 1) == b.substring(i + 1);
  return a.length > b.length
      ? a.substring(i + 1) == b.substring(i)
      : a.substring(i) == b.substring(i + 1);
}
