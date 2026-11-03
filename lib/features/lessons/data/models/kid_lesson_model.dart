import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/domain/entities/kid_lesson.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

String _required(String? value) =>
    value ?? (throw const FormatException('Kids lesson: a field is missing'));

KidWord _word(Map<String, Object?> json) => KidWord(
  word: _required(json.readString('word')),
  image: _required(json.readString('image')),
  arabic: json.readString('ar') ?? '',
  audioUrl: json.readString('audio'),
);

/// From a kids' lesson's package. Null when it has none, or can't be read. A
/// screen that can't be read is left out, and the rest show.
KidLesson? kidLessonFromJson(Map<String, Object?> lesson) {
  final json = lesson.readMap('kids');
  if (json == null) return null;
  final steps = <KidStep>[];
  for (final step in json.readList('steps') ?? const <Object?>[]) {
    try {
      final map = asJsonMap(step);
      final id = _required(map.readString('id'));
      final instruction = map.readString('instructionAudio');
      steps.add(switch (map.readString('kind')) {
        'word' => KidWordStep(
          id: id,
          instructionAudioUrl: instruction,
          word: _word(map.readMap('word') ?? const {}),
        ),
        'letter' => KidLetterStep(
          id: id,
          instructionAudioUrl: instruction,
          letter: _required(map.readString('letter')),
          videoUrl: map.readString('video'),
          videoLength: switch (map.readInt('videoMs')) {
            final ms? => Duration(milliseconds: ms),
            null => null,
          },
          audioUrl: map.readString('audio'),
          words: [
            for (final word in map.readList('words') ?? const <Object?>[])
              _word(asJsonMap(word)),
          ],
        ),
        'question' => KidQuestionStep(id: id, instructionAudioUrl: instruction),
        _ => throw const FormatException('Kids lesson: a step of no kind'),
      });
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Kids lesson: a step skipped');
    }
  }
  if (steps.isEmpty) return null;
  final voice = json.readMap('voice') ?? const {};
  return KidLesson(
    steps: steps,
    words: [
      for (final word in json.readList('words') ?? const <Object?>[])
        _word(asJsonMap(word)),
    ],
    voice: KidVoice(
      praise: voice.readString('praise'),
      tryAgain: voice.readString('tryAgain'),
      leave: voice.readString('leave'),
      done: voice.readString('done'),
    ),
  );
}
