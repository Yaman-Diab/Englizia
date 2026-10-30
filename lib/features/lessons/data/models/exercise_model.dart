import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

/// The questions of a lesson. One of a kind this version doesn't know is left
/// out, as the server should have hidden it (S §7.3).
List<Exercise> exercisesFromJson(Map<String, Object?> json) => [
  for (final question in json.readList('questions') ?? const <Object?>[])
    ?_exercise(asJsonMap(question)),
];

Exercise? _exercise(Map<String, Object?> json) {
  final kind = ExerciseKind.values.asNameMap()[json.readString('type')];
  if (kind == null) return null;
  final id = json.readString('id');
  final instruction = json.readText('instruction');
  final options = json.readList('options');
  if (id == null || instruction == null || options == null || options.isEmpty) {
    throw const FormatException('Exercise: an incomplete question');
  }
  final hint = json.readMap('hint');
  final hintText = hint?.readText('text');
  return Exercise(
    id: id,
    kind: kind,
    instruction: instruction,
    options: [for (final option in options) _option(asJsonMap(option))],
    before: json.readString('before') ?? '',
    after: json.readString('after') ?? '',
    word: json.readString('word') ?? '',
    audioUrl: json.readString('audioUrl') ?? '',
    hint: hintText == null
        ? null
        : ExerciseHint(text: hintText, term: hint?.readString('term') ?? ''),
    bookReference: json.readText('bookReference'),
  );
}

ExerciseOption _option(Map<String, Object?> json) {
  final id = json.readString('id');
  if (id == null) throw const FormatException('Exercise: an option with no id');
  return ExerciseOption(
    id: id,
    correct: json.readBool('correct') ?? false,
    text: json.readString('text') ?? '',
    imageUrl: json.readString('imageUrl') ?? '',
    imageAlt: json.readText('imageAlt'),
  );
}

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
          for (final entry in asJsonMap(json['lessons']).entries)
            entry.key: asJsonMap(entry.value),
        },
        unsent: [
          for (final answer in json.readList('unsent') ?? const <Object?>[])
            asJsonMap(answer),
        ],
      );

  final Map<String, Map<String, Object?>> lessons;

  /// `{lessonId, attemptId, questionId, optionId, hinted}`.
  final List<Map<String, Object?>> unsent;

  ExerciseProgress progress(String lessonId) {
    final lesson = lessons[lessonId];
    if (lesson == null) return const ExerciseProgress();
    return ExerciseProgress(
      position: lesson.readInt('position') ?? 0,
      hinted: {
        for (final id in lesson.readList('hinted') ?? const <Object?>[])
          id! as String,
      },
    );
  }

  void setProgress(String lessonId, ExerciseProgress progress) =>
      lessons[lessonId] = {
        'position': progress.position,
        'hinted': progress.hinted.toList(),
      };

  Map<String, Object?> toJson() => {'lessons': lessons, 'unsent': unsent};
}
