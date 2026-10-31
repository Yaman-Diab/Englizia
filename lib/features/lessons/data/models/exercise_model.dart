import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/stable_order.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

/// The lesson as it came, so it can be kept on the phone as it is.
final class LessonModel {
  const LessonModel(this.json);

  final Map<String, Object?> json;

  /// [seed] is this learner's, for the order of the options.
  Lesson toEntity(String seed) {
    final id = json.readString('id');
    final version = json.readInt('version');
    if (id == null || version == null) {
      throw const FormatException('Lesson: no id or version');
    }
    final exercises = <Exercise>[];
    var broken = 0;
    for (final question in json.readList('exercises') ?? const <Object?>[]) {
      try {
        if (_exercise(asJsonMap(question), seed) case final exercise?) {
          exercises.add(exercise);
        }
      } on FormatException catch (error, stackTrace) {
        // One bad question must not leave the learner stuck on the lesson.
        broken++;
        AppLogger.error(error, stackTrace, 'Lesson $id: a question skipped');
      }
    }
    if (exercises.isEmpty && broken > 0) {
      throw const FormatException('Lesson: no question could be read');
    }
    return Lesson(id: id, version: version, exercises: exercises);
  }
}

/// Null for what isn't shown here: a template this version doesn't know, which
/// the server should have hidden (S §7.3), and review-only questions.
Exercise? _exercise(Map<String, Object?> json, String seed) {
  if (json.readBool('reviewOnly') ?? false) return null;
  final template = json.readString('template');
  final id = json.readString('id');
  final instruction = json.readString('instructionAr');
  final prompt = json.readMap('prompt') ?? const <String, Object?>{};
  final answer = json.readString('answer');
  final hint = json.readMap('hint')?.readString('ar');
  final bookReference = _bookReference(json.readMap('bookRef'));
  if (template == null) throw const FormatException('Exercise: no template');
  if (!const {
    'multipleChoice',
    'imageChoice',
    'listenChoose',
  }.contains(template)) {
    return null;
  }
  if (id == null || instruction == null) {
    throw const FormatException('Exercise: no id or instruction');
  }
  final options = [
    for (final option in json.readList('options') ?? const <Object?>[])
      _option(asJsonMap(option)),
  ];
  if (options.isEmpty || !options.any((o) => o.id == answer)) {
    throw const FormatException('Exercise: no options, or no right one');
  }
  final shown = stableOrder(options, '$seed:$id');
  return switch (template) {
    'multipleChoice' => _multipleChoice(
      id: id,
      instruction: instruction,
      options: shown,
      answer: answer!,
      hint: hint,
      bookReference: bookReference,
      sentence: prompt.readString('en'),
    ),
    'imageChoice' => ImageChoiceExercise(
      id: id,
      instruction: instruction,
      options: shown,
      answerId: answer!,
      word: _required(prompt.readString('en')),
      audioUrl: prompt.readString('audio'),
      hint: hint,
      bookReference: bookReference,
    ),
    _ => ListenChooseExercise(
      id: id,
      instruction: instruction,
      options: shown,
      answerId: answer!,
      audioUrl: _required(prompt.readString('audio')),
      hint: hint,
      bookReference: bookReference,
    ),
  };
}

MultipleChoiceExercise _multipleChoice({
  required String id,
  required String instruction,
  required List<ExerciseOption> options,
  required String answer,
  required String? hint,
  required BookReference? bookReference,
  required String? sentence,
}) {
  final parts = _required(sentence).split(_blank);
  if (parts.length != 2) {
    throw const FormatException('Exercise: not one blank in the sentence');
  }
  return MultipleChoiceExercise(
    id: id,
    instruction: instruction,
    options: options,
    answerId: answer,
    before: parts.first.trim(),
    after: parts.last.trim(),
    hint: hint,
    bookReference: bookReference,
  );
}

const _blank = '___';

String _required(String? value) =>
    value ?? (throw const FormatException('Exercise: a field is missing'));

BookReference? _bookReference(Map<String, Object?>? json) {
  final page = json?.readInt('page');
  final exercise = json?.readInt('exercise');
  return page == null || exercise == null
      ? null
      : BookReference(page: page, exercise: exercise);
}

ExerciseOption _option(Map<String, Object?> json) {
  final id = json.readString('id');
  if (id == null) throw const FormatException('Exercise: an option with no id');
  return ExerciseOption(
    id: id,
    text: json.readString('text') ?? '',
    image: json.readString('image') ?? '',
    alt: json.readString('alt') ?? '',
  );
}

/// An attempt as it is kept and sent, with its stable [attemptId].
Map<String, Object?> attemptToJson(ExerciseAttempt attempt, String attemptId) =>
    {
      'attemptId': attemptId,
      'lessonVersion': attempt.lessonVersion,
      'questionId': attempt.questionId,
      'answer': switch (attempt.draft) {
        ChoiceDraft(:final optionId) => {'optionId': optionId},
      },
      'hinted': attempt.hinted,
    };

/// What is kept on the phone: each lesson's progress, and the answers not on
/// the server yet.
final class LessonStoreModel {
  LessonStoreModel({
    Map<String, Map<String, Object?>>? lessons,
    List<Map<String, Object?>>? unsent,
  }) : lessons = lessons ?? {},
       unsent = unsent ?? [];

  factory LessonStoreModel.fromJson(Map<String, Object?> json) =>
      LessonStoreModel(
        lessons: {
          for (final entry
              in (json.readMap('lessons') ?? const <String, Object?>{}).entries)
            entry.key: asJsonMap(entry.value),
        },
        unsent: [
          for (final answer in json.readList('unsent') ?? const <Object?>[])
            asJsonMap(answer),
        ],
      );

  final Map<String, Map<String, Object?>> lessons;

  /// `{lessonId, request}`, in the order to send them.
  final List<Map<String, Object?>> unsent;

  ExerciseProgress progress(String lessonId) {
    final lesson = lessons[lessonId];
    if (lesson == null) return const ExerciseProgress();
    return ExerciseProgress(
      done: _ids(lesson.readList('done')),
      hinted: _ids(lesson.readList('hinted')),
    );
  }

  static Set<String> _ids(List<Object?>? ids) => {
    for (final id in ids ?? const <Object?>[]) ?id as String?,
  };

  void setProgress(String lessonId, ExerciseProgress progress) =>
      lessons[lessonId] = {
        'done': progress.done.toList(),
        'hinted': progress.hinted.toList(),
      };

  Map<String, Object?> toJson() => {'lessons': lessons, 'unsent': unsent};
}
