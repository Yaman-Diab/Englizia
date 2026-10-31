import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:equatable/equatable.dart';

/// A word of a sentence, its punctuation stuck to it: nothing else is tappable or
/// lit (S §8.2). [gloss] is its meaning when it belongs to no span.
final class ReaderWord extends Equatable {
  const ReaderWord({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
    this.gloss,
  });

  final String id;
  final String text;
  final Duration start;
  final Duration end;
  final String? gloss;

  @override
  List<Object?> get props => [id, text, start, end, gloss];
}

final class ReaderSentence extends Equatable {
  const ReaderSentence({
    required this.id,
    required this.words,
    required this.arabic,
    this.imageUrl,
    this.imageAlt,
    this.speaker,
    this.shadowing = false,
  });

  final String id;
  final List<ReaderWord> words;
  final String arabic;
  final String? imageUrl;
  final String? imageAlt;

  /// For a conversation in a video.
  final String? speaker;

  /// One of the sentences practised after the text.
  final bool shadowing;

  String get english => words.map((word) => word.text).join(' ');

  Duration get start => words.first.start;

  Duration get end => words.last.end;

  @override
  List<Object?> get props => [
    id,
    words,
    arabic,
    imageUrl,
    imageAlt,
    speaker,
    shadowing,
  ];
}

enum SpanKind { word, phrasalVerb, idiom }

/// Words that go together, side by side or not, in one sentence, and what they
/// mean there. No word is in two spans.
final class ReaderSpan extends Equatable {
  const ReaderSpan({
    required this.id,
    required this.sentenceId,
    required this.wordIds,
    required this.kind,
    required this.base,
    required this.arabic,
    this.note,
    this.noteExample = const [],
  });

  final String id;
  final String sentenceId;
  final List<String> wordIds;
  final SpanKind kind;

  /// The form to learn, whatever the sentence made of it.
  final String base;

  /// In this sentence's sense.
  final String arabic;
  final String? note;
  final List<RulePart> noteExample;

  @override
  List<Object?> get props => [
    id,
    sentenceId,
    wordIds,
    kind,
    base,
    arabic,
    note,
    noteExample,
  ];
}

/// Where a moment of the sound falls.
typedef ReaderPlace = ({int sentence, int? word});

/// The text and sound of a reader. An interactive video shares all of this, with
/// its video as the time (S §8.2).
final class ReaderContent extends Equatable {
  const ReaderContent({
    required this.audioUrl,
    required this.duration,
    required this.sentences,
    this.spans = const [],
  });

  final String audioUrl;
  final Duration duration;
  final List<ReaderSentence> sentences;
  final List<ReaderSpan> spans;

  bool get hasShadowing => sentences.any((s) => s.shadowing);

  /// The span the word belongs to.
  ReaderSpan? spanOf(ReaderSentence sentence, ReaderWord word) {
    for (final span in spans) {
      if (span.sentenceId == sentence.id && span.wordIds.contains(word.id)) {
        return span;
      }
    }
    return null;
  }

  /// The sentence going on at [position], or the next one between two; and its
  /// word being said, if any.
  ReaderPlace placeAt(Duration position) {
    for (final (s, sentence) in sentences.indexed) {
      if (position < sentence.end) {
        int? said;
        for (final (w, word) in sentence.words.indexed) {
          if (position >= word.start) said = w;
        }
        return (sentence: s, word: said);
      }
    }
    return (sentence: sentences.length - 1, word: null);
  }

  @override
  List<Object?> get props => [audioUrl, duration, sentences, spans];
}

/// How the text shows (S §8.3).
enum ReaderMode { onTap, below, arabicFirst, arabicOnly, listening }

enum ReaderTextSize { small, medium, large }

final class ReaderPrefs extends Equatable {
  const ReaderPrefs({
    this.size = ReaderTextSize.medium,
    this.mode = ReaderMode.onTap,
    this.stopEachSentence = false,
  });

  final ReaderTextSize size;
  final ReaderMode mode;
  final bool stopEachSentence;

  ReaderPrefs copyWith({
    ReaderTextSize? size,
    ReaderMode? mode,
    bool? stopEachSentence,
  }) => ReaderPrefs(
    size: size ?? this.size,
    mode: mode ?? this.mode,
    stopEachSentence: stopEachSentence ?? this.stopEachSentence,
  );

  @override
  List<Object?> get props => [size, mode, stopEachSentence];
}

/// A span kept in the learner's word bank, whole: changing it in the panel later
/// doesn't change what was saved (S §8.2).
final class SavedWord extends Equatable {
  const SavedWord({
    required this.lessonId,
    required this.span,
    required this.sentence,
  });

  final String lessonId;
  final ReaderSpan span;
  final ReaderSentence sentence;

  @override
  List<Object?> get props => [lessonId, span, sentence];
}
