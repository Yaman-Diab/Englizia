import 'package:equatable/equatable.dart';

/// A published lesson as the app answers it: its version, as an attempt counts
/// for the version it was answered on (server doc §19.2), and its exercises.
final class Lesson extends Equatable {
  const Lesson({
    required this.id,
    required this.version,
    required this.exercises,
  });

  final String id;
  final int version;
  final List<Exercise> exercises;

  @override
  List<Object?> get props => [id, version, exercises];
}

/// Where a question sits in the student's book, on Imaar lessons.
final class BookReference extends Equatable {
  const BookReference({required this.page, required this.exercise});

  final int page;
  final int exercise;

  @override
  List<Object?> get props => [page, exercise];
}

/// One question of a lesson. The set of templates is closed (S §7.3), and each
/// needs its own screen code anyway, so the compiler names every place a new
/// one must be handled.
sealed class Exercise extends Equatable {
  const Exercise({
    required this.id,
    required this.instruction,
    this.hint,
    this.bookReference,
  });

  final String id;

  /// In Arabic in both app languages, as the content has no other (S §7.1).
  final String instruction;

  /// Arabic, and may name an English word.
  final String? hint;
  final BookReference? bookReference;

  /// The clip to load, when the question has one.
  String? get clipUrl => null;

  /// Plays once by itself on opening (S §7.3).
  bool get autoplays => false;

  /// Checked as it goes, with no «تحقق» (S §7.3: matching).
  bool get checksItself => false;

  /// A clip that fails is the question's business, so it says so. Elsewhere the
  /// clip is only an extra, and goes quiet.
  bool get reportsClipFailure => false;

  @override
  List<Object?> get props => [id, instruction, hint, bookReference];
}

final class ExerciseOption extends Equatable {
  const ExerciseOption({
    required this.id,
    this.text = '',
    this.image = '',
    this.alt = '',
  });

  final String id;

  /// English, except that a picture has [image] and its Arabic name [alt].
  final String text;
  final String image;
  final String alt;

  @override
  List<Object?> get props => [id, text, image, alt];
}

/// One right option among several, in the order to show them. The key comes
/// with the lesson so "check" works offline (S §7.1); the server marks the
/// answer again when it arrives.
sealed class ChoiceExercise extends Exercise {
  const ChoiceExercise({
    required super.id,
    required super.instruction,
    required this.options,
    required this.answerId,
    super.hint,
    super.bookReference,
  });

  final List<ExerciseOption> options;
  final String answerId;

  @override
  List<Object?> get props => [...super.props, options, answerId];
}

/// A sentence with its blank, and the words for it.
final class MultipleChoiceExercise extends ChoiceExercise {
  const MultipleChoiceExercise({
    required super.id,
    required super.instruction,
    required super.options,
    required super.answerId,
    required this.before,
    required this.after,
    super.hint,
    super.bookReference,
  });

  final String before;
  final String after;

  @override
  List<Object?> get props => [...super.props, before, after];
}

/// A word with its sound, and the pictures for it.
final class ImageChoiceExercise extends ChoiceExercise {
  const ImageChoiceExercise({
    required super.id,
    required super.instruction,
    required super.options,
    required super.answerId,
    required this.word,
    this.audioUrl,
    super.hint,
    super.bookReference,
  });

  final String word;
  final String? audioUrl;

  @override
  String? get clipUrl => audioUrl;

  @override
  List<Object?> get props => [...super.props, word, audioUrl];
}

/// A clip, and the sentences it might have said.
final class ListenChooseExercise extends ChoiceExercise {
  const ListenChooseExercise({
    required super.id,
    required super.instruction,
    required super.options,
    required super.answerId,
    required this.audioUrl,
    super.hint,
    super.bookReference,
  });

  final String audioUrl;

  @override
  String? get clipUrl => audioUrl;

  @override
  bool get autoplays => true;

  @override
  bool get reportsClipFailure => true;

  @override
  List<Object?> get props => [...super.props, audioUrl];
}

/// A word card of a bank. Its [id] tells apart two cards with the same word.
final class WordChip extends Equatable {
  const WordChip({required this.id, required this.text});

  final String id;
  final String text;

  @override
  List<Object?> get props => [id, text];
}

final class FillBlank extends Equatable {
  const FillBlank({required this.answer, this.alternatives = const []});

  final String answer;
  final List<String> alternatives;

  bool accepts(String word) => word == answer || alternatives.contains(word);

  @override
  List<Object?> get props => [answer, alternatives];
}

/// A sentence with blanks, and word cards with some extra among them.
final class FillChoicesExercise extends Exercise {
  const FillChoicesExercise({
    required super.id,
    required super.instruction,
    required this.segments,
    required this.blanks,
    required this.bank,
    super.hint,
    super.bookReference,
  });

  /// The sentence around the blanks: one more than [blanks].
  final List<String> segments;
  final List<FillBlank> blanks;

  /// In the order to show them.
  final List<WordChip> bank;

  @override
  List<Object?> get props => [...super.props, segments, blanks, bank];
}

/// The meaning in Arabic, and word cards to build the English with.
final class WordOrderExercise extends Exercise {
  const WordOrderExercise({
    required super.id,
    required super.instruction,
    required this.meaning,
    required this.answer,
    required this.answerWords,
    required this.bank,
    this.alternatives = const [],
    super.hint,
    super.bookReference,
  });

  final String meaning;
  final String answer;

  /// [answer] as cards, in order.
  final List<String> answerWords;

  /// Other orders that are right too.
  final List<String> alternatives;

  /// In the order to show them.
  final List<WordChip> bank;

  @override
  List<Object?> get props => [
    ...super.props,
    meaning,
    answer,
    answerWords,
    alternatives,
    bank,
  ];
}

/// A word and what it goes with: a [meaning], or a picture with its name.
final class MatchPair extends Equatable {
  const MatchPair({
    required this.id,
    this.meaning = '',
    this.image = '',
    this.alt = '',
  });

  /// The English word, which is unique in its question.
  final String id;
  final String meaning;
  final String image;
  final String alt;

  @override
  List<Object?> get props => [id, meaning, image, alt];
}

/// Pairs to put together, in two columns shuffled apart.
final class MatchingExercise extends Exercise {
  const MatchingExercise({
    required super.id,
    required super.instruction,
    required this.pairs,
    required this.meaningsShown,
    required this.wordsShown,
    required this.pictures,
    super.hint,
    super.bookReference,
  });

  final List<MatchPair> pairs;
  final List<MatchPair> meaningsShown;
  final List<MatchPair> wordsShown;

  /// A word goes with a picture.
  final bool pictures;

  @override
  bool get checksItself => true;

  @override
  List<Object?> get props => [
    ...super.props,
    pairs,
    meaningsShown,
    wordsShown,
    pictures,
  ];
}
