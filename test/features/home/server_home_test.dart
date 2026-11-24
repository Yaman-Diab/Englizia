import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/home/data/datasources/home_remote_data_source.dart';
import 'package:englizia/features/home/data/models/home_model.dart';
import 'package:englizia/features/home/data/models/server_home.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/lessons/data/datasources/unit_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/server_unit.dart';
import 'package:englizia/features/lessons/data/models/unit_plan_model.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

/// The dev server's own answers (`test/fixtures/api`).
Object? _body(String name) =>
    jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync());

Map<String, Object?> _data(String name) =>
    asJsonMap(ApiClient.unwrap(_body(name)));

List<Map<String, Object?>> _enrollments() => [
  for (final item in _data('app_enrollments_one').readList('items')!)
    asJsonMap(item),
];

const _track = '01a1f24f-ea3e-7693-b3a7-a60061ac9a53';
const _unit1 = '01a1f24f-eda5-7458-8d96-85170e60ccd1';
const _unit2 = '01a1f24f-f52a-7be8-b2e8-eacf638e789f';
const _lesson1 = '01a1f24f-eec9-7d31-8c4b-624e894c7858';
const _lesson2 = '01a1f24f-f304-732f-bcc9-59276e455482';

HomeSnapshot _home({
  String map = 'app_map_in_progress',
  void Function(Map<String, Object?> map)? change,
  List<Map<String, Object?>>? enrollments,
  Map<String, Object?>? placement,
}) {
  final json = _data(map);
  change?.call(json);
  return HomeModel(
    homeFromServer(
      me: _data('app_me_guest'),
      enrollments: enrollments ?? _enrollments(),
      map: json,
      placement: placement,
    ),
  ).toEntity();
}

