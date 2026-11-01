import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
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

/// What an interactive video adds to its text (S §8.4).
final class ReaderVideo extends Equatable {
  const ReaderVideo({
    required this.video,
    required this.requiredPercent,
    this.defaultSpeed = 1,
    this.savedWatch,
  });

  final LessonVideo video;

  /// Of the video really watched, from the panel.
  final int requiredPercent;

  /// From the panel: slower for kids.
  final double defaultSpeed;

  /// As the server last heard, from any phone.
  final WatchState? savedWatch;

  @override
  List<Object?> get props => [video, requiredPercent, defaultSpeed, savedWatch];
}

/// The text and media of a reader: an interactive text with its sound, and an
/// interactive video with its video as the time (S §8.2).
final class ReaderContent extends Equatable {
  const ReaderContent({
    required this.duration,
    required this.sentences,
    this.audioUrl = '',
    this.video,
    this.spans = const [],
  });

  /// A text's sound.
  final String audioUrl;

  /// A video's: then there is no [audioUrl].
  final ReaderVideo? video;
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
  List<Object?> get props => [audioUrl, video, duration, sentences, spans];
}

/// How the text shows (S §8.3, §8.4).
enum ReaderMode {
  onTap,
  below,
  currentTranslated,
  englishOnly,
  arabicFirst,
  arabicOnly,
  listening;

  static const forText = [onTap, below, arabicFirst, arabicOnly, listening];
  static const forVideo = [
    currentTranslated,
    arabicFirst,
    arabicOnly,
    englishOnly,
    listening,
  ];
}

enum ReaderTextSize { small, medium, large }

final class ReaderPrefs extends Equatable {
  const ReaderPrefs({
    this.size = ReaderTextSize.medium,
    this.mode = ReaderMode.onTap,
    this.videoMode = ReaderMode.currentTranslated,
    this.stopEachSentence = false,
  });

  final ReaderTextSize size;
  final ReaderMode mode;
  final ReaderMode videoMode;
  final bool stopEachSentence;

  ReaderPrefs copyWith({
    ReaderTextSize? size,
    ReaderMode? mode,
    ReaderMode? videoMode,
    bool? stopEachSentence,
  }) => ReaderPrefs(
    size: size ?? this.size,
    mode: mode ?? this.mode,
    videoMode: videoMode ?? this.videoMode,
    stopEachSentence: stopEachSentence ?? this.stopEachSentence,
  );

  @override
  List<Object?> get props => [size, mode, videoMode, stopEachSentence];
}

/// A span kept in the learner's word bank, whole: changing it in the panel later
/// doesn't change what was saved (S §8.2).
final class SavedWord extends Equatable {
  const SavedWord({
    required this.lessonId,
    required this.span,
    required this.sentence,
    this.videoId,
  });

  final String lessonId;
  final ReaderSpan span;
  final ReaderSentence sentence;

  /// With a video, the sentence's timing finds its moment again (S §8.4).
  final String? videoId;

  @override
  List<Object?> get props => [lessonId, span, sentence, videoId];
}
