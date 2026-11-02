import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/domain/entities/vocabulary.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

const _kinds = {
  'noun': VocabKind.noun,
  'verb': VocabKind.verb,
  'adjective': VocabKind.adjective,
  'adverb': VocabKind.adverb,
  'phrase': VocabKind.phrase,
};

String _required(String? value) =>
    value ?? (throw const FormatException('Vocabulary: a field is missing'));

Duration? _ms(int? value) =>
    value == null ? null : Duration(milliseconds: value);

/// From a vocabulary lesson's package. Null when it has none, or can't be read:
/// the page says so and offers to try again.
VocabContent? vocabularyFromJson(Map<String, Object?> lesson) {
  final json = lesson.readMap('vocabulary');
  if (json == null) return null;
  try {
    final words = [
      for (final word in json.readList('words') ?? const <Object?>[])
        _word(asJsonMap(word)),
    ];
    if (words.isEmpty) throw const FormatException('Vocabulary: no words');
    return VocabContent(words: words);
  } on FormatException catch (error, stackTrace) {
    AppLogger.error(error, stackTrace, 'Vocabulary unreadable');
    return null;
  }
}

VocabWord _word(Map<String, Object?> json) {
  final example = asJsonMap(json['example']);
  final tokens = [
    for (final token in example.readList('tokens') ?? const <Object?>[])
      VocabToken(
        id: _required(asJsonMap(token).readString('id')),
        text: _required(asJsonMap(token).readString('text')),
        start: _ms(asJsonMap(token).readInt('startMs')),
        end: _ms(asJsonMap(token).readInt('endMs')),
      ),
  ];
  if (tokens.isEmpty) {
    throw const FormatException('Vocabulary: an example is empty');
  }
  return VocabWord(
    id: _required(json.readString('id')),
    word: _required(json.readString('word')),
    kind: _kinds[json.readString('pos')],
    arabic: _required(json.readString('ar')),
    imageUrl: json.readString('image'),
    audioUrl: json.readString('audio'),
    example: VocabExample(
      tokens: tokens,
      arabic: _required(example.readString('ar')),
      audioUrl: example.readString('audio'),
      highlighted: {
        for (final id in example.readList('highlight') ?? const <Object?>[])
          if (id is String) id,
      },
    ),
  );
}

/// A saved card as it is sent: all of it, as the panel may change the original.
Map<String, Object?> vocabWordToJson(VocabWord word, {required bool saved}) => {
  'wordId': word.id,
  'saved': saved,
  if (saved) ...{
    'base': word.word,
    'kind': ?word.kind?.name,
    'ar': word.arabic,
    'sentence': {'en': word.example.english, 'ar': word.example.arabic},
  },
};