void main() {
  group('home from the server’s map', () {
    test('the learner, the track and the level', () {
      final home = _home();

      expect(home.learner.name, _data('app_me_guest')['displayName']);
      expect(home.learner.signIn, isNull, reason: 'a guest');
      expect(home.learner.lessonsDone, 1);
      expect(home.enrollment.id, _track);
      expect(home.enrollment.trackId, _track);
      expect(home.enrollment.title, 'الإنجليزية العامة (تجريبي)');
      expect(home.enrollment.audience, TrackAudience.self);
      expect(home.enrollment.kidsMode, isFalse);
      expect(home.enrollment.ordered, isTrue);
      expect(home.enrollment.levelLabel, HomeLevelLabel.level);
      expect(home.level.label, 'A1');
      expect(home.level.name, 'المبتدئ', reason: 'its code isn’t said twice');
      expect(home.level.cefr, HomeCefr.a1);
      expect(home.level.completed, isFalse);
      expect(home.level.next, isNull);
    });

    test('what the server doesn’t say yet is left out', () {
      final home = _home();

      expect(home.week, isNull);
      expect(home.streak, isNull);
      expect(home.review, isNull);
      expect(home.events, isEmpty);
      expect(home.cards.placementMinutes, isNull);
      expect(home.cards.levelCheckLessonId, isNull);
      expect(home.v01, isTrue);
    });

    test('the units in order: the one in hand, then the locked one', () {
      final home = _home();

      expect(home.units.map((u) => (u.id, u.number, u.status)), [
        (_unit1, 1, UnitLessonStatus.current),
        (_unit2, 2, UnitLessonStatus.locked),
      ]);
      final first = home.units.first;
      expect(first.title, 'التعريف بالنفس');
      expect(first.titleEn, 'About me');
      expect(first.coverUrl, endsWith('.webp'));
      expect(first.lockedBy, isNull);
      expect(home.units.last.lockedBy?.id, _unit1);
      expect(home.units.last.lockedBy?.number, 1);
    });

    test('the unit in hand has its lessons, done or not', () {
      final lessons = _home().units.first.lessons;

      expect(lessons.map((l) => (l.base.id, l.base.done)), [
        (_lesson1, true),
        (_lesson2, false),
      ]);
      expect(lessons.first.base.kind, LessonKind.grammarVideo);
      expect(lessons.first.base.title, 'الفعل to be: am وis وare');
      expect(lessons.first.base.minutes, 8);
    });

    test('a new learner starts at the first lesson of the first unit', () {
      final home = _home(map: 'app_map_new_learner');

      expect(home.learner.lessonsDone, 0);
      expect(home.units.first.status, UnitLessonStatus.current);
      expect(home.units.first.lessons.every((l) => !l.base.done), isTrue);
    });

    test('a locked unit shows what it holds, without being fetched', () {
      final preview = _home().units.last.preview!;

      expect(preview.lessons.map((l) => l.title), [
        'الجمع بإضافة s',
        'this وthese',
      ]);
      expect(preview.lessons.first.kind, LessonKind.grammarVideo);
      expect(preview.lessons.first.minutes, 8);
    });

    test('every unit finished ends the level', () {
      final home = _home(
        change: (map) {
          map['nextLessonId'] = null;
          for (final unit in map.readList('units')!) {
            asJsonMap(unit)['state'] = 'completed';
          }
        },
      );

      expect(home.level.completed, isTrue);
      expect(
        home.units.every((u) => u.status == UnitLessonStatus.done),
        isTrue,
      );
    });

    test('a track open all at once locks nothing', () {
      final home = _home(
        change: (map) {
          map['unlockMode'] = 'all_open';
          asJsonMap(map.readList('units')!.last)['state'] = 'unlocked';
        },
      );

      expect(home.enrollment.ordered, isFalse);
      expect(home.units.last.status, UnitLessonStatus.open);
      expect(home.units.last.lockedBy, isNull);
    });

    test('the joined tracks, the active one with its unit', () {
      final track = _home().enrollments.single;

      expect(track.enrollmentId, _track);
      expect(track.trackId, _track);
      expect(track.title, 'الإنجليزية العامة (تجريبي)');
      expect(track.levelLabel, 'A1');
      expect(track.levelName, 'المبتدئ');
      expect(track.unit, 1);
      expect(track.units, 2);
      expect(track.active, isTrue);
      expect(track.unitCoverUrl, _home().units.first.coverUrl);
    });

    Map<String, Object?> enrollment(void Function(Map<String, Object?>) to) {
      final one = _enrollments().single;
      to(one);
      return one;
    }

    test('whose track it is, as the track says', () {
      HomeSnapshot as(String audience) => _home(
        enrollments: [
          enrollment(
            (e) => asJsonMap(e['track'])['onboardingAudience'] = audience,
          ),
        ],
      );

      expect(_home().enrollment.audience, TrackAudience.self, reason: 'adult');
      expect(as('child').enrollment.audience, TrackAudience.child);
      expect(
        as('school_student').enrollment.audience,
        TrackAudience.schoolStudent,
      );
    });

    test('a track that doesn\u2019t say: read from what it carries', () {
      void unsaid(Map<String, Object?> e) =>
          asJsonMap(e['track']).remove('onboardingAudience');
      final child = _home(
        enrollments: [
          enrollment((e) {
            unsaid(e);
            e['child'] = {'name': 'Child', 'age': 7};
          }),
        ],
      );
      final school = _home(
        enrollments: [
          enrollment((e) {
            unsaid(e);
            asJsonMap(e['track'])['levelLabel'] = 'grade';
          }),
        ],
      );

      expect(child.enrollment.audience, TrackAudience.child);
      expect(school.enrollment.audience, TrackAudience.schoolStudent);
    });

    test('the active track\u2019s cover is the enrollment\u2019s own', () {
      final track = _home(
        enrollments: [
          enrollment((e) => e['unitCoverUrl'] = 'https://example.com/u.webp'),
        ],
      ).enrollments.single;

      expect(track.unitCoverUrl, 'https://example.com/u.webp');
    });

    test('a test put off shows its card, with how long it takes', () {
      final pending = _enrollments().single..['placementPending'] = true;

      final home = _home(
        enrollments: [pending],
        placement: _data('app_placement_available'),
      );

      // 675 and 875 seconds.
      expect(home.cards.placementMinutes, (min: 12, max: 15));
      expect(
        _home(enrollments: [pending]).cards.placementMinutes,
        isNull,
        reason: 'no state, no card',
      );
    });
  });

  group('a unit from the map', () {
    UnitPlan unit(String id, {String map = 'app_map_in_progress'}) =>
        UnitPlanModel(unitFromMap(_data(map), id)!).toEntity();

    test('its place, its grammar and its lessons', () {
      final first = unit(_unit1);

      expect(first.number, 1);
      expect(first.title, 'التعريف بالنفس');
      expect(first.levelLabel, 'A1');
      expect(first.coverUrl, endsWith('.webp'));
      expect(first.ordered, isTrue);
      expect(first.kids, isFalse);
      expect(first.concepts.first, 'الفعل to be: am وis وare');
      expect(first.concepts, hasLength(4));
      expect(first.lessons.map((l) => (l.id, l.done)), [
        (_lesson1, true),
        (_lesson2, false),
      ]);
      expect(first.lockedBy, isNull);
      expect(first.next?.id, _unit2);
      expect(first.next?.number, 2);
    });

    test('a locked unit names the one that opens it', () {
      final second = unit(_unit2);

      expect(second.lockedBy?.id, _unit1);
      expect(second.lockedBy?.number, 1);
      expect(second.next, isNull);
    });

    test('its goals are the unit’s objectives, in Arabic', () {
      final map = _data('app_map_in_progress');
      asJsonMap(map.readList('units')!.first)['objectives'] = [
        {'ar': 'أن تعرّف بنفسك', 'en': 'Introduce yourself'},
      ];

      expect(UnitPlanModel(unitFromMap(map, _unit1)!).toEntity().goals, [
        'أن تعرّف بنفسك',
      ]);
    });

    test('a unit the level doesn’t have is none', () {
      expect(unitFromMap(_data('app_map_in_progress'), 'no-such'), isNull);
    });
  });

  group('the calls', () {
    late FakeHttpAdapter adapter;
    late ApiClient client;
    late Map<String, FakeResponse> answers;

    setUp(() {
      answers = {
        '/api/v1/app/enrollments': FakeResponse(
          200,
          body: _body('app_enrollments_one'),
        ),
        '/api/v1/app/me': FakeResponse(200, body: _body('app_me_guest')),
        '/api/v1/app/enrollments/$_track/map': FakeResponse(
          200,
          body: _body('app_map_in_progress'),
        ),
        '/api/v1/app/placement': FakeResponse(
          200,
          body: _body('app_placement_available'),
        ),
      };
      adapter = FakeHttpAdapter(
        (request) =>
            answers[request.path] ??
            const FakeResponse(
              404,
              body: {
                'statusCode': 404,
                'error': {'code': 'route.not_found'},
              },
            ),
      );
      client = ApiClient(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
      );
    });

    List<String> asked() => [for (final r in adapter.requests) r.path];

    Map<String, Object?> pendingEnrollments() {
      final body = asJsonMap(_body('app_enrollments_one'));
      asJsonMap(
        asJsonMap(body['data']).readList('items')!.single,
      )['placementPending'] = true;
      return body;
    }

    test('home is the account, the tracks and the active one’s map', () async {
      final home = (await HomeRemoteDataSourceImpl(
        client,
      ).getHome()).toEntity();

      expect(asked().first, '/api/v1/app/enrollments');
      expect(asked().toSet(), {
        '/api/v1/app/enrollments',
        '/api/v1/app/me',
        '/api/v1/app/enrollments/$_track/map',
      });
      expect(home.units, hasLength(2));
    });

    test('a test put off is asked about, for its card', () async {
      answers['/api/v1/app/enrollments'] = FakeResponse(
        200,
        body: pendingEnrollments(),
      );

      final home = (await HomeRemoteDataSourceImpl(
        client,
      ).getHome()).toEntity();

      expect(adapter.requests.last.path, '/api/v1/app/placement');
      expect(adapter.requests.last.query, {'trackId': _track});
      expect(home.cards.placementMinutes, (min: 12, max: 15));
    });

    test('home shows without the test’s state', () async {
      answers
        ..['/api/v1/app/enrollments'] = FakeResponse(
          200,
          body: pendingEnrollments(),
        )
        ..remove('/api/v1/app/placement');

      final home = (await HomeRemoteDataSourceImpl(
        client,
      ).getHome()).toEntity();

      expect(home.cards.placementMinutes, isNull);
      expect(home.units, hasLength(2));
    });

    test('with no track joined there is no home to draw', () async {
      answers['/api/v1/app/enrollments'] = FakeResponse(
        200,
        body: _body('app_enrollments_empty'),
      );

      await expectLater(
        HomeRemoteDataSourceImpl(client).getHome(),
        throwsFormatException,
      );
      expect(asked(), ['/api/v1/app/enrollments']);
    });

    test(
      'a unit is read from its level’s map, and the track remembered',
      () async {
        final source = UnitRemoteDataSourceImpl(client);

        final first = (await source.getUnit(_unit1)).toEntity();
        final second = (await source.getUnit(_unit2)).toEntity();

        expect(first.id, _unit1);
        expect(second.id, _unit2);
        expect(asked(), [
          '/api/v1/app/enrollments',
          '/api/v1/app/enrollments/$_track/map',
          '/api/v1/app/enrollments/$_track/map',
        ]);
      },
    );

    test('a unit the level doesn’t have is not found', () async {
      final source = UnitRemoteDataSourceImpl(client);
      await source.getUnit(_unit1);

      await expectLater(
        source.getUnit('no-such'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });

    test('a track left is asked for again', () async {
      final source = UnitRemoteDataSourceImpl(client);
      await source.getUnit(_unit1);
      const other = 'other-track';
      final map = asJsonMap(_body('app_map_in_progress'));
      asJsonMap(map['data'])['trackId'] = other;
      final enrollments = asJsonMap(_body('app_enrollments_one'));
      asJsonMap(
        asJsonMap(enrollments['data']).readList('items')!.single,
      )['trackId'] = other;
      answers
        ..remove('/api/v1/app/enrollments/$_track/map')
        ..['/api/v1/app/enrollments'] = FakeResponse(200, body: enrollments)
        ..['/api/v1/app/enrollments/$other/map'] = FakeResponse(200, body: map);
      adapter.requests.clear();

      final unit = (await source.getUnit(_unit2)).toEntity();

      expect(unit.id, _unit2);
      expect(asked(), [
        '/api/v1/app/enrollments/$_track/map',
        '/api/v1/app/enrollments',
        '/api/v1/app/enrollments/$other/map',
      ]);
    });
  });
}
