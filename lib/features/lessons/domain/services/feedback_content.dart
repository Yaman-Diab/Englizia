import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';

/// A piece of a sentence shown in the feedback; [strong] for what was at stake.
final class AnswerPart {
  const AnswerPart(this.text, {this.strong = false});

  final String text;
  final bool strong;
}

/// The whole right answer, its key parts strong (S §7.2). Empty for a template
/// with nothing to show, as each pair of a matching was checked in its time.
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
  MatchingExercise() => const [],
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

/// Another right way to say it, so the learner knows the order isn't the only
/// one: the first accepted form other than the one built (S §7.2).
String? otherRightForm(Exercise exercise, ExerciseDraft? draft) {
  if (exercise is! WordOrderExercise || draft is! SequenceDraft) return null;
  final built = plainWords(draft.chips.map((c) => c.text).join(' '));
  for (final form in [exercise.answer, ...exercise.alternatives]) {
    if (plainWords(form) != built) return form;
  }
  return null;
}
