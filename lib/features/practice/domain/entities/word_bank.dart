import 'package:equatable/equatable.dart';

/// What kind of word was saved, from a reader's span or a vocabulary card. An
/// unknown kind shows no badge.
enum WordKind {
  noun,
  verb,
  adjective,
  adverb,
  phrase,
  phrasalVerb,
  idiom,
  word,
}

/// Where a word was saved from, in a video: its sentence's moment, kept for
/// «شاهد المقطع» (S §10.3).
final class WordMoment extends Equatable {
  const WordMoment({required this.videoId, required this.start});

  final String videoId;
  final Duration start;

  @override
  List<Object?> get props => [videoId, start];
}

/// A word in the learner's bank: a copy, which later changes to the lesson don't
/// touch (S §10.2), and where it stands in the boxes.
final class BankWord extends Equatable {
  const BankWord({
    required this.id,
    required this.word,
    required this.arabic,
    required this.box,
    required this.dueAt,
    this.sentence = '',
    this.sentenceArabic = '',
    this.unitId,
    this.kind,
    this.highlighted = const {},
    this.imageUrl,
    this.audioUrl,
    this.sentenceAudioUrl,
    this.lessonTitle,
    this.moment,
  });

  final String id;
  final String word;
  final WordKind? kind;

  /// Its meaning in the sentence it was saved from.
  final String arabic;

  /// The lesson's sentence with it; a kids' word has none.
  final String sentence;
  final String sentenceArabic;

  /// The unit it came from, which kids filter by.
  final String? unitId;

  /// The places in [sentence], split by spaces, that are the word.
  final Set<int> highlighted;
  final String? imageUrl;
  final String? audioUrl;
  final String? sentenceAudioUrl;

  /// «من: يوم في المزرعة».
  final String? lessonTitle;
  final WordMoment? moment;

  /// 1 to 5: the longer it was known, the higher (S §10.2).
  final int box;

  /// From when it is due for review.
  final DateTime dueAt;

  BankWord copyWith({int? box, DateTime? dueAt}) => BankWord(
    id: id,
    word: word,
    kind: kind,
    arabic: arabic,
    sentence: sentence,
    sentenceArabic: sentenceArabic,
    highlighted: highlighted,
    imageUrl: imageUrl,
    audioUrl: audioUrl,
    sentenceAudioUrl: sentenceAudioUrl,
    lessonTitle: lessonTitle,
    moment: moment,
    box: box ?? this.box,
    dueAt: dueAt ?? this.dueAt,
  );

  @override
  List<Object?> get props => [
    id,
    word,
    kind,
    arabic,
    sentence,
    sentenceArabic,
    highlighted,
    imageUrl,
    audioUrl,
    sentenceAudioUrl,
    lessonTitle,
    moment,
    box,
    dueAt,
    unitId,
  ];
}

/// A unit the words came from, shown to kids by its picture.
final class BankUnit extends Equatable {
  const BankUnit({required this.id, required this.title, this.imageUrl});

  final String id;
  final String title;
  final String? imageUrl;

  @override
  List<Object?> get props => [id, title, imageUrl];
}

/// What the guide says in kids' «كلماتي» and its game, recorded once.
final class KidWordsVoice extends Equatable {
  const KidWordsVoice({this.words, this.empty, this.review, this.done});

  /// «هذه كلماتك.», «تعلّم كلمات في الدروس لتجمعها هنا.», «هل تعرف هذه
  /// الكلمة؟» and «رائع!».
  final String? words;
  final String? empty;
  final String? review;
  final String? done;

  @override
  List<Object?> get props => [words, empty, review, done];
}

/// Everything «تدرّب» shows: the bank, and the counts of what lies beside it.
final class WordBank extends Equatable {
  const WordBank({
    required this.words,
    this.sessionSize = 12,
    this.conceptsDue,
    this.savedSentences = 0,
    this.units = const [],
    this.kidsVoice = const KidWordsVoice(),
  });

  final List<BankWord> words;

  /// Kids mode: the units to filter by.
  final List<BankUnit> units;
  final KidWordsVoice kidsVoice;

  /// How many cards a review takes, from the panel.
  final int sessionSize;

  /// Concepts due today; null while the mistakes' bank is off (S §11).
  final int? conceptsDue;

  /// Sentences saved for practising saying them.
  final int savedSentences;

  WordBank copyWith({List<BankWord>? words}) => WordBank(
    words: words ?? this.words,
    sessionSize: sessionSize,
    conceptsDue: conceptsDue,
    savedSentences: savedSentences,
    units: units,
    kidsVoice: kidsVoice,
  );

  @override
  List<Object?> get props => [
    words,
    sessionSize,
    conceptsDue,
    savedSentences,
    units,
    kidsVoice,
  ];
}
