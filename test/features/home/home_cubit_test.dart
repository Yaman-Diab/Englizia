import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/data/models/home_model.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';
import '../../helpers/fake_lesson_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';

final _morning = DateTime(2026, 11, 5, 10);

HomeSnapshot _home([HomeMockScenario scenario = HomeMockScenario.general]) =>
    mockHome(scenario: scenario, now: _morning);

HomeSnapshot _afterLesson() => mockHomeAfterLesson(now: _morning);

/// [scenario] with unit [index] the current one.
HomeSnapshot _movedTo(HomeMockScenario scenario, int index) {
  final json = mockHomeJson(scenario: scenario, now: _morning);
  moveCurrentUnit(json, index);
  return HomeModel(json).toEntity();
}

void main() {
  late FakeHomeRepository homes;
  late FakeProfileRepository profiles;
  late FakeLessonRepository lessons;
  late FakeConnectivityService connectivity;
  late FakeSoundPlayer sounds;
  late DateTime now;

  setUp(() {
    homes = FakeHomeRepository(_home());
    profiles = FakeProfileRepository(mockProfile());
    lessons = FakeLessonRepository();
    connectivity = FakeConnectivityService();
    sounds = FakeSoundPlayer();
    now = _morning;
  });

  HomeCubit cubit() {
    final subject = HomeCubit(
      homes,
      profiles,
      lessons,
      connectivity,
      sounds,
      now: () => now,
    );
    addTearDown(subject.close);
    return subject;
  }

  group('opening', () {
    test('what was kept shows at once, then the server\'s', () async {
      homes.kept = _home(HomeMockScenario.atRisk);
      profiles.kept = mockProfile();
      final subject = cubit();
      final shown = <HomeSnapshot?>[];
      final listening = subject.stream.listen((s) => shown.add(s.home));
      addTearDown(listening.cancel);

      await subject.start();

      expect(shown.whereType<HomeSnapshot>().first, homes.kept);
      expect(subject.state.home, _home());
      expect(subject.state.load, LoadStatus.ready);
      expect(subject.state.trackTitle, 'الإنجليزية العامة');
      expect(subject.state.kidsHint, isFalse);
      expect(homes.fetches, 1);
    });

    test(
      'a child\'s kept profile asks for the kids\' shell before data',
      () async {
        profiles.kept = mockProfile(kids: true);
        homes
          ..home = null
          ..failure = const NetworkFailure();
        final subject = cubit();
        await subject.start();
        expect(subject.state.home, isNull);
        expect(subject.state.kids, isTrue);
      },
    );

    test('nothing kept and no connection: the failure', () async {
      homes
        ..home = null
        ..failure = const NetworkFailure();
      profiles.failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();
      expect(subject.state.load, LoadStatus.failure);
      expect(subject.state.failure, const NetworkFailure());
      expect(subject.state.home, isNull);
      expect(subject.state.trackTitle, isNull);
    });

    test(
      'a first open names the track from the profile (header §2.1)',
      () async {
        homes
          ..home = null
          ..failure = const ServerFailure(statusCode: 500);
        final subject = cubit();
        await subject.start();
        await pumpEventQueue();
        expect(profiles.fetches, 1);
        expect(subject.state.load, LoadStatus.failure);
        expect(subject.state.trackTitle, 'الإنجليزية العامة');
        expect(subject.state.kidsHint, isFalse);
      },
    );

    test('a kept home or profile needs no profile fetch', () async {
      profiles.kept = mockProfile();
      await cubit().start();
      profiles.kept = null;
      homes.kept = _home();
      await cubit().start();
      await pumpEventQueue();
      expect(profiles.fetches, 0);
    });

    test(
      'the current lesson is fetched ahead, so «تابع» opens offline',
      () async {
        await cubit().start();
        expect(lessons.fetched, ['les_it']);
      },
    );

    test('the phone\'s own progress wins over the server\'s', () async {
      lessons.phone['les_it'] = const LessonOnPhone(
        kept: true,
        resume: LessonResume(question: 2, share: .25),
      );
      final subject = cubit();
      await subject.start();
      final lesson = subject.state.home!.currentUnit!.lessons[3];
      expect(lesson.resume?.question, 2);
      expect(lesson.kept, isTrue);
    });

    test('the opening plays once a day', () async {
      final first = cubit();
      await first.start();
      expect(first.state.openingDue, isTrue);
      first.openingPlayed();
      expect(first.state.openingDue, isFalse);
      expect(homes.openingDay, '2026-11-05');

      final again = cubit();
      await again.start();
      expect(again.state.openingDue, isFalse);

      now = DateTime(2026, 11, 6, 4, 30);
      final tomorrow = cubit();
      await tomorrow.start();
      expect(tomorrow.state.openingDue, isTrue);
    });
  });

  group('refreshing', () {
    test('offline with something shown: the strip, the data stays', () async {
      homes.kept = _home();
      homes.failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();
      expect(subject.state.home, isNotNull);
      expect(subject.state.offlineFetch, isTrue);
      expect(subject.state.offline, isTrue);
      expect(subject.state.refreshFailed, isFalse);

      homes.failure = null;
      expect(await subject.refresh(), isTrue);
      expect(subject.state.offline, isFalse);
    });

    test('a refresh asked for that fails says so, until dismissed', () async {
      final subject = cubit();
      await subject.start();
      homes.failure = const ServerFailure(statusCode: 500);
      expect(await subject.refresh(byUser: true), isFalse);
      expect(subject.state.refreshFailed, isTrue);
      expect(subject.state.load, LoadStatus.ready);
      subject.dismissRefreshFailure();
      expect(subject.state.refreshFailed, isFalse);
    });

    test('the connection coming back refreshes', () async {
      final subject = cubit();
      await subject.start();
      connectivity.online = false;
      await pumpEventQueue();
      expect(subject.state.online, isFalse);
      expect(subject.state.offline, isTrue);
      connectivity.online = true;
      await pumpEventQueue();
      expect(subject.state.online, isTrue);
      expect(homes.fetches, 2);
    });

    test('the badge: what is due, never for kids or v0.1', () async {
      final subject = cubit();
      await subject.start();
      expect(subject.state.badge, 15);
      homes.home = mockHome(kids: true);
      await subject.refresh();
      expect(subject.state.badge, 0);
      homes.home = _home(HomeMockScenario.v01);
      await subject.refresh();
      expect(subject.state.badge, 0);
    });
  });

  group('back from a lesson', () {
    test('a lesson done: celebrated, then played', () async {
      final subject = cubit();
      await subject.start();
      homes.home = _afterLesson();

      await subject.returned();

      final moment = subject.state.moment;
      expect(moment, isA<LessonDoneMoment>());
      expect(subject.state.momentId, 1);
      expect(subject.state.home, _afterLesson());
      expect(moment!.goalReached, isTrue);
      subject.momentPlayed();
      expect(subject.state.moment, isNull);
      expect(subject.state.momentId, 1);
    });

    test('a refresh while a page covers home waits for the return', () async {
      final subject = cubit();
      await subject.start();
      subject.left();
      homes.home = _afterLesson();

      expect(await subject.refresh(), isTrue);
      expect(subject.state.home, _home(), reason: 'home stays as drawn');
      expect(subject.state.refreshing, isFalse);

      await subject.returned();
      expect(subject.state.moment, isA<LessonDoneMoment>());
      expect(subject.state.home, _afterLesson());
    });

    test(
      'a return without the server celebrates what came meanwhile',
      () async {
        final subject = cubit();
        await subject.start();
        subject.left();
        homes.home = _afterLesson();
        await subject.refresh();
        homes.failure = const NetworkFailure();

        await subject.returned();

        expect(subject.state.moment, isA<LessonDoneMoment>());
        expect(subject.state.home, _afterLesson());
        expect(subject.state.offlineFetch, isTrue);
      },
    );

    test('once back, a refresh shows at once', () async {
      final subject = cubit();
      await subject.start();
      subject.left();
      await subject.returned();
      homes.home = _afterLesson();
      await subject.refresh();
      expect(subject.state.home, _afterLesson());
      expect(subject.state.moment, isNull);
    });

    test('nothing done: a plain swap', () async {
      final subject = cubit();
      await subject.start();
      await subject.returned();
      expect(subject.state.moment, isNull);
      expect(subject.state.momentId, 0);
    });

    test('a unit done opens the next', () async {
      homes.home = _home(HomeMockScenario.lastLesson);
      final subject = cubit();
      await subject.start();
      homes.home = _movedTo(HomeMockScenario.general, 3);

      await subject.returned();

      final moment = subject.state.moment;
      expect(moment, isA<UnitDoneMoment>());
      expect((moment! as UnitDoneMoment).nextUnit, 3);
      expect(subject.state.levelJustDone, isFalse);
    });

    test('the level done: its card at the horizon this session', () async {
      homes.home = _home(HomeMockScenario.lastUnit);
      final subject = cubit();
      await subject.start();
      homes.home = _home(HomeMockScenario.levelComplete);

      await subject.returned();

      expect((subject.state.moment! as UnitDoneMoment).levelDone, isTrue);
      expect(subject.state.levelJustDone, isTrue);
    });

    testWidgets('a slow server: the phone\'s completion is celebrated', (
      tester,
    ) async {
      final subject = HomeCubit(
        homes,
        profiles,
        lessons,
        connectivity,
        sounds,
        now: () => now,
      );
      await subject.start();
      final hold = Completer<void>();
      homes.gate = hold.future;
      lessons.phone['les_it'] = const LessonOnPhone(done: true);

      final returning = subject.returned();
      await tester.pump(HomeCubit.returnWait);
      await returning;

      expect(subject.state.moment, isA<LessonDoneMoment>());
      expect(subject.state.home!.currentUnit!.lessons[3].done, isTrue);
      hold.complete();
      await subject.close();
    });

    testWidgets('a slow server\'s answer still shows when it comes', (
      tester,
    ) async {
      final subject = HomeCubit(
        homes,
        profiles,
        lessons,
        connectivity,
        sounds,
        now: () => now,
      );
      await subject.start();
      final hold = Completer<void>();
      homes
        ..gate = hold.future
        ..home = _afterLesson();
      lessons.phone['les_it'] = const LessonOnPhone(done: true);

      final returning = subject.returned();
      await tester.pump(HomeCubit.returnWait);
      await returning;
      final moment = subject.state.moment!;
      expect((moment.minutesFrom, moment.minutesTo), (7, 7));
      expect(subject.state.home!.todayMinutes, 7);

      hold.complete();
      await tester.pump();
      expect(subject.state.home!.todayMinutes, 14);
      expect(subject.state.home!.streak!.current, 8);
      expect(subject.state.momentId, 1, reason: 'nothing more to celebrate');
      await subject.close();
    });

    testWidgets('a unit the phone finished celebrates once, though the '
        'server catches up on the next return', (tester) async {
      homes.home = _home(HomeMockScenario.lastLesson);
      final subject = HomeCubit(
        homes,
        profiles,
        lessons,
        connectivity,
        sounds,
        now: () => now,
      );
      await subject.start();
      final hold = Completer<void>();
      homes
        ..gate = hold.future
        ..home = _movedTo(HomeMockScenario.general, 3);
      lessons.phone['les_mock'] = const LessonOnPhone(done: true);

      final returning = subject.returned();
      await tester.pump(HomeCubit.returnWait);
      await returning;
      expect(subject.state.moment, isA<UnitDoneMoment>());
      expect((subject.state.moment! as UnitDoneMoment).nextUnit, isNull);
      subject.momentPlayed();

      homes.gate = null;
      subject.left();
      await subject.returned();
      expect(subject.state.home!.currentUnitIndex, 3);
      expect(subject.state.moment, isNull);
      expect(subject.state.momentId, 1, reason: 'M6 played once');

      hold.complete();
      await tester.pump();
      expect(subject.state.momentId, 1);
      await subject.close();
    });

    test('an offline return still celebrates the phone', () async {
      final subject = cubit();
      await subject.start();
      homes.failure = const NetworkFailure();
      lessons.phone['les_it'] = const LessonOnPhone(done: true);

      await subject.returned();

      final moment = subject.state.moment;
      expect(moment, isA<LessonDoneMoment>());
      moment as LessonDoneMoment;
      expect((moment.lesson, moment.next), (3, 4));
      expect((moment.minutesFrom, moment.minutesTo), (7, 7));
      expect(moment.goalReached, isFalse);
      expect(subject.state.offlineFetch, isTrue);
      expect(subject.state.momentId, 1);
    });

    test('a return before any data just loads', () async {
      homes
        ..home = null
        ..failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();
      expect(subject.state.load, LoadStatus.failure);
      homes
        ..failure = null
        ..home = _home();

      await subject.returned();

      expect(subject.state.load, LoadStatus.ready);
      expect(subject.state.home, _home());
      expect(subject.state.moment, isNull);
      expect(subject.state.momentId, 0);
      expect(homes.fetches, 2);
    });

    test('a good return clears a failed refresh', () async {
      final subject = cubit();
      await subject.start();
      homes.failure = const ServerFailure(statusCode: 500);
      await subject.refresh(byUser: true);
      expect(subject.state.refreshFailed, isTrue);
      homes.failure = null;

      await subject.returned();

      expect(subject.state.refreshFailed, isFalse);
      expect(subject.state.offlineFetch, isFalse);
    });

    test('a lesson the server hasn\'t heard of yet: the phone\'s next one is '
        'fetched ahead', () async {
      final subject = cubit();
      await subject.start();
      lessons.phone['les_it'] = const LessonOnPhone(done: true);

      await subject.returned();

      expect(subject.state.moment, isA<LessonDoneMoment>());
      expect(lessons.fetched.last, 'les_chat_box');
    });

    test('a return while one is compared joins it: one moment', () async {
      final subject = cubit();
      await subject.start();
      final hold = Completer<void>();
      homes
        ..gate = hold.future
        ..home = _afterLesson();

      final first = subject.returned();
      subject.left();
      final second = subject.returned();
      hold.complete();
      await Future.wait([first, second]);

      expect(subject.state.moment, isA<LessonDoneMoment>());
      expect(subject.state.momentId, 1);
      expect(homes.fetches, 2);
    });
  });

  group('the day', () {
    testWidgets('the clock ticks; a new day refreshes', (tester) async {
      now = DateTime(2026, 11, 6, 3, 58);
      final subject = HomeCubit(
        homes,
        profiles,
        lessons,
        connectivity,
        sounds,
        now: () => now,
      );
      await subject.start();
      expect(homes.fetches, 1);

      now = DateTime(2026, 11, 6, 3, 59);
      await tester.pump(HomeCubit.tick);
      expect(subject.state.now, now);
      expect(homes.fetches, 1);

      now = DateTime(2026, 11, 6, 4, 1);
      await tester.pump(HomeCubit.tick);
      await tester.pump();
      expect(homes.fetches, 2);
      await subject.close();
    });

    testWidgets('a new day starts on the phone, even offline (A30)', (
      tester,
    ) async {
      homes.home = _home(HomeMockScenario.goalReached);
      now = DateTime(2026, 11, 6, 3, 58);
      final subject = HomeCubit(
        homes,
        profiles,
        lessons,
        connectivity,
        sounds,
        now: () => now,
      );
      await subject.start();
      expect(subject.state.status.kind, HomeStatusKind.goalReached);

      homes.failure = const NetworkFailure();
      now = DateTime(2026, 11, 6, 4, 1);
      await tester.pump(HomeCubit.tick);
      await tester.pump();
      expect(homes.fetches, 2);
      expect(subject.state.home!.todayMinutes, 0);
      expect(subject.state.status, (
        kind: HomeStatusKind.minutesLeft,
        minutesLeft: 10,
      ));

      now = DateTime(2026, 11, 6, 19);
      await tester.pump(HomeCubit.tick);
      expect(subject.state.atRisk, isTrue);
      await subject.close();
    });

    test('what was kept from another day starts it at no minutes', () async {
      homes
        ..kept = _home(HomeMockScenario.goalReached)
        ..failure = const NetworkFailure();
      now = DateTime(2026, 11, 7, 10);
      final subject = cubit();
      await subject.start();
      expect(subject.state.home!.todayMinutes, 0);
      expect(subject.state.status.kind, HomeStatusKind.minutesLeft);
    });

    test('greeting, status and risk follow the clock', () async {
      homes.home = _home(HomeMockScenario.atRisk);
      now = DateTime(2026, 11, 5, 19, 30);
      final subject = cubit();
      await subject.start();
      expect(subject.state.greeting, HomeGreeting.evening);
      expect(subject.state.status, (
        kind: HomeStatusKind.minutesLeft,
        minutesLeft: 5,
      ));
      expect(subject.state.atRisk, isTrue);
    });
  });

  group('notices', () {
    test('a one-time notice closes for good', () async {
      homes.home = _home(HomeMockScenario.freezeUsed);
      final subject = cubit();
      await subject.start();
      final event = subject.state.notices(emailReminder: false).event!;
      expect(
        subject.state.notices(emailReminder: false).card,
        HomeCardNotice.freeze,
      );

      await subject.closeEvent(event.id);

      expect(homes.seen, {event.id});
      expect(
        subject.state.notices(emailReminder: false).card,
        HomeCardNotice.none,
      );
      final later = cubit();
      await later.start();
      expect(later.state.seenEvents, {event.id});
    });

    test('a connection strip even before data', () {
      final subject = cubit();
      expect(
        subject.state.copyWith(online: false).notices(emailReminder: true).top,
        HomeTopNotice.offline,
      );
    });
  });

  group('tracks and levels', () {
    test('another track: switched, then its home', () async {
      final subject = cubit();
      await subject.start();
      subject.openingPlayed();
      final emar = profiles.profile.tracks.last;
      homes.home = mockHome(emar: true, now: _morning);

      expect(await subject.switchTrack(emar), isNull);

      expect(profiles.switches, [emar.enrollmentId]);
      expect(subject.state.home?.enrollment.id, 'enr_emar');
      expect(subject.state.switches, 1);
      expect(subject.state.switchedTo, emar.title);
      expect(subject.state.switching, isFalse);
      expect(subject.state.openingDue, isFalse);
    });

    test('a switch that fails changes nothing', () async {
      final subject = cubit();
      await subject.start();
      profiles.writeFailure = const NetworkFailure();
      final emar = profiles.profile.tracks.last;
      expect(await subject.switchTrack(emar), const NetworkFailure());
      expect(subject.state.switching, isFalse);
      expect(subject.state.switches, 0);
      expect(subject.state.home?.enrollment.id, 'enr_general');
    });

    test('«ابدأ B1» starts the next level, then refreshes', () async {
      homes.home = _home(HomeMockScenario.levelComplete);
      final subject = cubit();
      await subject.start();
      expect(await subject.startNextLevel(), isNull);
      expect(profiles.levels, [('enr_general', 'lvl_gen_b1')]);
      expect(homes.fetches, 2);
    });
  });

  test(
    'kids: the unit says its name; a greeting not recorded says nothing',
    () async {
      final player = FakeClipPlayer();
      homes.home = mockHome(kids: true, now: _morning);
      final subject = HomeCubit(
        homes,
        profiles,
        lessons,
        connectivity,
        sounds,
        player: player,
        now: () => now,
      );
      await subject.refresh();

      await subject.sayGreeting();
      expect(player.loaded, isEmpty);

      await subject.sayUnit();
      expect(player.loaded, ['https://example.com/mock/kids/unit_3.mp3']);
      expect(player.played, 1);

      await subject.close();
      expect(player.stopped, 1);
    },
  );

  test('cheers are sounds', () async {
    final subject = cubit()
      ..cheer(HomeCheer.goal)
      ..cheer(HomeCheer.level);
    await pumpEventQueue();
    expect(sounds.played, [AppSound.goalReached, AppSound.achievement]);
    expect(subject.state.load, LoadStatus.loading);
  });
}
