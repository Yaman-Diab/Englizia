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

Duration? _ms(int? value) =>
    value == null ? null : Duration(milliseconds: value);

KidLine _line(Map<String, Object?>? json) => KidLine(
  text: _required(json?.readString('en')),
  audioUrl: json?.readString('audio'),
);

List<KidTimedWord> _timed(List<Object?>? json) => [
  for (final word in json ?? const <Object?>[])
    KidTimedWord(
      _required(asJsonMap(word).readString('text')),
      Duration(milliseconds: asJsonMap(word).readInt('startMs') ?? 0),
    ),
];

KidStoryPage _page(Map<String, Object?> json) => KidStoryPage(
  image: _required(json.readString('image')),
  audioUrl: json.readString('audio'),
  words: _timed(json.readList('words')),
  marked: [
    for (final word in json.readList('marked') ?? const <Object?>[])
      _word(asJsonMap(word)),
  ],
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
          videoLength: _ms(map.readInt('videoMs')),
          audioUrl: map.readString('audio'),
          words: [
            for (final word in map.readList('words') ?? const <Object?>[])
              _word(asJsonMap(word)),
          ],
        ),
        'question' => KidQuestionStep(id: id, instructionAudioUrl: instruction),
        'story' => KidStoryStep(
          id: id,
          instructionAudioUrl: instruction,
          pages: [
            for (final page in map.readList('pages') ?? const <Object?>[])
              _page(asJsonMap(page)),
          ],
        ),
        'song' => KidSongStep(
          id: id,
          instructionAudioUrl: instruction,
          videoUrl: map.readString('video'),
          videoLength: _ms(map.readInt('videoMs')),
          pictures: [
            for (final image in map.readList('pictures') ?? const <Object?>[])
              if (image is String) image,
          ],
          lines: [
            for (final line in map.readList('lines') ?? const <Object?>[])
              _timed(asJsonMap(line).readList('words')),
          ],
        ),
        'dialogue' => KidDialogueStep(
          id: id,
          instructionAudioUrl: instruction,
          echoInstructionAudioUrl: map.readString('echoInstructionAudio'),
          character: _word(map.readMap('character') ?? const {}),
          opening: _line(map.readMap('opening')),
          closing: _line(map.readMap('closing')),
          replies: [
            for (final reply in map.readList('replies') ?? const <Object?>[])
              KidReply(
                word: _word(asJsonMap(reply).readMap('word') ?? const {}),
                answer: _line(asJsonMap(reply).readMap('answer')),
                echo: _line(asJsonMap(reply).readMap('echo')),
              ),
          ],
        ),
        'speak' => KidSpeakStep(
          id: id,
          instructionAudioUrl: instruction,
          word: _word(map.readMap('word') ?? const {}),
        ),
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
