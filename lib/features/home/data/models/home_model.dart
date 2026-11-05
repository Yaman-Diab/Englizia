import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/lessons/data/models/lesson_result_model.dart';
import 'package:englizia/features/lessons/data/models/unit_plan_model.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/me/data/models/profile_model.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/home.md).

/// Home as `GET /api/v1/app/home` sends it. The raw [json] is what the phone
/// keeps. The enrollments, the streak and the week read as «أنا» reads them,
/// and a lesson as the unit's screen does.
final class HomeModel {
  const HomeModel(this.json);

  final Map<String, Object?> json;

  /// A part that can't be read is left out; without the learner's name, the
  /// enrollment, the level or a unit, nothing can be drawn.
  HomeSnapshot toEntity() {
    final learner = json.readMap('learner');
    final enrollment = json.readMap('enrollment');
    final level = json.readMap('level');
    final name = learner?.readString('name');
    final enrollmentId = enrollment?.readString('id');
    final levelId = level?.readString('id');
    final units = [
      for (final (index, item)
          in (json.readList('units') ?? const <Object?>[]).indexed)
        ?_unit(item, index),
    ];
    if (learner == null ||
        enrollment == null ||
        level == null ||
        name == null ||
        enrollmentId == null ||
        levelId == null ||
        units.isEmpty) {
      throw const FormatException(
        'Home without a learner, an enrollment, a level or units',
      );
    }
    final streak = json.readMap('streak');
    return HomeSnapshot(
      learner: HomeLearner(
        name: name,
        lessonsDone: learner.readInt('lessonsDone') ?? 0,
        welcomeBack: learner.readBool('welcomeBack') ?? false,
        emailVerified: learner.readBool('emailVerified') ?? false,
        signIn: switch (learner.readString('signIn')) {
          'guest' => null,
          'google' => SignInMethod.google,
          'apple' => SignInMethod.apple,
          _ => SignInMethod.email,
        },
        stars: learner.readInt('stars'),
        // ASSUMPTION(api): `learner.greetingAudio` — docs/api/home.md.
        greetingAudioUrl: learner.readString('greetingAudio'),
      ),
      enrollment: HomeEnrollment(
        id: enrollmentId,
        trackId: enrollment.readString('trackId') ?? '',
        title: enrollment.readString('title') ?? '',
        audience: _audiences[enrollment.readString('audience')],
        kidsMode: enrollment.readBool('kidsMode') ?? false,
        ordered: enrollment.readBool('ordered') ?? true,
        levelLabel: switch (enrollment.readString('levelLabel')) {
          'grade' => HomeLevelLabel.grade,
          'book' => HomeLevelLabel.book,
          _ => HomeLevelLabel.level,
        },
      ),
      enrollments: [
        for (final item in json.readList('enrollments') ?? const <Object?>[])
          ?ProfileModel.trackOf(item),
      ],
      level: HomeLevel(
        id: levelId,
        label: level.readString('label') ?? '',
        name: level.readString('name') ?? '',
        cefr: _cefr(level.readString('cefr')),
        completed: level.readBool('completed') ?? false,
        next: _levelRef(level.readMap('next')),
      ),
      units: units,
      week: ProfileModel.weekOf(json.readMap('week')),
      streak: ProfileModel.streakOf(streak),
      // ASSUMPTION(api): `streak.freezesPerWeek` — docs/api/home.md.
      freezesPerWeek: (streak?.readInt('freezesPerWeek') ?? 1).clamp(0, 3),
      review: _review(json.readMap('review')),
      cards: _cards(json.readMap('cards')),
      events: [
        for (final item in json.readList('events') ?? const <Object?>[])
          ?_event(item),
      ],
    );
  }

  static const _audiences = {
    'self': TrackAudience.self,
    'child': TrackAudience.child,
    'schoolStudent': TrackAudience.schoolStudent,
  };

  static const _statuses = {
    'done': UnitLessonStatus.done,
    'current': UnitLessonStatus.current,
    'open': UnitLessonStatus.open,
    'locked': UnitLessonStatus.locked,
  };

  static HomeCefr? _cefr(String? name) => switch (name) {
    'preA1' => HomeCefr.preA1,
    'a1' => HomeCefr.a1,
    'a2' => HomeCefr.a2,
    'b1' => HomeCefr.b1,
    'b2' => HomeCefr.b2,
    'c1' => HomeCefr.c1,
    _ => null,
  };

  static HomeLevelRef? _levelRef(Map<String, Object?>? json) {
    final id = json?.readString('id');
    final label = json?.readString('label');
    if (json == null || id == null || label == null) return null;
    return HomeLevelRef(
      id: id,
      label: label,
      name: json.readString('name') ?? '',
      cefr: _cefr(json.readString('cefr')),
    );
  }

