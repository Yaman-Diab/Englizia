import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';

/// A piece of a sentence shown in the feedback; [strong] for what was at stake.
final class AnswerPart {
  const AnswerPart(
    this.text, {
    this.strong = false,
    this.underlined = false,
    this.struck = false,
  });

  final String text;
  final bool strong;

  /// A word corrected.
  final bool underlined;

  /// The word that was wrong, shown next to its correction.
  final bool struck;
}

/// The whole right answer, its key parts strong (S §7.2). Empty for a template
/// with nothing to show, as each pair of a matching was checked in its time and
/// the learner's own words have no one right answer.
List<AnswerPart> correctAnswerParts(Exercise exercise) => switch (exercise) {
  final MultipleChoiceExercise e => [
    AnswerPart('${e.before} '),
    AnswerPart(_rightText(e), strong: true),
    AnswerPart(_startsWithPunctuation(e.after) ? e.after : ' ${e.after}'),
  ],
  final ImageChoiceExercise e => [AnswerPart(e.word, strong: true)],
  final ListenChooseExercise e => [
    AnswerPart(e.transcript ?? _rightText(e), strong: e.transcript == null),
  ],
  final FillChoicesExercise e => [
    for (final (i, segment) in e.segments.indexed) ...[
      AnswerPart(
        '${i == 0 ? '' : ' '}$segment${i < e.blanks.length ? ' ' : ''}',
      ),
      if (i < e.blanks.length) AnswerPart(e.blanks[i].answer, strong: true),
    ],
  ],
  final WordOrderExercise e => [AnswerPart(e.answer)],
  MatchingExercise() ||
  RepeatSentenceExercise() ||
  SpeakAnswerExercise() => const [],
  final ListenWriteExercise e => [AnswerPart(e.accepted.first)],
  final FillTypedExercise e => [
    AnswerPart('${e.before} '),
    AnswerPart(e.accepted.first, strong: true),
    AnswerPart(_startsWithPunctuation(e.after) ? e.after : ' ${e.after}'),
  ],
  final SentenceOrderExercise e => [AnswerPart(e.sentences.join('\n'))],
  final SpellingExercise e => [AnswerPart(e.word, strong: true)],
  final TranslationExercise e => [AnswerPart(e.accepted.first)],
  final ErrorCorrectionExercise e => [
    for (final (i, token) in e.tokens.indexed) ...[
      if (i > 0) const AnswerPart(' '),
      if (token.id == e.wrongTokenId) ...[
        AnswerPart(token.text, struck: true),
        const AnswerPart(' '),
        AnswerPart(e.correction, strong: true),
      ] else
        AnswerPart(token.text),
    ],
  ],
  final DialogueExercise e => [AnswerPart(_rightText(e), strong: true)],
  final ReadingExercise e => [AnswerPart(_rightText(e), strong: true)],
};

String _rightText(ChoiceExercise exercise) =>
    exercise.options.firstWhere((o) => o.id == exercise.answerId).text;

bool _startsWithPunctuation(String text) =>
    text.isNotEmpty && RegExp(r'^[.,?!;:]').hasMatch(text);

/// What the clip says, with what told it apart from the [chosenId] option
/// strong: the words the learner's choice doesn't have.
List<AnswerPart> heardParts(ListenChooseExercise exercise, String? chosenId) {
  final heard = exercise.transcript ?? _rightText(exercise);
  final chosen = exercise.options
      .where((o) => o.id == chosenId)
      .map((o) => plainWords(o.text).split(' '))
      .expand((words) => words)
      .toSet();
  final words = heard.split(' ');
  return [
    for (final (i, word) in words.indexed)
      AnswerPart(
        i < words.length - 1 ? '$word ' : word,
        strong: chosen.isNotEmpty && !chosen.contains(plainWords(word)),
      ),
  ];
}

/// Another right way to say it, so the learner knows it isn't the only one: the
/// first accepted form other than the one given (S §7.2).
String? otherRightForm(
  Exercise exercise,
  ExerciseDraft? draft,
  Evaluation evaluation,
) {
  if (exercise is TypedExercise && evaluation is TextEvaluation) {
    final at = evaluation.acceptedIndex ?? 0;
    return at == 0 ? null : exercise.accepted.first;
  }
  if (exercise is! WordOrderExercise || draft is! SequenceDraft) return null;
  final built = plainWords(draft.chips.map((c) => c.text).join(' '));
  for (final form in [exercise.answer, ...exercise.alternatives]) {
    if (plainWords(form) != built) return form;
  }
  return null;
}

/// The accepted form with the word the learner misspelled marked, when that is
/// how it was accepted (S §7.2).
List<AnswerPart>? spellingParts(Exercise exercise, Evaluation evaluation) {
  if (exercise is! TypedExercise || evaluation is! TextEvaluation) return null;
  final fixed = evaluation.fixedWord;
  if (fixed == null) return null;
  final words = exercise.accepted[evaluation.acceptedIndex ?? 0].split(' ');
  return [
    for (final (i, word) in words.indexed)
      AnswerPart(
        i < words.length - 1 ? '$word ' : word,
        strong: i == fixed,
        underlined: i == fixed,
      ),
  ];
}
