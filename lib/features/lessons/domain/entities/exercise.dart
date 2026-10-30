import 'package:englizia/core/l10n/localized_text.dart';
import 'package:equatable/equatable.dart';

/// The kinds of question this version shows; the server hides others.
enum ExerciseKind { multipleChoice, imageChoice, listeningChoice }

final class ExerciseOption extends Equatable {
  const ExerciseOption({
    required this.id,
    required this.correct,
    this.text = '',
    this.imageUrl = '',
    this.imageAlt,
  });

  final String id;

  /// Lessons' keys come with them, so "check" works offline (S §7.1); the
  /// server marks the answer again when it arrives.
  final bool correct;

  /// English, except that an image choice has [imageUrl] and [imageAlt] instead.
  final String text;
  final String imageUrl;
  final LocalizedText? imageAlt;

  @override
  List<Object?> get props => [id, correct, text, imageUrl, imageAlt];
}

final class ExerciseHint extends Equatable {
  const ExerciseHint({required this.text, this.term = ''});

  /// In the app's language, followed by [term].
  final LocalizedText text;

  /// The English word the hint points at.
  final String term;

  @override
  List<Object?> get props => [text, term];
}

/// One question of a lesson. Options come in the order to show them, shuffled
/// for this learner and steady on returning to it.
final class Exercise extends Equatable {
  const Exercise({
    required this.id,
    required this.kind,
    required this.instruction,
    required this.options,
    this.before = '',
    this.after = '',
    this.word = '',
    this.audioUrl = '',
    this.hint,
    this.bookReference,
  });

  final String id;
  final ExerciseKind kind;
  final LocalizedText instruction;
  final List<ExerciseOption> options;

  /// Multiple choice: the sentence around its blank.
  final String before;
  final String after;

  /// Image choice: the word the pictures are about.
  final String word;
  final String audioUrl;
  final ExerciseHint? hint;

  /// Imaar: where it is in the student's book.
  final LocalizedText? bookReference;

  @override
  List<Object?> get props => [
    id,
    kind,
    instruction,
    options,
    before,
    after,
    word,
    audioUrl,
    hint,
    bookReference,
  ];
}

/// An answer checked, on its way to the server. [hinted] makes a right answer
/// an assisted success, not an independent one (S §7.1).
final class ExerciseAnswer extends Equatable {
  const ExerciseAnswer({
    required this.lessonId,
    required this.questionId,
    required this.optionId,
    required this.hinted,
  });

  final String lessonId;
  final String questionId;
  final String optionId;
  final bool hinted;

  @override
  List<Object?> get props => [lessonId, questionId, optionId, hinted];
}

/// Where a lesson's exercises stand on this phone.
final class ExerciseProgress extends Equatable {
  const ExerciseProgress({this.position = 0, this.hinted = const {}});

  /// Questions done, which is the one to carry on from.
  final int position;

  /// Questions whose hint was opened.
  final Set<String> hinted;

  @override
  List<Object?> get props => [position, hinted];
}
