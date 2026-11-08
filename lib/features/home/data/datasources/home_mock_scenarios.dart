import 'dart:convert';

import 'package:englizia/core/network/json_reader.dart';

/// The design's frames, played on the bundled home (mock mode only, from
/// the dev page). Deleted with the mock once the endpoint is confirmed.
enum HomeMockScenario {
  /// 01: unit 3, 3 of 6 done, 7 of 10 minutes, streak 7, review 12 + 3.
  general,

  /// 02: no lesson done yet, unit 1 current, its last lesson the level check.
  firstDay,

  /// 03: the current lesson left at question 3 of 6.
  partial,

  /// 04: today's goal reached.
  goalReached,

  /// 05: the evening, 5 minutes learned: the streak at risk.
  atRisk,

  /// 06: back after a while, with a review due.
  welcomeBack,

  /// 15·1: a freeze was used yesterday.
  freezeUsed,

  /// 15·2: the streak ended yesterday.
  streakBroken,

  /// 14·2: the level check is offered.
  levelCheck,

  /// 14·3: the placement test was put off.
  placementDeferred,

  /// 10: only the unit's review is left (M6 once it is done).
  lastLesson,

  /// 10 + 11: the level's last unit, only its review left (M6 then M7).
  lastUnit,

  /// 11: every unit done.
  levelComplete,

  /// 09ب: a unit of 8 lessons whose next lesson starts a new row.
  newRow,

  /// n4 / n8 / n10: islands of 4, 8 and 10 lessons.
  lessons4,
  lessons8,
  lessons10,

  /// 18: no connection; what the phone kept shows.
  offline,

  /// 19: no connection and nothing kept (the dev page clears it).
  offlineEmpty,

  /// 20: the first load works, every refresh after it fails.
  refreshFails,

  /// 21: a slow first load (the dev page clears what was kept).
  slow,

  /// 22: a v0.1 server: no week, streak or review.
  v01,
}

/// [json] (a home `data`) as [scenario]'s frame, on the day of [now]. The
/// assets hold each unit's lessons in `mockLessons`, the goals of locked
/// units in `mockGoals`, and more lessons for longer islands in
/// `mockExtraLessons`.
Map<String, Object?> applyScenario(
  Map<String, Object?> json,
  HomeMockScenario scenario,
  DateTime now,
) {
  final home = copyJson(json);
  final yesterday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
  switch (scenario) {
    case HomeMockScenario.general ||
        HomeMockScenario.offline ||
        HomeMockScenario.offlineEmpty ||
        HomeMockScenario.refreshFails ||
        HomeMockScenario.slow:
      break;
    case HomeMockScenario.firstDay:
      home.child('learner')['lessonsDone'] = 0;
      moveCurrentUnit(home, 0);
      _setToday(home, 0);
      _setStreak(home, 0);
      home.remove('review');
    case HomeMockScenario.partial:
      final lessons = _currentLessons(home);
      final index = _firstUndone(lessons);
      if (index != null) {
        lessons[index]['resume'] = {'question': 3, 'questions': 6, 'share': .5};
      }
    case HomeMockScenario.goalReached:
      _setToday(home, 12);
      _setStreak(home, 8);
    case HomeMockScenario.atRisk:
      _setToday(home, 5);
    case HomeMockScenario.welcomeBack:
      home.child('learner')['welcomeBack'] = true;
      _setToday(home, 0);
      _setStreak(home, 0);
    case HomeMockScenario.freezeUsed:
      home['events'] = [
        {
          'id': 'ev_frz_$yesterday',
          'kind': 'freezeUsed',
          'on': yesterday,
          'streak': 7,
          'freezesLeft': 1,
        },
      ];
      home.child('streak')['freezes'] = 1;
    case HomeMockScenario.streakBroken:
      home['events'] = [
        {
          'id': 'ev_brk_$yesterday',
          'kind': 'streakBroken',
          'on': yesterday,
          'streak': 7,
        },
      ];
      _setStreak(home, 0);
      _setToday(home, 0);
    case HomeMockScenario.levelCheck:
      home['cards'] = {
        ...home.child('cards'),
        'levelCheck': {'lessonId': 'les_mock'},
      };
    case HomeMockScenario.placementDeferred:
      home['cards'] = {
        ...home.child('cards'),
        'placement': {
          'estimatedMinutes': {'min': 12, 'max': 15},
        },
      };
    case HomeMockScenario.lastLesson:
      final lessons = _currentLessons(home);
      for (final (index, lesson) in lessons.indexed) {
        lesson['done'] = index < lessons.length - 1;
      }
    case HomeMockScenario.lastUnit:
      final units = home.list('units');
      final last = units.length - 1;
      final count = _mockLessons(home, units[last].readString('id')).length;
      moveCurrentUnit(home, last, done: count - 1);
    case HomeMockScenario.levelComplete:
      moveCurrentUnit(home, home.list('units').length);
      home.child('level')['completed'] = true;
    case HomeMockScenario.newRow:
      _setLessons(home, count: 8, done: 5);
    case HomeMockScenario.lessons4:
      _setLessons(home, count: 4, done: 2);
    case HomeMockScenario.lessons8:
      _setLessons(home, count: 8, done: 4);
    case HomeMockScenario.lessons10:
      _setLessons(home, count: 10, done: 8);
    case HomeMockScenario.v01:
      home
        ..remove('week')
        ..remove('streak')
        ..remove('review');
  }
  return home;
}

