import 'package:equatable/equatable.dart';

/// A published lesson as the app answers it: its version, as an attempt counts
/// for the version it was answered on (server doc §19.2), and its exercises.
final class Lesson extends Equatable {
  const Lesson({
    required this.id,
    required this.version,
    required this.exercises,
    this.xpPerAnswer,
    this.explainEnabled = false,
  });

  final String id;
  final int version;
  final List<Exercise> exercises;

  /// What a right answer earns, from the panel (v1.0). With none, no badge.
  final int? xpPerAnswer;

  /// «اشرح لي» is on: by the track's settings and the day's limit.
  final bool explainEnabled;

  @override
  List<Object?> get props => [
    id,
    version,
    exercises,
    xpPerAnswer,
    explainEnabled,
  ];
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
    this.explanation,
    this.answerAudioUrl,
  });

  final String id;

  /// In Arabic in both app languages, as the content has no other (S §7.1).
  final String instruction;

  /// Arabic, and may name an English word.
  final String? hint;
  final BookReference? bookReference;

  /// Why, shown after a wrong answer: Arabic, a paragraph per line.
  final String? explanation;

  /// The right sentence said, for the feedback.
  final String? answerAudioUrl;

  /// The clip to load, when the question has one.
  String? get clipUrl => null;

  /// The clip the feedback plays.
  String? get answerClipUrl => answerAudioUrl ?? clipUrl;

  /// Plays once by itself on opening (S §7.3).
  bool get autoplays => false;

  /// Checked as it goes, with no «تحقق» (S §7.3: matching, speech).
  bool get checksItself => false;

  /// Said aloud: it can be skipped for this lesson, and can't be wrong (S §7.5).
  bool get isSpeech => false;

  /// A clip that fails is the question's business, so it says so. Elsewhere the
  /// clip is only an extra, and goes quiet.
  bool get reportsClipFailure => false;

  /// Questions with the same value share what surrounds them, and only what is
  /// their own moves from one to the next (S §7.3: a text's questions).
  String get stayKey => id;

  @override
  List<Object?> get props => [
    id,
    instruction,
    hint,
    bookReference,
    explanation,
    answerAudioUrl,
  ];
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
    super.explanation,
    super.answerAudioUrl,
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
    super.explanation,
    super.answerAudioUrl,
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
    super.explanation,
    super.answerAudioUrl,
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
    this.transcript,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  final String audioUrl;

  /// What the clip says, shown after a wrong answer.
  final String? transcript;

  @override
  String? get clipUrl => audioUrl;

  @override
  bool get autoplays => true;

  @override
  bool get reportsClipFailure => true;

  @override
  List<Object?> get props => [...super.props, audioUrl, transcript];
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
    super.explanation,
    super.answerAudioUrl,
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
    this.reviewable = const [],
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  final String meaning;
  final String answer;

  /// [answer] as cards, in order.
  final List<String> answerWords;

  /// Other orders that are right too.
  final List<String> alternatives;

  /// Orders not known to be right or wrong: the server judges them.
  final List<String> reviewable;

  /// In the order to show them.
  final List<WordChip> bank;

  @override
  List<Object?> get props => [
    ...super.props,
    meaning,
    answer,
    answerWords,
    alternatives,
    reviewable,
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
    super.explanation,
    super.answerAudioUrl,
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

/// Listen, then say it.
final class RepeatSentenceExercise extends Exercise {
  const RepeatSentenceExercise({
    required super.id,
    required super.instruction,
    required this.sentence,
    required this.audioUrl,
    required this.passPercent,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  final String sentence;
  final String audioUrl;

  /// Of the words heard, from the panel (S §7.3).
  final int passPercent;

  List<String> get words => sentence.split(' ');

  @override
  String? get clipUrl => audioUrl;

  @override
  bool get autoplays => true;

  @override
  bool get reportsClipFailure => true;

  @override
  bool get checksItself => true;

  @override
  bool get isSpeech => true;

  @override
  List<Object?> get props => [...super.props, sentence, audioUrl, passPercent];
}

/// An answer typed by the learner, against saved accepted forms (S §7.4).
sealed class TypedExercise extends Exercise {
  const TypedExercise({
    required super.id,
    required super.instruction,
    required this.accepted,
    this.typoMinLetters,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  /// The first is the one shown to a learner who got it wrong.
  final List<String> accepted;

  /// Words at least this long may have one wrong letter; null accepts none.
  final int? typoMinLetters;

  @override
  List<Object?> get props => [...super.props, accepted, typoMinLetters];
}

/// A clip, and a field to write what it says.
final class ListenWriteExercise extends TypedExercise {
  const ListenWriteExercise({
    required super.id,
    required super.instruction,
    required super.accepted,
    required this.audioUrl,
    super.typoMinLetters,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
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

/// A sentence with a blank to type in, and its base word in brackets.
final class FillTypedExercise extends TypedExercise {
  const FillTypedExercise({
    required super.id,
    required super.instruction,
    required super.accepted,
    required this.before,
    required this.after,
    required this.baseWord,
    super.typoMinLetters,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  final String before;
  final String after;
  final String baseWord;

  @override
  List<Object?> get props => [...super.props, before, after, baseWord];
}

/// Sentences to put in order.
final class SentenceOrderExercise extends Exercise {
  const SentenceOrderExercise({
    required super.id,
    required super.instruction,
    required this.sentences,
    required this.bank,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  /// In the right order.
  final List<String> sentences;

  /// The same, in the order to show them.
  final List<WordChip> bank;

  @override
  List<Object?> get props => [...super.props, sentences, bank];
}

/// A word's picture and sound, and letters to spell it with.
final class SpellingExercise extends Exercise {
  const SpellingExercise({
    required super.id,
    required super.instruction,
    required this.word,
    required this.image,
    required this.alt,
    required this.bank,
    this.audioUrl,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  final String word;
  final String image;
  final String alt;
  final String? audioUrl;

  /// The word's letters and the extra ones, in the order to show them.
  final List<WordChip> bank;

  @override
  String? get clipUrl => audioUrl;

  @override
  List<Object?> get props => [...super.props, word, image, alt, audioUrl, bank];
}

/// An Arabic sentence to write in English, against the saved translations.
final class TranslationExercise extends TypedExercise {
  const TranslationExercise({
    required super.id,
    required super.instruction,
    required super.accepted,
    required this.arabic,
    super.typoMinLetters,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  final String arabic;

  @override
  List<Object?> get props => [...super.props, arabic];
}

/// A sentence with one wrong word: find it, then choose its correction.
final class ErrorCorrectionExercise extends Exercise {
  const ErrorCorrectionExercise({
    required super.id,
    required super.instruction,
    required this.tokens,
    required this.wrongTokenId,
    required this.correction,
    required this.corrections,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  /// The sentence's words, in order.
  final List<WordChip> tokens;
  final String wrongTokenId;
  final String correction;

  /// [correction] among the wrong ones, in the order to show them.
  final List<WordChip> corrections;

  @override
  List<Object?> get props => [
    ...super.props,
    tokens,
    wrongTokenId,
    correction,
    corrections,
  ];
}

/// A line of a conversation: the character's, or the learner's to fill.
final class DialogueLine extends Equatable {
  const DialogueLine.character(this.text) : isLearner = false;

  const DialogueLine.learner() : text = '', isLearner = true;

  final String text;
  final bool isLearner;

  @override
  List<Object?> get props => [text, isLearner];
}

/// A conversation missing the learner's line, and replies to choose it from.
final class DialogueExercise extends ChoiceExercise {
  const DialogueExercise({
    required super.id,
    required super.instruction,
    required super.options,
    required super.answerId,
    required this.characterName,
    required this.lines,
    this.characterAvatar,
    super.hint,
    super.bookReference,
    super.explanation,
    super.answerAudioUrl,
  });

  final String characterName;
  final String? characterAvatar;
  final List<DialogueLine> lines;

  @override
  List<Object?> get props => [
    ...super.props,
    characterName,
    characterAvatar,
    lines,
  ];
}

/// The text its questions are about.
final class ReadingPassage extends Equatable {
  const ReadingPassage({
    required this.id,
    required this.title,
    required this.text,
    this.audioUrl,
  });

  final String id;
  final String title;
  final String text;
  final String? audioUrl;

  @override
  List<Object?> get props => [id, title, text, audioUrl];
}

/// One question about a text. Each is its own step of the lesson, checked alone,
/// and the text stays still between them (S §7.3).
final class ReadingExercise extends ChoiceExercise {
  const ReadingExercise({
    required super.id,
    required super.instruction,
    required super.options,
    required super.answerId,
    required this.passage,
    required this.ask,
    required this.step,
    required this.steps,
    super.hint,
    super.bookReference,
    super.explanation,
  });

  final ReadingPassage passage;
  final String ask;

  /// Which of the text's questions this is, from 1.
  final int step;
  final int steps;

  @override
  String? get clipUrl => passage.audioUrl;

  /// The whole text isn't the answer: the feedback has nothing to play.
  @override
  String? get answerClipUrl => null;

  @override
  String get stayKey => passage.id;

  @override
  List<Object?> get props => [...super.props, passage, ask, step, steps];
}

/// A question to answer in the learner's own words, spoken or typed, judged by
/// the server's AI (S §16). It checks itself once spoken; typing has «تحقق».
final class SpeakAnswerExercise extends Exercise {
  const SpeakAnswerExercise({
    required super.id,
    required super.instruction,
    required this.ask,
    this.audioUrl,
    super.hint,
    super.bookReference,
  });

  final String ask;
  final String? audioUrl;

  @override
  String? get clipUrl => audioUrl;

  @override
  bool get autoplays => audioUrl != null;

  @override
  bool get checksItself => true;

  @override
  bool get isSpeech => true;

  @override
  List<Object?> get props => [...super.props, ask, audioUrl];
}
