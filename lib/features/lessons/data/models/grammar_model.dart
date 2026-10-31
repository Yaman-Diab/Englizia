import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/teacher_question.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

const _qualities = {
  'auto': VideoQuality.auto,
  'low': VideoQuality.low,
  'medium': VideoQuality.medium,
  'high': VideoQuality.high,
};

String _required(String? value) =>
    value ?? (throw const FormatException('Grammar: a field is missing'));

int _requiredInt(int? value) =>
    value ?? (throw const FormatException('Grammar: a number is missing'));

/// From a grammar lesson's package. Null when it has no such content, or when it
/// can't be read: the page says so and offers to try again.
GrammarContent? grammarFromJson(Map<String, Object?> lesson) {
  final json = lesson.readMap('content');
  if (json == null) return null;
  try {
    final video = json.readMap('video');
    final teacher = json.readMap('teacher');
    return GrammarContent(
      summary: _summary(asJsonMap(json['summary'])),
      requiredPercent: _requiredInt(json.readInt('requiredWatchPercent')),
      video: video == null ? null : _video(video),
      teacherName: teacher?.readString('name'),
      teacherAvatar: teacher?.readString('avatar'),
      bookPage: lesson.readMap('bookRef')?.readInt('page'),
      exercisesOpen: json.readBool('exercisesOpen') ?? false,
      questionsEnabled: json.readBool('questionsEnabled') ?? false,
      savedWatch: switch (json.readMap('watch')) {
        final watch? => watchFromJson(watch),
        null => null,
      },
    );
  } on FormatException catch (error, stackTrace) {
    AppLogger.error(error, stackTrace, 'Grammar content unreadable');
    return null;
  }
}

GrammarVideo _video(Map<String, Object?> json) {
  final sources = [
    for (final source in json.readList('sources') ?? const <Object?>[])
      if (_qualities[asJsonMap(source).readString('quality')]
          case final quality?)
        VideoSource(
          quality: quality,
          url: _required(asJsonMap(source).readString('url')),
          sizeMb: asJsonMap(source).readInt('sizeMb'),
        ),
  ];
  if (sources.isEmpty) throw const FormatException('Grammar: no video source');
  return GrammarVideo(
    id: _required(json.readString('id')),
    duration: Duration(seconds: _requiredInt(json.readInt('durationSeconds'))),
    coverUrl: json.readString('cover'),
    sources: sources,
    captions: [
      for (final caption in json.readList('captions') ?? const <Object?>[])
        VideoCaption(
          from: Duration(
            milliseconds: _requiredInt(asJsonMap(caption).readInt('fromMs')),
          ),
          to: Duration(
            milliseconds: _requiredInt(asJsonMap(caption).readInt('toMs')),
          ),
          text: _required(asJsonMap(caption).readString('ar')),
        ),
    ],
  );
}

List<RulePart> _parts(List<Object?>? parts) => [
  for (final part in parts ?? const <Object?>[])
    RulePart(
      _required(asJsonMap(part).readString('text')),
      strong: asJsonMap(part).readBool('strong') ?? false,
      marked: asJsonMap(part).readBool('marked') ?? false,
    ),
];

RuleSummary _summary(Map<String, Object?> json) => RuleSummary(
  text: _required(json.readString('ar')),
  rows: [
    for (final row in json.readList('table') ?? const <Object?>[])
      RuleRow(
        left: _required(asJsonMap(row).readString('left')),
        right: _parts(asJsonMap(row).readList('right')),
      ),
  ],
  examples: [
    for (final example in json.readList('examples') ?? const <Object?>[])
      RuleExample(
        parts: _parts(asJsonMap(example).readList('en')),
        arabic: _required(asJsonMap(example).readString('ar')),
        audioUrl: asJsonMap(example).readString('audio'),
      ),
  ],
);

WatchState watchFromJson(Map<String, Object?> json) => WatchState(
  videoId: _required(json.readString('videoId')),
  positionSeconds: json.readInt('positionSeconds') ?? 0,
  ranges: [
    for (final range in json.readList('watched') ?? const <Object?>[])
      if (range is List && range.length == 2)
        (range[0]! as int, range[1]! as int),
  ],
);

/// As it is kept on the phone and sent, with the lesson's version.
Map<String, Object?> watchToJson(WatchState watch, {int? lessonVersion}) => {
  'videoId': watch.videoId,
  'lessonVersion': ?lessonVersion,
  'positionSeconds': watch.positionSeconds,
  'watched': [
    for (final (from, to) in watch.ranges) [from, to],
  ],
};

VideoQuality videoQualityFromName(String? name) =>
    _qualities[name] ?? VideoQuality.auto;

List<TeacherQuestion> questionsFromJson(Object? json) => [
  for (final question in json is List ? json : const <Object?>[])
    questionFromJson(asJsonMap(question)),
];

TeacherQuestion questionFromJson(Map<String, Object?> json) {
  final reply = json.readMap('reply');
  final seconds = json.readInt('videoSeconds');
  return TeacherQuestion(
    id: _required(json.readString('questionId')),
    text: _required(json.readString('text')),
    askedAt: DateTime.parse(_required(json.readString('askedAt'))),
    videoPosition: seconds == null ? null : Duration(seconds: seconds),
    reply: reply == null
        ? null
        : TeacherReply(
            name: _required(reply.readString('name')),
            role: reply.readString('role') == 'admin'
                ? ReplierRole.admin
                : ReplierRole.teacher,
            text: _required(reply.readString('text')),
          ),
  );
}

Map<String, Object?> questionToJson(TeacherQuestion question) => {
  'questionId': question.id,
  'text': question.text,
  'videoSeconds': ?question.videoPosition?.inSeconds,
};
