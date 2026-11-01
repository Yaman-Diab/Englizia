import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/grammar_model.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

const _kinds = {
  'word': SpanKind.word,
  'phrasalVerb': SpanKind.phrasalVerb,
  'idiom': SpanKind.idiom,
};

String _required(String? value) =>
    value ?? (throw const FormatException('Reader: a field is missing'));

Duration _ms(int? value) => Duration(
  milliseconds:
      value ?? (throw const FormatException('Reader: a time is missing')),
);

/// From an interactive text's or video's package. Null when it has none, or can't
/// be read: the page says so and offers to try again.
ReaderContent? readerFromJson(Map<String, Object?> lesson) {
  final json = lesson.readMap('reader');
  if (json == null) return null;
  try {
    final sentences = [
      for (final sentence in json.readList('sentences') ?? const <Object?>[])
        _sentence(asJsonMap(sentence)),
    ];
    if (sentences.isEmpty) {
      throw const FormatException('Reader: no sentences');
    }
    final video = _video(json);
    final audio = video == null ? asJsonMap(json['audio']) : null;
    return ReaderContent(
      audioUrl: audio == null ? '' : _required(audio.readString('url')),
      video: video,
      duration: video?.video.duration ?? _ms(audio?.readInt('durationMs')),
      sentences: sentences,
      spans: [
        for (final span in json.readList('spans') ?? const <Object?>[])
          ?_span(asJsonMap(span)),
      ],
    );
  } on FormatException catch (error, stackTrace) {
    AppLogger.error(error, stackTrace, 'Reader content unreadable');
    return null;
  }
}

ReaderVideo? _video(Map<String, Object?> json) {
  final video = json.readMap('video');
  if (video == null) return null;
  return ReaderVideo(
    video: lessonVideoFromJson(video),
    requiredPercent:
        json.readInt('requiredWatchPercent') ??
        (throw const FormatException('Reader: no watching required')),
    defaultSpeed: json.readDouble('defaultSpeed') ?? 1,
    savedWatch: switch (json.readMap('watch')) {
      final watch? => watchFromJson(watch),
      null => null,
    },
  );
}

ReaderSentence _sentence(Map<String, Object?> json) {
  final words = [
    for (final word in json.readList('words') ?? const <Object?>[])
      ReaderWord(
        id: _required(asJsonMap(word).readString('id')),
        text: _required(asJsonMap(word).readString('text')),
        start: _ms(asJsonMap(word).readInt('startMs')),
        end: _ms(asJsonMap(word).readInt('endMs')),
        gloss: asJsonMap(word).readString('gloss'),
      ),
  ];
  if (words.isEmpty) throw const FormatException('Reader: a sentence is empty');
  return ReaderSentence(
    id: _required(json.readString('id')),
    words: words,
    arabic: _required(json.readString('ar')),
    imageUrl: json.readString('image'),
    imageAlt: json.readString('imageAlt'),
    speaker: json.readString('speaker'),
    shadowing: json.readBool('shadowing') ?? false,
  );
}

/// A span of a kind this version doesn't know is only left unmarked.
ReaderSpan? _span(Map<String, Object?> json) {
  final kind = _kinds[json.readString('kind')];
  if (kind == null) return null;
  return ReaderSpan(
    id: _required(json.readString('id')),
    sentenceId: _required(json.readString('sentenceId')),
    wordIds: [
      for (final id in json.readList('wordIds') ?? const <Object?>[])
        if (id is String) id,
    ],
    kind: kind,
    base: _required(json.readString('base')),
    arabic: _required(json.readString('ar')),
    note: json.readString('note'),
    noteExample: [
      for (final part in json.readList('noteExample') ?? const <Object?>[])
        RulePart(
          _required(asJsonMap(part).readString('text')),
          strong: asJsonMap(part).readBool('strong') ?? false,
        ),
    ],
  );
}

ReaderPrefs readerPrefsFromJson(Map<String, Object?> json) => ReaderPrefs(
  size: ReaderTextSize.values.firstWhere(
    (size) => size.name == json.readString('size'),
    orElse: () => ReaderTextSize.medium,
  ),
  mode: ReaderMode.values.firstWhere(
    (mode) => mode.name == json.readString('mode'),
    orElse: () => ReaderMode.onTap,
  ),
  videoMode: ReaderMode.values.firstWhere(
    (mode) => mode.name == json.readString('videoMode'),
    orElse: () => ReaderMode.currentTranslated,
  ),
  stopEachSentence: json.readBool('stopEachSentence') ?? false,
);

Map<String, Object?> readerPrefsToJson(ReaderPrefs prefs) => {
  'size': prefs.size.name,
  'mode': prefs.mode.name,
  'videoMode': prefs.videoMode.name,
  'stopEachSentence': prefs.stopEachSentence,
};

/// A saved word as it is sent: all of it, as the panel may change the original.
Map<String, Object?> savedWordToJson(SavedWord word, {required bool saved}) => {
  'spanId': word.span.id,
  'saved': saved,
  if (saved) ...{
    'base': word.span.base,
    'kind': word.span.kind.name,
    'ar': word.span.arabic,
    'note': ?word.span.note,
    'sentence': {
      'en': word.sentence.english,
      'ar': word.sentence.arabic,
      if (word.videoId case final videoId?) ...{
        'videoId': videoId,
        'startMs': word.sentence.start.inMilliseconds,
        'endMs': word.sentence.end.inMilliseconds,
      },
    },
  },
};
