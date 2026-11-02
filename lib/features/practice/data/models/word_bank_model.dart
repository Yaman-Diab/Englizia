import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/practice.md).

const _kinds = {
  'noun': WordKind.noun,
  'verb': WordKind.verb,
  'adjective': WordKind.adjective,
  'adverb': WordKind.adverb,
  'phrase': WordKind.phrase,
  'phrasalVerb': WordKind.phrasalVerb,
  'idiom': WordKind.idiom,
  'word': WordKind.word,
};

String _required(String? value) =>
    value ?? (throw const FormatException('Word bank: a field is missing'));

/// `GET /api/v1/app/word-bank`, and the copy kept on the phone, which is the same.
final class WordBankModel {
  const WordBankModel(this.json);

  final Map<String, Object?> json;

  /// A word that can't be read is left out, so one doesn't empty the bank.
  WordBank toEntity() => WordBank(
    words: [
      for (final word in json.readList('words') ?? const <Object?>[])
        ?_word(asJsonMap(word)),
    ],
    sessionSize: json.readInt('sessionSize') ?? 12,
    conceptsDue: json.readInt('conceptsDue'),
    savedSentences: json.readInt('savedSentences') ?? 0,
  );

  static BankWord? _word(Map<String, Object?> json) {
    try {
      final sentence = asJsonMap(json['sentence']);
      final source = json.readMap('source');
      final video = json.readMap('video');
      final box = json.readInt('box') ?? 1;
      return BankWord(
        id: _required(json.readString('id')),
        word: _required(json.readString('base')),
        kind: _kinds[json.readString('kind')],
        arabic: _required(json.readString('ar')),
        sentence: _required(sentence.readString('en')),
        sentenceArabic: _required(sentence.readString('ar')),
        highlighted: {
          for (final place in sentence.readList('highlight') ?? const [])
            if (place is int) place,
        },
        sentenceAudioUrl: sentence.readString('audio'),
        imageUrl: json.readString('image'),
        audioUrl: json.readString('audio'),
        lessonTitle: source?.readString('title'),
        moment: video == null
            ? null
            : WordMoment(
                videoId: _required(video.readString('videoId')),
                start: Duration(milliseconds: video.readInt('startMs') ?? 0),
              ),
        box: box.clamp(1, 5),
        dueAt: DateTime.parse(_required(json.readString('dueAt'))),
      );
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'A bank word skipped');
      return null;
    }
  }

  /// To keep the bank on the phone.
  static Map<String, Object?> fromEntity(WordBank bank) => {
    'sessionSize': bank.sessionSize,
    'conceptsDue': ?bank.conceptsDue,
    'savedSentences': bank.savedSentences,
    'words': [
      for (final word in bank.words)
        {
          'id': word.id,
          'base': word.word,
          'kind': ?word.kind?.name,
          'ar': word.arabic,
          'sentence': {
            'en': word.sentence,
            'ar': word.sentenceArabic,
            'highlight': word.highlighted.toList(),
            'audio': ?word.sentenceAudioUrl,
          },
          'image': ?word.imageUrl,
          'audio': ?word.audioUrl,
          if (word.lessonTitle case final title?) 'source': {'title': title},
          if (word.moment case final moment?)
            'video': {
              'videoId': moment.videoId,
              'startMs': moment.start.inMilliseconds,
            },
          'box': word.box,
          'dueAt': word.dueAt.toIso8601String(),
        },
    ],
  };
}

/// One answer as it is sent: its id makes sending it twice harmless.
Map<String, Object?> reviewToJson({
  required String reviewId,
  required String wordId,
  required bool known,
  required DateTime at,
}) => {
  'reviewId': reviewId,
  'wordId': wordId,
  'known': known,
  'reviewedAt': at.toUtc().toIso8601String(),
};