/// Makes unit [index] the current one with [done] of its lessons done: the
/// units before it done, those after it locked (ordered tracks) or open. An
/// [index] past the last unit finishes them all.
void moveCurrentUnit(Map<String, Object?> home, int index, {int done = 0}) {
  final ordered = home.child('enrollment').readBool('ordered') ?? true;
  final units = home.list('units');
  for (final (i, unit) in units.indexed) {
    if (i < index) {
      unit['status'] = 'done';
      unit
        ..remove('lessons')
        ..remove('lockedBy')
        ..remove('preview');
    } else if (i == index) {
      unit['status'] = 'current';
      unit['lessons'] = [
        for (final (k, lesson) in _mockLessons(
          home,
          unit.readString('id'),
        ).indexed)
          {...lesson, 'done': k < done},
      ];
      unit
        ..remove('lockedBy')
        ..remove('preview');
    } else if (ordered) {
      final before = units[i - 1];
      unit['status'] = 'locked';
      unit['lockedBy'] = {'id': before['id'], 'number': before['number']};
      unit['preview'] ??= _previewOf(home, unit.readString('id'));
      unit.remove('lessons');
    } else {
      unit['status'] = 'open';
      unit
        ..remove('lessons')
        ..remove('lockedBy')
        ..remove('preview');
    }
  }
}

/// A deep copy that can be changed.
Map<String, Object?> copyJson(Map<String, Object?> json) =>
    asJsonMap(jsonDecode(jsonEncode(json)));

extension on Map<String, Object?> {
  Map<String, Object?> child(String key) =>
      (this[key] ??= <String, Object?>{}) as Map<String, Object?>;

  List<Map<String, Object?>> list(String key) => [
    for (final item in readList(key) ?? const <Object?>[]) asJsonMap(item),
  ];
}

List<Map<String, Object?>> _currentLessons(Map<String, Object?> home) {
  for (final unit in home.list('units')) {
    if (unit['status'] == 'current') return unit.list('lessons');
  }
  return const [];
}

int? _firstUndone(List<Map<String, Object?>> lessons) {
  for (final (index, lesson) in lessons.indexed) {
    if (lesson['done'] != true) return index;
  }
  return null;
}

/// A unit's lessons as the mock lists them, all undone; the current unit's
/// when the mock has none for it.
List<Map<String, Object?>> _mockLessons(
  Map<String, Object?> home,
  String? unitId,
) {
  final lessons =
      home.readMap('mockLessons')?.readList(unitId ?? '') ??
      [for (final lesson in _currentLessons(home)) lesson];
  return [
    for (final item in lessons)
      {...asJsonMap(item), 'done': false}..remove('resume'),
  ];
}

Map<String, Object?> _previewOf(Map<String, Object?> home, String? unitId) => {
  'goal': home.readMap('mockGoals')?.readString(unitId ?? '') ?? '',
  'lessons': [
    for (final lesson in _mockLessons(home, unitId))
      {
        'kind': lesson['kind'],
        'title': lesson['title'],
        'minutes': lesson['minutes'],
      },
  ],
};

/// The current unit with [count] lessons, [done] of them done: its own
/// lessons and the mock's extra ones, its review last.
void _setLessons(
  Map<String, Object?> home, {
  required int count,
  required int done,
}) {
  for (final unit in home.list('units')) {
    if (unit['status'] != 'current') continue;
    final lessons = unit.list('lessons');
    final review = lessons.where((l) => l['kind'] == 'unitReview').toList();
    final pool = [
      ...lessons.where((l) => l['kind'] != 'unitReview'),
      for (final item in home.readList('mockExtraLessons') ?? const <Object?>[])
        asJsonMap(item),
    ];
    final picked = [...pool.take(count - review.length), ...review];
    unit['lessons'] = [
      for (final (k, lesson) in picked.indexed)
        {...lesson, 'done': k < done}..remove('resume'),
    ];
  }
}

void _setToday(Map<String, Object?> home, int minutes) {
  final week = home.readMap('week');
  final days = week?.list('days');
  final today = week?.readInt('today');
  if (days == null || today == null || today >= days.length) return;
  days[today]['minutes'] = minutes;
}

void _setStreak(Map<String, Object?> home, int current) {
  final streak = home.readMap('streak');
  if (streak == null) return;
  streak['current'] = current;
  if ((streak.readInt('longest') ?? 0) < current) streak['longest'] = current;
}
