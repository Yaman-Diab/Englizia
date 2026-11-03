import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/lesson_result_model.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

/// A unit's screen as `GET /api/v1/app/units/{unitId}` sends it. The raw
/// [json] is what the phone keeps for offline.
final class UnitPlanModel {
  const UnitPlanModel(this.json);

  final Map<String, Object?> json;

  /// A lesson that can't be read is left out, so the rest still show; a unit
  /// with none can't be shown.
  UnitPlan toEntity() {
    final id = json.readString('id');
    final lessons = [
      for (final item in json.readList('lessons') ?? const <Object?>[])
        ?_lesson(item),
    ];
    if (id == null || lessons.isEmpty) {
      throw const FormatException('Unit without an id or lessons');
    }
    final pages = json.readMap('bookPages');
    final from = pages?.readInt('from');
    final to = pages?.readInt('to');
    return UnitPlan(
      id: id,
      number: json.readInt('number') ?? 0,
      title: json.readString('title') ?? '',
      lessons: lessons,
      levelLabel: json.readString('levelLabel') ?? '',
      coverUrl: json.readString('cover'),
      kids: json.readBool('kidsMode') ?? false,
      ordered: json.readBool('ordered') ?? true,
      goals: [
        for (final goal in json.readList('goals') ?? const <Object?>[])
          if (goal is String && goal.isNotEmpty) goal,
      ],
      concepts: [
        for (final item in json.readList('concepts') ?? const <Object?>[])
          ?asJsonMap(item).readString('name'),
      ],
      bookPages: from != null && to != null ? (from: from, to: to) : null,
      titleAudioUrl: json.readString('titleAudio'),
      lockedBy: _link(json.readMap('lockedBy')),
      next: _link(json.readMap('next')),
    );
  }

  static UnitLesson? _lesson(Object? item) {
    if (item is! Map<String, Object?>) return null;
    final id = item.readString('id');
    final title = item.readString('title');
    if (id == null || title == null) return null;
    final resume = item.readMap('resume');
    final question = resume?.readInt('question');
    return UnitLesson(
      id: id,
      kind: lessonKindFrom(item.readString('kind')),
      title: title,
      minutes: item.readInt('minutes'),
      page: item.readInt('page'),
      done: item.readBool('done') ?? false,
      stars: (item.readInt('stars') ?? 0).clamp(0, 5),
      imageUrl: item.readString('image'),
      audioUrl: item.readString('audio'),
      scenarioId: item.readString('scenarioId'),
      resume: question == null
          ? null
          : LessonResume(
              question: question,
              share: (resume?.readDouble('share') ?? 0).clamp(0, 1),
            ),
    );
  }

  static UnitLink? _link(Map<String, Object?>? json) {
    final id = json?.readString('id');
    final number = json?.readInt('number');
    if (id == null || number == null) return null;
    return UnitLink(
      id: id,
      number: number,
      title: json?.readString('title') ?? '',
    );
  }
}
