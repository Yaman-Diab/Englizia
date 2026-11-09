import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/lessons.md).

const _kinds = {
  'vocabulary': LessonKind.vocabulary,
  'interactiveVideo': LessonKind.interactiveVideo,
  'grammarVideo': LessonKind.grammarVideo,
  'interactiveText': LessonKind.interactiveText,
  'conversation': LessonKind.conversation,
  'unitReview': LessonKind.unitReview,
};

const _nextKinds = {
  'lesson': NextKind.lesson,
  'unitReview': NextKind.unitReview,
  'unit': NextKind.unit,
};

LessonKind _kind(String? name) => _kinds[name] ?? LessonKind.other;

/// A lesson's `kind` as the contract spells it.
LessonKind lessonKindFrom(String? name) => _kind(name);

/// A part that can't be read is left out: it must not cost the learner a lesson.
UnitProgress? _unit(Map<String, Object?>? json) {
  final number = json?.readInt('number');
  final title = json?.readString('title');
  final lessons = json?.readList('lessons');
  if (number == null || title == null || lessons == null || lessons.isEmpty) {
    return null;
  }
  final steps = <UnitStep>[];
  for (final lesson in lessons) {
    final map = asJsonMap(lesson);
    final id = map.readString('id');
    if (id == null) return null;
    steps.add(
      UnitStep(
        lessonId: id,
        kind: _kind(map.readString('kind')),
        done: map.readBool('done') ?? false,
      ),
    );
  }
  return UnitProgress(number: number, title: title, steps: steps);
}

NextStep? _next(Map<String, Object?>? json) {
  final kind = _nextKinds[json?.readString('kind')];
  if (json == null || kind == null) return null;
  return NextStep(
    kind: kind,
    title: json.readString('title') ?? '',
    lessonId: json.readString('lessonId'),
    lessonKind: _kind(json.readString('lessonKind')),
    // ASSUMPTION(api): `next.scenarioId`, as a unit's lessons have it
    // (docs/api/lessons.md).
    scenarioId: json.readString('scenarioId'),
    unitNumber: json.readInt('unitNumber'),
  );
}

/// From the top of a lesson's package.
LessonOutline lessonOutlineFromJson(Map<String, Object?> json) => LessonOutline(
  title: json.readString('title'),
  replay: json.readBool('alreadyCompleted') ?? false,
  earnsXp: json.readInt('xpPerAnswer') != null,
  unit: _unit(json.readMap('unit')),
  next: _next(json.readMap('next')),
);

/// What the server answers when a lesson is completed.
LessonResult lessonResultFromJson(Map<String, Object?> json) {
  final firstTry = json.readMap('firstTry');
  final goal = json.readMap('goal');
  final goalBefore = goal?.readInt('before');
  final goalNow = goal?.readInt('now');
  final goalTarget = goal?.readInt('target');
  final streak = json.readMap('streak');
  final streakBefore = streak?.readInt('before');
  final streakNow = streak?.readInt('now');
  return LessonResult(
    xp: json.readInt('xp'),
    rightFirstTime: firstTry?.readInt('right'),
    counted: firstTry?.readInt('total'),
    seconds: json.readInt('seconds'),
    pending: json.readInt('pendingReviews'),
    wordsSaved: json.readInt('wordsSaved') ?? 0,
    concepts: [
      for (final concept in json.readList('concepts') ?? const <Object?>[])
        if (concept is String) concept,
    ],
    goal: goalBefore == null || goalNow == null || goalTarget == null
        ? null
        : DailyGoal(before: goalBefore, now: goalNow, target: goalTarget),
    streak: streakBefore == null || streakNow == null
        ? null
        : StreakDays(before: streakBefore, now: streakNow),
    unit: _unit(json.readMap('unit')),
    next: _next(json.readMap('next')),
    replay: json.readBool('replay'),
  );
}

/// A completion as it is kept and sent, with its stable [completionId].
Map<String, Object?> completionToJson(
  LessonSummary summary,
  String completionId,
) => {
  'completionId': completionId,
  'lessonVersion': summary.lessonVersion,
  'seconds': summary.seconds,
};
