import 'dart:io';

import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/data/datasources/home_remote_data_source.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

final _morning = DateTime(2026, 11, 5, 10);
final _evening = DateTime(2026, 11, 5, 19, 30);

/// Home before and after the lessons [done] reach the mock server.
Future<(HomeSnapshot, HomeSnapshot)> _played(
  HomeMockScenario scenario,
  Set<String> done, {
  String enrollment = 'enr_general',
}) async {
  final completed = <String>{};
  final server = HomeFakeDataSource(
    _DiskBundle(),
    activeEnrollmentId: () async => enrollment,
    completedOnPhone: completed.contains,
    latency: Duration.zero,
    now: () => _morning,
  )..scenario = scenario;
  final before = (await server.getHome()).toEntity();
  completed.addAll(done);
  final after = (await server.getHome()).toEntity();
  return (before, after);
}

HomeSnapshot _home([HomeMockScenario scenario = HomeMockScenario.general]) =>
    mockHome(scenario: scenario, now: _morning);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the learner\'s day', () {
    test('starts at the day start, not at midnight', () {
      expect(
        HomeRules.dayKey(DateTime(2026, 11, 5, 3, 59), '04:00'),
        '2026-11-04',
      );
      expect(HomeRules.dayKey(DateTime(2026, 11, 5, 4), '04:00'), '2026-11-05');
      expect(
        HomeRules.dayKey(DateTime(2026, 1, 1, 0, 30), '4:30'),
        '2025-12-31',
      );
      expect(HomeRules.dayKey(DateTime(2026, 11, 5, 0, 1), ''), '2026-11-05');
    });

    test(
      'starts at the day start on the wall clock, on a clock change too',
      () {
        // Every day of years with and without daylight saving where this runs:
        // a day that changes the clock before 04:00 still starts at 04:00.
        const oneDay = Duration(days: 1);
        String key(DateTime d) => d.toIso8601String().substring(0, 10);
        for (final year in const [2021, 2026]) {
          for (
            var day = DateTime.utc(year);
            day.year == year;
            day = day.add(oneDay)
          ) {
            for (final (hour, minute, expected) in [
              (3, 59, key(day.subtract(oneDay))),
              (4, 0, key(day)),
              (4, 30, key(day)),
            ]) {
              final at = DateTime(day.year, day.month, day.day, hour, minute);
              if (at.hour != hour) continue; // not on this clock that day
              expect(HomeRules.dayKey(at, '04:00'), expected, reason: '$at');
            }
          }
        }
      },
    );

    test('today rolls over on the phone at the day start (A30)', () {
      final home = _home(HomeMockScenario.goalReached);
      expect(home.todayMinutes, 12);
      expect(HomeRules.asOf(home, DateTime(2026, 11, 6, 3, 59)), same(home));

      final next = HomeRules.asOf(home, DateTime(2026, 11, 6, 19));
      final week = next.week!;
      expect(week.today, home.week!.today + 1);
      expect(week.days[week.today].date, DateTime(2026, 11, 6));
      expect(week.days, home.week!.days);
      expect(next.todayMinutes, 0);
      expect(HomeRules.status(next), (
        kind: HomeStatusKind.minutesLeft,
        minutesLeft: 10,
      ));
      expect(HomeRules.atRisk(next, DateTime(2026, 11, 6, 19)), isTrue);
    });

    test('past the week\'s last day, today is none of its days', () {
      final later = HomeRules.asOf(
        _home(HomeMockScenario.goalReached),
        DateTime(2026, 11, 9, 10),
      );
      expect(later.week!.today, later.week!.days.length);
      expect(later.todayMinutes, 0);
      expect(HomeRules.asOf(later, DateTime(2026, 11, 10, 10)), same(later));
    });

    test('a phone behind the server\'s day leaves its today', () {
      final home = _home();
      expect(HomeRules.asOf(home, DateTime(2026, 11, 5, 2)), same(home));
      expect(HomeRules.asOf(home, DateTime(2026, 11, 3, 22)), same(home));
      final v01 = _home(HomeMockScenario.v01);
      expect(HomeRules.asOf(v01, DateTime(2026, 11, 9)), same(v01));
    });
  });

  group('the current lesson', () {
    test('is the first not done', () {
      final unit = _home().currentUnit!;
      expect(unit.currentLesson, 3);
      expect(unit.lessons[unit.currentLesson].id, 'les_it');
    });

    test('a unit review waits for every other lesson', () {
      HomeLesson lesson(String id, {bool done = false, bool review = false}) =>
          HomeLesson(
            base: UnitLesson(
              id: id,
              kind: review ? LessonKind.unitReview : LessonKind.vocabulary,
              title: id,
              done: done,
            ),
          );
      expect(
        HomeRules.currentLessonIndex([
          lesson('a', done: true),
          lesson('review', review: true),
          lesson('b'),
        ]),
        2,
      );
      expect(
        HomeRules.currentLessonIndex([
          lesson('a', done: true),
          lesson('review', review: true),
          lesson('b', done: true),
        ]),
        1,
      );
      expect(
        HomeRules.currentLessonIndex([lesson('a', done: true)]),
        1,
        reason: 'all done',
      );
    });
  });

  group('the greeting', () {
    test('first match wins: kids, first day, back, morning, evening', () {
      expect(
        HomeRules.greeting(mockHome(kids: true), _morning),
        HomeGreeting.kids,
      );
      expect(
        HomeRules.greeting(_home(HomeMockScenario.firstDay), _morning),
        HomeGreeting.firstDay,
      );
      expect(
        HomeRules.greeting(_home(HomeMockScenario.welcomeBack), _evening),
        HomeGreeting.back,
      );
      expect(HomeRules.greeting(_home(), _morning), HomeGreeting.morning);
      expect(
        HomeRules.greeting(_home(), DateTime(2026, 11, 5, 12)),
        HomeGreeting.evening,
      );
    });

    test('the name is the first word', () {
      const learner = HomeLearner(name: ' Ahmad  Sami ');
      expect(learner.firstName, 'Ahmad');
    });
  });

  group('the status line', () {
    test('v0.1, first day, goal reached, minutes left', () {
      expect(
        HomeRules.status(_home(HomeMockScenario.v01)).kind,
        HomeStatusKind.next,
      );
      expect(
        HomeRules.status(_home(HomeMockScenario.firstDay)).kind,
        HomeStatusKind.firstLesson,
      );
      expect(
        HomeRules.status(_home(HomeMockScenario.goalReached)).kind,
        HomeStatusKind.goalReached,
      );
      expect(HomeRules.status(_home()), (
        kind: HomeStatusKind.minutesLeft,
        minutesLeft: 3,
      ));
    });

    test('the streak is at risk in the evening, short of the goal', () {
      final risk = _home(HomeMockScenario.atRisk);
      expect(HomeRules.atRisk(risk, _evening), isTrue);
      expect(HomeRules.atRisk(risk, DateTime(2026, 11, 5, 17, 59)), isFalse);
      expect(
        HomeRules.atRisk(_home(HomeMockScenario.goalReached), _evening),
        isFalse,
      );
      expect(
        HomeRules.atRisk(_home(HomeMockScenario.streakBroken), _evening),
        isFalse,
        reason: 'no streak to keep',
      );
      expect(HomeRules.atRisk(mockHome(kids: true), _evening), isFalse);
      expect(HomeRules.atRisk(_home(HomeMockScenario.v01), _evening), isFalse);
    });
  });

  group('the islands', () {
    test('saturation by status, the current by its share done', () {
      final home = _home();
      expect(HomeRules.saturation(home.units[0]), 1);
      expect(HomeRules.saturation(home.units[3]), 0);
      expect(HomeRules.saturation(home.units[2]), .5);
      expect(
        HomeRules.saturation(home.units[2], doneOverride: 4),
        closeTo(.667, .001),
      );
      expect(
        HomeRules.saturation(_home(HomeMockScenario.firstDay).units[0]),
        .15,
      );
      expect(HomeRules.saturation(mockHome(emar: true).units[4]), .15);
    });

    test('units done', () {
      expect(_home().unitsDone, 2);
      expect(_home(HomeMockScenario.levelComplete).unitsDone, 8);
      final allDone = _home(
        HomeMockScenario.lastLesson,
      ).withPhone((_) => const LessonOnPhone(done: true));
      expect(allDone.unitsDone, 3, reason: 'the current one, all done');
    });

    test('the review: a box in the sea, or the first station', () {
      expect(HomeRules.reviewBox(_home()), isTrue);
      expect(HomeRules.reviewFirst(_home()), isFalse);
      final back = _home(HomeMockScenario.welcomeBack);
      expect(HomeRules.reviewFirst(back), isTrue);
      expect(HomeRules.reviewBox(back), isFalse);
      expect(HomeRules.reviewBox(mockHome(kids: true)), isFalse);
      expect(HomeRules.reviewBox(_home(HomeMockScenario.v01)), isFalse);
      expect(
        HomeRules.reviewBox(_home(HomeMockScenario.levelComplete)),
        isFalse,
      );
    });
  });

  group('the notice area', () {
    HomeNotices notices(
      HomeSnapshot home, {
      Set<String> seen = const {},
      bool email = false,
      bool offline = false,
      bool failed = false,
    }) => HomeRules.notices(
      home,
      seen: seen,
      emailReminder: email,
      offline: offline,
      refreshFailed: failed,
    );

    test('nothing by default', () {
      expect(notices(_home()), (
        top: HomeTopNotice.none,
        card: HomeCardNotice.none,
        event: null,
      ));
    });

    test('a one-time notice first, once', () {
      final home = _home(HomeMockScenario.freezeUsed);
      final first = notices(home, email: true);
      expect(first.card, HomeCardNotice.freeze);
      expect(first.event?.kind, HomeEventKind.freezeUsed);
      expect(first.top, HomeTopNotice.none, reason: 'the email waits');
      expect(notices(home, seen: {first.event!.id}).card, HomeCardNotice.none);
      expect(
        notices(_home(HomeMockScenario.streakBroken)).card,
        HomeCardNotice.broke,
      );
    });

    test('the level done, then the email, the check, the test', () {
      expect(
        notices(_home(HomeMockScenario.levelComplete), email: true).card,
        HomeCardNotice.levelDone,
      );
      final check = _home(HomeMockScenario.levelCheck);
      expect(notices(check, email: true), (
        top: HomeTopNotice.email,
        card: HomeCardNotice.none,
        event: null,
      ));
      expect(notices(check).card, HomeCardNotice.levelCheck);
      expect(
        notices(_home(HomeMockScenario.placementDeferred)).card,
        HomeCardNotice.placement,
      );
    });

    test('the email only after the first lesson, never for kids', () {
      expect(
        notices(_home(HomeMockScenario.firstDay), email: true).top,
        HomeTopNotice.none,
      );
      expect(
        notices(mockHome(kids: true), email: true).top,
        HomeTopNotice.none,
      );
    });

    test('a connection strip takes the top slot, beside a card', () {
      final check = _home(HomeMockScenario.levelCheck);
      expect(notices(check, offline: true), (
        top: HomeTopNotice.offline,
        card: HomeCardNotice.levelCheck,
        event: null,
      ));
      expect(
        notices(check, offline: true, failed: true).top,
        HomeTopNotice.refreshFailed,
      );
      expect(
        notices(_home(), email: true, offline: true).top,
        HomeTopNotice.offline,
      );
    });

    test('kids never get one-time notices', () {
      final kids = mockHome(kids: true);
      final withEvent = kids.copyWith(
        events: [
          HomeEvent(
            id: 'ev',
            kind: HomeEventKind.streakBroken,
            on: _morning,
            streak: 3,
          ),
        ],
      );
      expect(notices(withEvent).card, HomeCardNotice.none);
    });
  });

  group('the page search', () {
    test('keeps three digits, Arabic-Indic ones too', () {
      final arabic = String.fromCharCodes([0x663, 0x664]);
      expect(HomeRules.parsePage('34'), 34);
      expect(HomeRules.parsePage(arabic), 34);
      expect(HomeRules.pageDigits('1234'), '123');
      expect(HomeRules.parsePage('a3b'), 3);
      expect(HomeRules.parsePage(''), isNull);
      expect(HomeRules.parsePage('0'), isNull);
      expect(HomeRules.parsePage('00'), isNull);
    });

    test('the book runs from the first unit to the last', () {
      expect(HomeRules.bookRange(mockHome(emar: true)), (from: 6, to: 77));
      expect(HomeRules.bookRange(_home()), isNull);
    });

    test('a page is in the unit whose pages hold it', () {
      final emar = mockHome(emar: true);
      expect(HomeRules.findPage(emar, 39), const PageHit.lesson(2, 4));
      expect(HomeRules.findPage(emar, 30), const PageHit.lesson(2, 0));
      expect(HomeRules.findPage(emar, 41), const PageHit.lesson(2, 5));
      expect(
        HomeRules.findPage(emar, 18),
        const PageHit.unit(1),
        reason: 'unit 2 starts at 18 (A8)',
      );
      expect(HomeRules.findPage(emar, 55), const PageHit.unit(4));
      expect(HomeRules.findPage(emar, 5), isNull);
      expect(HomeRules.findPage(emar, 78), isNull);
    });
  });

  group('what a return celebrates', () {
    test(
      'a lesson done: its stone, the next, the minutes and the goal',
      () async {
        final (before, after) = await _played(HomeMockScenario.general, {
          'les_it',
        });
        final moment = HomeRules.diff(before, after);
        expect(moment, isA<LessonDoneMoment>());
        moment as LessonDoneMoment;
        expect(moment.lesson, 3);
        expect(moment.next, 4);
        expect(
          (moment.minutesFrom, moment.minutesTo, moment.goal),
          (7, 14, 10),
        );
        expect((moment.streakFrom, moment.streakTo), (7, 8));
        expect(moment.goalReached, isTrue);
      },
    );

    test('a unit done opens the next', () async {
      final (before, after) = await _played(HomeMockScenario.lastLesson, {
        'les_mock',
      });
      final moment = HomeRules.diff(before, after);
      expect(moment, isA<UnitDoneMoment>());
      moment as UnitDoneMoment;
      expect((moment.unit, moment.nextUnit, moment.levelDone), (2, 3, false));
      expect(after.currentUnit?.lessons.first.id, 'les_market_words');
    });

    test('the level\'s last unit done completes the level', () async {
      final (before, after) = await _played(HomeMockScenario.lastUnit, {
        'les_mock',
      });
      final moment = HomeRules.diff(before, after);
      expect(moment, isA<UnitDoneMoment>());
      moment as UnitDoneMoment;
      expect((moment.unit, moment.nextUnit, moment.levelDone), (7, null, true));
      expect(after.level.completed, isTrue);
    });

    test('the phone alone still celebrates the unit', () {
      final before = _home(HomeMockScenario.lastLesson);
      final after = before.withPhone(
        (id) => LessonOnPhone(done: id == 'les_mock'),
      );
      final moment = HomeRules.diff(before, after);
      expect(moment, isA<UnitDoneMoment>());
      expect((moment! as UnitDoneMoment).nextUnit, isNull);
    });

    test(
      'nothing new, two lessons at once, or another track: a swap',
      () async {
        expect(HomeRules.diff(_home(), _home()), isNull);
        final (before, after) = await _played(HomeMockScenario.general, {
          'les_it',
          'les_chat_box',
        });
        expect(HomeRules.diff(before, after), isNull);
        expect(HomeRules.diff(_home(), mockHome(emar: true)), isNull);
        expect(
          HomeRules.diff(_home(HomeMockScenario.levelComplete), _home()),
          isNull,
          reason: 'no current unit before',
        );
      },
    );
  });
}
