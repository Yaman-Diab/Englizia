import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/server_unit.dart';

/// Home put together from what the server has (docs/api/home.md): the account
/// (`GET /app/me`), the joined tracks (`GET /app/enrollments`) and the active
/// track's map (`GET /app/enrollments/{trackId}/map`), in the shape
/// `HomeModel` reads. What the server doesn't say yet is left out, and home
/// draws without it: the week and the streak, the review, the one-time
/// notices, the level after this one.

const _cefr = {
  'pre_a1': 'preA1',
  'a1': 'a1',
  'a2': 'a2',
  'b1': 'b1',
  'b2': 'b2',
  'c1': 'c1',
};

/// Whose track it is: the track's own `onboardingAudience`, else what the
/// enrollment carries.
String _audience(Map<String, Object?> enrollment) {
  final track = enrollment.readMap('track');
  if (track?.readString('onboardingAudience') case final audience?) {
    return audience;
  }
  if (enrollment['child'] != null || (track?.readBool('kidsMode') ?? false)) {
    return 'child';
  }
  return track?.readString('levelLabel') == 'grade'
      ? 'school_student'
      : 'adult';
}

/// How the account signs in, as home's email reminder asks: `authMethods`
/// holds `password`, `google` and `apple`, and a guest's is empty.
String _signIn(Map<String, Object?> me) {
  if (me.readString('accountType') == 'guest') return 'guest';
  final methods = [
    for (final method in me.readList('authMethods') ?? const <Object?>[])
      '$method'.toLowerCase(),
  ];
  if (methods.any((m) => m.contains('password') || m.contains('email'))) {
    return 'email';
  }
  if (methods.any((m) => m.contains('google'))) return 'google';
  if (methods.any((m) => m.contains('apple'))) return 'apple';
  return 'email';
}

/// [enrollments] are `GET /app/enrollments`'s items, [map] the active one's,
/// and [placement] the test's state when the track still waits for it.
Map<String, Object?> homeFromServer({
  required Map<String, Object?> me,
  required List<Map<String, Object?>> enrollments,
  required Map<String, Object?> map,
  Map<String, Object?>? placement,
}) {
  final trackId = map.readString('trackId');
  final active = enrollments
      .where((enrollment) => enrollment.readString('trackId') == trackId)
      .firstOrNull;
  final units = mapUnits(map);
  final level = map.readMap('level');
  final names = levelNames(level);
  // The unit the learner is in: the one that holds the next lesson, else the
  // first not finished that is open.
  final next = map.readString('nextLessonId');
  var current = units.indexWhere(
    (unit) => lessonsFromMap(unit).any((lesson) => lesson['id'] == next),
  );
  if (current < 0) {
    current = units.indexWhere((u) => u.readString('state') == 'unlocked');
  }
  final ordered = map.readString('unlockMode') != 'all_open';
  final completed =
      units.isNotEmpty &&
      units.every((unit) => unit.readString('state') == 'completed');
  return {
    'learner': {
      'name': me.readString('displayName'),
      // The lessons finished in this level: the server has no count of all.
      'lessonsDone': [
        for (final unit in units)
          ...lessonsFromMap(unit).where((lesson) => lesson['done'] == true),
      ].length,
      'emailVerified': me.readBool('emailVerified') ?? false,
      'signIn': _signIn(me),
    },
    'enrollment': {
      'id': trackId,
      'trackId': trackId,
      'title': active?.readMap('track')?.readString('nameAr') ?? '',
      'audience': ?(active == null ? null : _audience(active)),
      'kidsMode': map.readBool('kidsMode') ?? false,
      'ordered': ordered,
      'levelLabel': map.readString('levelLabel'),
    },
    'enrollments': [
      for (final enrollment in enrollments)
        _track(enrollment, current < 0 ? null : units[current]),
    ],
    'level': {
      'id': level?.readString('id'),
      'label': names.label,
      'name': names.name,
      'cefr': ?_cefr[level?.readString('cefrCode')],
      'completed': completed,
    },
    'units': [
      for (final (i, unit) in units.indexed)
        {
          'id': unit.readString('id'),
          'number': i + 1,
          'title': {
            'ar': unit.readString('titleAr'),
            'en': ?unit.readString('titleEn'),
          },
          'cover': ?unit.readString('coverUrl'),
          'status': switch (unit.readString('state')) {
            'completed' => 'done',
            'unlocked' => i == current ? 'current' : 'open',
            _ => 'locked',
          },
          'bookPages': ?unit.readMap('bookPages'),
          'lockedBy': ?(ordered ? lockedByFromMap(units, i) : null),
          if (i == current)
            'lessons': lessonsFromMap(unit)
          else if (unit.readString('state') == 'locked')
            'preview': {
              'goal': [
                for (final goal
                    in unit.readList('objectives') ?? const <Object?>[])
                  if (goal is Map)
                    ?goal.cast<String, Object?>().readString('ar'),
              ].firstOrNull,
              'lessons': lessonsFromMap(unit),
            },
        },
    ],
    'cards': {'placement': ?_placementCard(active, placement)},
  };
}

/// A joined track, as `ProfileModel.trackOf` reads it. The server knows an
/// enrollment by its track, so the track's id stands for both.
Map<String, Object?> _track(
  Map<String, Object?> enrollment,
  Map<String, Object?>? currentUnit,
) {
  final track = enrollment.readMap('track');
  final level = enrollment.readMap('level');
  final names = levelNames(level);
  final active = enrollment.readBool('isActive') ?? false;
  return {
    'enrollmentId': enrollment.readString('trackId'),
    'trackId': enrollment.readString('trackId'),
    'title': track?.readString('nameAr'),
    'audience': _audience(enrollment),
    'levelId': level?.readString('id'),
    'levelLabel': names.label,
    'levelName': names.name,
    'unit': ?enrollment.readInt('unitNo'),
    'units': ?enrollment.readInt('unitCount'),
    'unitCover':
        ?(enrollment.readString('unitCoverUrl') ??
        (active ? currentUnit?.readString('coverUrl') : null) ??
        track?.readString('coverUrl')),
    'active': active,
  };
}

/// «اختبر مستواك», while the track's test is put off and can be taken: how
/// long it takes, without and with its deciding stage.
Map<String, Object?>? _placementCard(
  Map<String, Object?>? enrollment,
  Map<String, Object?>? placement,
) {
  if (!(enrollment?.readBool('placementPending') ?? false)) return null;
  final seconds = placement?.readMap('test')?.readMap('estimatedSeconds');
  final short = seconds?.readInt('withoutTiebreak');
  final long = seconds?.readInt('withTiebreak');
  if (placement?.readString('state') == 'unavailable' ||
      short == null ||
      long == null) {
    return null;
  }
  return {
    'estimatedMinutes': {'min': (short / 60).ceil(), 'max': (long / 60).ceil()},
  };
}
