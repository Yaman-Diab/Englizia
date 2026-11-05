import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/data/datasources/home_remote_data_source.dart';
import 'package:englizia/features/home/data/models/home_model.dart';
import 'package:englizia/features/home/data/repositories/home_repository_impl.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_home_repository.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

/// The server: the bundled home, or no connection.
class _Remote implements HomeRemoteDataSource {
  _Remote(this.json);

  Map<String, Object?> json;
  bool offline = false;

  @override
  Future<HomeModel> getHome() async {
    if (offline) throw const NetworkException('connectionError');
    return HomeModel(json);
  }
}

final _now = DateTime(2026, 11, 5, 10);

HomeSnapshot _parse(void Function(Map<String, Object?> home) change) {
  final json = mockHomeJson(now: _now);
  change(json);
  return HomeModel(json).toEntity();
}

List<Map<String, Object?>> _units(Map<String, Object?> home) => [
  for (final unit in home['units']! as List) unit as Map<String, Object?>,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the model', () {
    test('reads the general track as the design draws it', () {
      final home = mockHome(now: _now);
      expect(home.learner.name, 'أحمد');
      expect(home.learner.lessonsDone, 14);
      expect(home.learner.signIn, SignInMethod.email);
      expect(home.enrollment.id, 'enr_general');
      expect(home.enrollment.audience, TrackAudience.self);
      expect(home.enrollment.levelLabel, HomeLevelLabel.level);
      expect(home.enrollments.map((t) => t.enrollmentId), [
        'enr_general',
        'enr_emar',
      ]);
      expect(home.level.cefr, HomeCefr.a2);
      expect(home.level.next?.label, 'B1');
      expect(home.units, hasLength(8));
      expect(home.currentUnitIndex, 2);
      expect(home.units.first.titleEn, 'Greetings');
      expect(home.units[2].coverUrl, 'assets/mock/units/farm.svg');

      final unit = home.currentUnit!;
      expect(unit.lessons.map((l) => l.id), [
        'les_voc',
        'les_iv',
        'les_gv',
        'les_it',
        'les_chat_box',
        'les_mock',
      ]);
      expect(unit.doneCount, 3);
      expect(unit.lessons[4].ai, isTrue);
      expect(unit.lessons[4].base.scenarioId, 'sc_fragile_box');
      expect(unit.lessons[5].kind, LessonKind.unitReview);
      expect(unit.lessons[5].levelCheck, isFalse);

      final market = home.units[3];
      expect(market.status, UnitLessonStatus.locked);
      expect(market.lessons, isEmpty);
      expect(market.lockedBy?.number, 3);
      expect(market.preview?.goal, 'تسأل عن الأسعار وتشتري ما تحتاجه');
      expect(market.preview?.lessons, hasLength(6));
      expect(market.preview?.roundedMinutes, 40);

      expect(home.todayMinutes, 7);
      expect(home.goalMinutes, 10);
      expect(home.streak?.current, 7);
      expect(home.freezesPerWeek, 1);
      expect(home.review?.total, 15);
      expect(home.review?.minutes, 5);
      expect(home.cards, const HomeCards());
      expect(home.events, isEmpty);
      expect(home.v01, isFalse);
    });

    test('reads Emar: open units with their pages, a grade', () {
      final home = mockHome(emar: true, now: _now);
      expect(home.enrollment.ordered, isFalse);
      expect(home.enrollment.levelLabel, HomeLevelLabel.grade);
      expect(home.level.cefr, isNull);
      expect(home.level.next?.label, 'الصف 8');
      expect(home.units, hasLength(6));
      expect(home.units.skip(3).map((u) => u.status), [
        for (var i = 0; i < 3; i++) UnitLessonStatus.open,
      ]);
      expect(home.units.first.bookPages, (from: 6, to: 17));
      expect(home.units.last.bookPages, (from: 66, to: 77));
      expect(home.currentUnit?.lessons.map((l) => l.page), [
        30,
        32,
        34,
        36,
        39,
        41,
      ]);
    });

    test('reads a child\'s: both names, stars, pictures', () {
      final home = mockHome(kids: true, now: _now);
      expect(home.kids, isTrue);
      expect(home.learner.stars, 14);
      expect(home.learner.firstName, 'ليان');
      expect(home.units.map((u) => u.stars), [5, 4, 2, 0, 0, 0, 0, 0]);
      expect(home.units[2].titleEn, 'Colors');
      expect(home.units[2].titleAudioUrl, isNotNull);
      final lessons = home.currentUnit!.lessons;
      expect(lessons.map((l) => l.title), [
        'Red',
        'Blue',
        'Yellow',
        'Green',
        'Colors song',
        'Rainbow',
      ]);
      expect(lessons.first.base.imageUrl, 'assets/mock/lessons/kids/red.svg');
      expect(lessons.last.base.imageUrl, isNull);
      expect(home.review, isNull);
      expect(home.level.next, isNull);
    });

    test('every scenario of every track reads', () {
      for (final scenario in HomeMockScenario.values) {
        for (final (kids, emar) in [
          (false, false),
          (false, true),
          (true, false),
        ]) {
          expect(
            () => mockHome(scenario: scenario, kids: kids, emar: emar),
            returnsNormally,
            reason: '$scenario kids:$kids emar:$emar',
          );
        }
      }
    });

    test('each scenario is its frame', () {
      HomeSnapshot of(HomeMockScenario scenario) =>
          mockHome(scenario: scenario, now: _now);

      final first = of(HomeMockScenario.firstDay);
      expect(first.learner.lessonsDone, 0);
      expect(first.currentUnitIndex, 0);
      expect(first.currentUnit!.doneCount, 0);
      expect(first.currentUnit!.lessons.last.levelCheck, isTrue);
      expect(first.currentUnit!.lessons.last.id, 'les_mock');
      expect((first.todayMinutes, first.streak?.current), (0, 0));
      expect(first.review, isNull);
      expect(first.units[2].status, UnitLessonStatus.locked);
      expect(first.units[2].preview?.lessons, hasLength(6));

      final partial = of(HomeMockScenario.partial).currentUnit!.lessons[3];
      expect(partial.resume, const LessonResume(question: 3, share: .5));
      expect(partial.questions, 6);

      final goal = of(HomeMockScenario.goalReached);
      expect((goal.todayMinutes, goal.streak?.current), (12, 8));
      expect(of(HomeMockScenario.atRisk).todayMinutes, 5);

      final back = of(HomeMockScenario.welcomeBack);
      expect(back.learner.welcomeBack, isTrue);
      expect((back.todayMinutes, back.streak?.current), (0, 0));
      expect(back.review, isNotNull);

      final freeze = of(HomeMockScenario.freezeUsed);
      expect(freeze.events.single.kind, HomeEventKind.freezeUsed);
      expect(freeze.events.single.on, DateTime(2026, 11, 4));
      expect(freeze.events.single.freezesLeft, 1);
      expect(freeze.streak?.freezes, 1);

      final broke = of(HomeMockScenario.streakBroken);
      expect(broke.events.single.kind, HomeEventKind.streakBroken);
      expect(broke.events.single.streak, 7);
      expect(broke.streak?.current, 0);

      expect(
        of(HomeMockScenario.levelCheck).cards.levelCheckLessonId,
        'les_mock',
      );
      expect(of(HomeMockScenario.placementDeferred).cards.placementMinutes, (
        min: 12,
        max: 15,
      ));

      final last = of(HomeMockScenario.lastLesson).currentUnit!;
      expect(last.lessons[last.currentLesson].id, 'les_mock');

      final lastUnit = of(HomeMockScenario.lastUnit);
      expect(lastUnit.currentUnitIndex, 7);
      expect(lastUnit.currentUnit!.currentLesson, 5);
      expect(lastUnit.currentUnit!.lessons[5].id, 'les_mock');

      final complete = of(HomeMockScenario.levelComplete);
      expect(complete.currentUnit, isNull);
      expect(complete.level.completed, isTrue);
      expect(complete.unitsDone, 8);

      for (final (scenario, count, done) in [
        (HomeMockScenario.newRow, 8, 5),
        (HomeMockScenario.lessons4, 4, 2),
        (HomeMockScenario.lessons8, 8, 4),
        (HomeMockScenario.lessons10, 10, 8),
      ]) {
        final unit = of(scenario).currentUnit!;
        expect(unit.lessons, hasLength(count), reason: '$scenario');
        expect(unit.doneCount, done, reason: '$scenario');
        expect(unit.currentLesson, done, reason: '$scenario');
        expect(unit.lessons.last.kind, LessonKind.unitReview);
        expect(unit.lessons.map((l) => l.id).toSet(), hasLength(count));
      }

      final v01 = of(HomeMockScenario.v01);
      expect((v01.week, v01.streak, v01.review), (null, null, null));
      expect(v01.v01, isTrue);
      expect(v01.todayMinutes, 0);
    });

    test('unknown values read as the least they allow', () {
      final home = _parse((json) {
        final units = _units(json);
        units[3]['status'] = 'sunk';
        final lessons = units[2]['lessons']! as List;
        (lessons[0] as Map<String, Object?>)['kind'] = 'hologram';
        json['events'] = [
          {'id': 'a', 'kind': 'confetti', 'on': '2026-11-04', 'streak': 3},
          {'id': 'b', 'kind': 'streakBroken', 'on': '2026-11-04', 'streak': 3},
          {'kind': 'freezeUsed', 'on': '2026-11-04'},
        ];
        (json['level']! as Map<String, Object?>)['cefr'] = 'z9';
        (json['enrollment']! as Map<String, Object?>)['levelLabel'] = 'tier';
      });
      expect(home.units[3].status, UnitLessonStatus.locked);
      expect(home.currentUnit!.lessons.first.kind, LessonKind.other);
      expect(home.events.map((e) => e.id), ['b']);
      expect(home.level.cefr, isNull);
      expect(home.enrollment.levelLabel, HomeLevelLabel.level);
    });

    test('a part left out isn\'t shown', () {
      final bare = _parse((json) {
        json
          ..remove('week')
          ..remove('review')
          ..remove('cards')
          ..remove('events')
          ..remove('enrollments');
        _units(json)[1]['title'] = 'عائلتي';
        (json['learner']! as Map<String, Object?>)['signIn'] = 'guest';
      });
      expect(bare.v01, isTrue);
      expect(bare.review, isNull);
      expect(bare.cards, const HomeCards());
      expect(bare.events, isEmpty);
      expect(bare.enrollments, isEmpty);
      expect(bare.units[1].title, 'عائلتي');
      expect(bare.units[1].titleEn, isNull);
      expect(bare.learner.signIn, isNull, reason: 'a guest');

      final noLessons = _parse((json) => _units(json)[2]['lessons'] = []);
      expect(noLessons.units[2].status, UnitLessonStatus.open);
      expect(noLessons.currentUnit, isNull);
    });

    test('without a name, an enrollment, a level or units: unreadable', () {
      for (final change in <void Function(Map<String, Object?>)>[
        (json) => (json['learner']! as Map<String, Object?>).remove('name'),
        (json) => json.remove('enrollment'),
        (json) => (json['level']! as Map<String, Object?>).remove('id'),
        (json) => json['units'] = [],
        (json) => json['units'] = [
          {'number': 1},
        ],
      ]) {
        expect(() => _parse(change), throwsFormatException);
      }
    });
  });

  group('the repository', () {
    late SettingsStorageService settings;
    late _Remote remote;
    late HomeRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsStorageService(await SharedPreferences.getInstance());
      remote = _Remote(mockHomeJson(now: _now));
      repository = HomeRepositoryImpl(remote, settings: settings);
    });

    test('keeps what came, to show it next time', () async {
      expect(repository.keptHome, isNull);
      final result = await repository.getHome();
      expect(result, isA<Ok<HomeSnapshot>>());
      expect(repository.keptHome, (result as Ok<HomeSnapshot>).value);
    });

    test('offline: a failure, and what was kept stays', () async {
      await repository.getHome();
      remote.offline = true;
      expect(
        await repository.getHome(),
        const Err<HomeSnapshot>(NetworkFailure()),
      );
      expect(repository.keptHome, isNotNull);
    });

    test('an unreadable kept home is none', () async {
      await settings.setHome(jsonEncode({'learner': 'nobody'}));
      expect(repository.keptHome, isNull);
      await settings.setHome('{not json');
      expect(repository.keptHome, isNull);
    });

    test('the opening once a day', () async {
      expect(repository.openingShownOn('2026-11-05'), isFalse);
      await repository.setOpeningShown('2026-11-05');
      expect(repository.openingShownOn('2026-11-05'), isTrue);
      expect(repository.openingShownOn('2026-11-06'), isFalse);
    });

    test('seen notices: the last 20', () async {
      for (var i = 0; i < 25; i++) {
        await repository.markEventSeen('ev_$i');
      }
      await repository.markEventSeen('ev_10');
      final seen = settings.homeSeenEvents;
      expect(seen, hasLength(20));
      expect(seen.last, 'ev_10');
      expect(repository.seenEvents, contains('ev_24'));
      expect(repository.seenEvents, isNot(contains('ev_4')));
    });

    test('signing out forgets home', () async {
      await repository.getHome();
      await repository.setOpeningShown('2026-11-05');
      await repository.markEventSeen('ev');
      await settings.clearAccountData();
      expect(repository.keptHome, isNull);
      expect(repository.openingShownOn('2026-11-05'), isFalse);
      expect(repository.seenEvents, isEmpty);
    });
  });

  group('the mock server', () {
    late Set<String> completed;
    late String? enrollment;

    HomeFakeDataSource server({bool kids = false}) => HomeFakeDataSource(
      _DiskBundle(),
      activeEnrollmentId: () async => enrollment,
      completedOnPhone: completed.contains,
      kids: kids,
      latency: Duration.zero,
      now: () => _now,
    );

    setUp(() {
      completed = {};
      enrollment = 'enr_general';
    });

    test('follows the active track', () async {
      final mock = server();
      expect((await mock.getHome()).toEntity().enrollment.id, 'enr_general');
      enrollment = 'enr_emar';
      expect((await mock.getHome()).toEntity().enrollment.id, 'enr_emar');
      expect(
        (await server(kids: true).getHome()).toEntity().enrollment.id,
        'enr_kids',
      );
    });

    test('counts a lesson done on the phone once, with its minutes', () async {
      final mock = server();
      await mock.getHome();
      completed.add('les_it');
      final after = (await mock.getHome()).toEntity();
      expect(after.currentUnit!.lessons[3].done, isTrue);
      expect(after.todayMinutes, 14);
      expect(after.streak?.current, 8, reason: 'the goal was reached');
      expect(after.learner.lessonsDone, 15);
      final again = (await mock.getHome()).toEntity();
      expect(again.todayMinutes, 14);
    });

    test(
      'a unit finished opens the next; the last completes the level',
      () async {
        final mock = server()..scenario = HomeMockScenario.lastLesson;
        completed.add('les_mock');
        final next = (await mock.getHome()).toEntity();
        expect(next.units[2].status, UnitLessonStatus.done);
        expect(next.currentUnitIndex, 3);
        expect(next.currentUnit!.doneCount, 0);
        expect(next.units[4].lockedBy?.number, 4);

        mock.scenario = HomeMockScenario.lastUnit;
        final done = (await mock.getHome()).toEntity();
        expect(done.level.completed, isTrue);
        expect(done.currentUnit, isNull);
      },
    );

    test('a done level check leaves its card', () async {
      final mock = server()..scenario = HomeMockScenario.levelCheck;
      expect(
        (await mock.getHome()).toEntity().cards.levelCheckLessonId,
        'les_mock',
      );
      completed.addAll(['les_it', 'les_chat_box', 'les_mock']);
      expect(
        (await mock.getHome()).toEntity().cards.levelCheckLessonId,
        isNull,
      );
    });

    test('offline, a failing refresh, the evening', () async {
      final mock = server()..scenario = HomeMockScenario.offline;
      await expectLater(mock.getHome(), throwsA(isA<NetworkException>()));
      mock.scenario = HomeMockScenario.refreshFails;
      await mock.getHome();
      await expectLater(mock.getHome(), throwsA(isA<ApiException>()));
      expect(mock.now(), _now);
      mock.scenario = HomeMockScenario.atRisk;
      expect(mock.now(), DateTime(2026, 11, 5, 19, 30));
    });

    test('its week ends on today', () async {
      final home = (await server().getHome()).toEntity();
      expect(home.week!.days[home.week!.today].date, DateTime(2026, 11, 5));
    });
  });
}