  /// An unknown status is the least it allows: locked. A current unit whose
  /// lessons can't be read opens like Emar's, from its own screen.
  static HomeUnit? _unit(Object? item, int index) {
    if (item is! Map<String, Object?>) return null;
    final id = item.readString('id');
    // ASSUMPTION(api): `title {ar, en}`; a plain string is the Arabic title.
    final titles = item.readMap('title');
    final ar = titles?.readString('ar') ?? item.readString('title');
    final en = titles?.readString('en');
    final title = ar ?? en;
    if (id == null || title == null) return null;
    var status =
        _statuses[item.readString('status')] ?? UnitLessonStatus.locked;
    final lessons = status == UnitLessonStatus.current
        ? [
            for (final lesson in item.readList('lessons') ?? const <Object?>[])
              ?_lesson(lesson),
          ]
        : const <HomeLesson>[];
    if (status == UnitLessonStatus.current && lessons.isEmpty) {
      status = UnitLessonStatus.open;
    }
    final pages = item.readMap('bookPages');
    final from = pages?.readInt('from');
    final to = pages?.readInt('to');
    final lockedBy = item.readMap('lockedBy');
    final lockedById = lockedBy?.readString('id');
    final lockedByNumber = lockedBy?.readInt('number');
    return HomeUnit(
      id: id,
      number: item.readInt('number') ?? index + 1,
      title: title,
      titleEn: ar == null ? null : en,
      coverUrl: item.readString('cover'),
      status: status,
      bookPages: from != null && to != null ? (from: from, to: to) : null,
      // ASSUMPTION(api): kids' `stars` per unit — docs/api/home.md.
      stars: item.readInt('stars')?.clamp(0, 5),
      titleAudioUrl: item.readString('titleAudio'),
      lockedBy: lockedById != null && lockedByNumber != null
          ? UnitLink(id: lockedById, number: lockedByNumber)
          : null,
      preview: _preview(item.readMap('preview')),
      lessons: lessons,
    );
  }

  static HomeLesson? _lesson(Object? item) {
    final base = UnitPlanModel.lessonOf(item);
    if (base == null || item is! Map<String, Object?>) return null;
    return HomeLesson(
      base: base,
      // ASSUMPTION(api): `ai`, `levelCheck` and `resume.questions` —
      // docs/api/home.md.
      ai: item.readBool('ai') ?? false,
      levelCheck: item.readBool('levelCheck') ?? false,
      questions: item.readMap('resume')?.readInt('questions'),
    );
  }

  // ASSUMPTION(api): a locked unit's `preview` — docs/api/home.md.
  static HomeUnitPreview? _preview(Map<String, Object?>? json) {
    if (json == null) return null;
    return HomeUnitPreview(
      goal: json.readString('goal') ?? '',
      lessons: [
        for (final item in json.readList('lessons') ?? const <Object?>[])
          ?_previewLesson(item),
      ],
    );
  }

  static HomePreviewLesson? _previewLesson(Object? item) {
    if (item is! Map<String, Object?>) return null;
    final title = item.readString('title');
    if (title == null) return null;
    return HomePreviewLesson(
      kind: lessonKindFrom(item.readString('kind')),
      title: title,
      minutes: item.readInt('minutes') ?? 0,
    );
  }

  // ASSUMPTION(api): `review {wordsDue, conceptsDue, minutes}` —
  // docs/api/home.md.
  static HomeReview? _review(Map<String, Object?>? json) {
    final words = json?.readInt('wordsDue');
    if (json == null || words == null) return null;
    return HomeReview(
      wordsDue: words,
      conceptsDue: json.readInt('conceptsDue'),
      minutes: json.readInt('minutes') ?? 0,
    );
  }

  // ASSUMPTION(api): `cards.levelCheck` and `cards.placement` —
  // docs/api/home.md.
  static HomeCards _cards(Map<String, Object?>? json) {
    final minutes = json?.readMap('placement')?.readMap('estimatedMinutes');
    final min = minutes?.readInt('min');
    final max = minutes?.readInt('max');
    return HomeCards(
      levelCheckLessonId: json?.readMap('levelCheck')?.readString('lessonId'),
      placementMinutes: min != null && max != null
          ? (min: min, max: max)
          : null,
    );
  }

  /// An unknown kind is skipped: it can't be told.
  // ASSUMPTION(api): `events[]` — docs/api/home.md.
  static HomeEvent? _event(Object? item) {
    if (item is! Map<String, Object?>) return null;
    final id = item.readString('id');
    final on = item.readDateTime('on');
    final kind = switch (item.readString('kind')) {
      'freezeUsed' => HomeEventKind.freezeUsed,
      'streakBroken' => HomeEventKind.streakBroken,
      _ => null,
    };
    if (id == null || on == null || kind == null) return null;
    return HomeEvent(
      id: id,
      kind: kind,
      on: on,
      streak: item.readInt('streak') ?? 0,
      freezesLeft: item.readInt('freezesLeft'),
    );
  }
}
