import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/notice_card.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/presentation/intro/cubit/placement_intro_cubit.dart';
import 'package:englizia/features/placement/presentation/intro/pages/placement_intro_page.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_placement_repository.dart';
import '../../../helpers/fake_track_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  const inProgress = PlacementInProgress(stage: 1, question: 9);
  const retake = PlacementRetakeOpen(level: 'A2', daysAgo: 34);
  const locked = PlacementRetakeLocked(daysLeft: 12);

  late FakeConnectivityService connectivity;
  late FakeSoundPlayer sounds;

  setUp(() {
    connectivity = FakeConnectivityService();
    sounds = FakeSoundPlayer();
  });

  PlacementIntroCubit cubitWith({
    List<Result<PlacementStatus>> statuses = const [Ok(PlacementNotTaken())],
    FakePlacementRepository? placement,
    List<Result<List<TrackLevel>>> levels = const [Ok(<TrackLevel>[])],
    Duration trialLength = const Duration(seconds: 1),
  }) {
    final cubit = PlacementIntroCubit(
      placement ??
          FakePlacementRepository(const [Ok(testPlacementSummary)], statuses),
      FakeTrackRepository(levels: levels),
      connectivity,
      sounds,
      trialLength: trialLength,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('PlacementIntroCubit', () {
    test('a first test can start', () async {
      final cubit = cubitWith();
      await cubit.start('trk');
      expect(cubit.state.load, LoadStatus.ready);
      expect(cubit.state.status, const PlacementNotTaken());
      expect(cubit.state.canStart, isTrue);
    });

    test('a locked retake can\'t, one open can', () async {
      final closed = cubitWith(statuses: const [Ok(locked)]);
      await closed.start(null);
      expect(closed.state.canStart, isFalse);

      final open = cubitWith(statuses: const [Ok(retake)]);
      await open.start(null);
      expect(open.state.canStart, isTrue);
    });

    test('offline still shows the screen, and loads when back', () async {
      connectivity.online = false;
      final cubit = cubitWith(
        placement: FakePlacementRepository(
          const [Err(NetworkFailure()), Ok(testPlacementSummary)],
          const [Err(NetworkFailure()), Ok(inProgress)],
        ),
      );
      await cubit.start(null);
      expect(cubit.state.load, LoadStatus.ready);
      expect(cubit.state.canStart, isFalse);
      expect(cubit.state.summary, isNull);

      connectivity.online = true;
      await pumpEventQueue();
      expect(cubit.state.summary, testPlacementSummary);
      expect(cubit.state.status, inProgress);
      expect(cubit.state.canStart, isTrue);
    });

    test(
      'losing the connection takes the button away and nothing else',
      () async {
        final placement = FakePlacementRepository();
        final cubit = cubitWith(placement: placement);
        await cubit.start(null);

        connectivity.online = false;
        await pumpEventQueue();
        expect(cubit.state.canStart, isFalse);
        expect(cubit.state.summary, testPlacementSummary);

        connectivity.online = true;
        await pumpEventQueue();
        expect(cubit.state.canStart, isTrue);
        expect(placement.calls, 1);
      },
    );

    test('a server failure leaves a retry', () async {
      final cubit = cubitWith(
        placement: FakePlacementRepository(const [
          Err(ServerFailure()),
          Ok(testPlacementSummary),
        ]),
      );
      await cubit.start(null);
      expect(cubit.state.load, LoadStatus.failure);

      await cubit.load();
      expect(cubit.state.load, LoadStatus.ready);
      expect(cubit.state.failure, isNull);
    });

    test('no published test: the screen stays, the button does not', () async {
      final cubit = cubitWith(
        placement: FakePlacementRepository(const [Err(NotFoundFailure())]),
      );
      await cubit.start(null);
      expect(cubit.state.load, LoadStatus.ready);
      expect(cubit.state.testUnavailable, isTrue);
      expect(cubit.state.canStart, isFalse);
    });

    test('knows the first level, and goes on without it', () async {
      final known = cubitWith(
        levels: [
          Ok([fakeGrade(1)]),
        ],
      );
      await known.start('trk');
      expect(known.state.firstLevel, fakeGrade(1));

      final unknown = cubitWith(levels: const [Err(NetworkFailure())]);
      await unknown.start('trk');
      expect(unknown.state.load, LoadStatus.ready);
      expect(unknown.state.firstLevel, isNull);
    });

    test('the sound check plays, ends by itself, and can be stopped', () async {
      final cubit = cubitWith(trialLength: const Duration(milliseconds: 1));
      await cubit.start(null);

      cubit.toggleTrial();
      expect(cubit.state.trying, isTrue);
      expect(sounds.played, [AppSound.placementTrial]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.trying, isFalse);

      final stopped = cubitWith(trialLength: const Duration(minutes: 1));
      await stopped.start(null);
      stopped.toggleTrial();
      stopped.toggleTrial();
      expect(stopped.state.trying, isFalse);
    });
  });

  group('PlacementIntroPage', () {
    late int starts;
    late int skips;
    late int lessons;
    late int backs;

    setUp(() {
      starts = 0;
      skips = 0;
      lessons = 0;
      backs = 0;
    });

    Future<PlacementIntroCubit> pumpPage(
      WidgetTester tester, {
      PlacementStatus status = const PlacementNotTaken(),
      bool online = true,
      List<Result<List<TrackLevel>>> levels = const [Ok(<TrackLevel>[])],
      LayoutCase? layout,
      Size? size,
    }) async {
      connectivity.online = online;
      final cubit = cubitWith(
        placement: FakePlacementRepository(
          online
              ? const [Ok(testPlacementSummary)]
              : const [Err(NetworkFailure())],
          online ? [Ok(status)] : const [Err(NetworkFailure())],
        ),
        levels: levels,
      );
      await cubit.start('trk');
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementIntroPage(
            onBack: () => backs++,
            onStart: () async => starts++,
            onSkip: () => skips++,
            onLessons: () => lessons++,
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: size ?? layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.settleEntrance(
        FormEntrance.action + const Duration(seconds: 1),
      );
      return cubit;
    }

    AppButton button(WidgetTester tester) =>
        tester.widget<AppButton>(find.byType(AppButton).last);

    TextButton other(WidgetTester tester) =>
        tester.widget<TextButton>(find.byType(TextButton).last);

    for (final (name, status) in const <(String, PlacementStatus)>[
      ('a first test', PlacementNotTaken()),
      ('an unfinished test', inProgress),
      ('an open retake', retake),
      ('a locked retake', locked),
    ]) {
      testLayouts('$name lays out without overflow', (tester, layout) async {
        await pumpPage(tester, status: status, layout: layout);
        expect(tester.takeException(), isNull);
      });
    }

    testLayouts('offline lays out without overflow', (tester, layout) async {
      await pumpPage(tester, online: false, layout: layout);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a first test: the facts, the guide, and both ways', (
      tester,
    ) async {
      await pumpPage(
        tester,
        levels: [
          Ok([fakeGrade(1)]),
        ],
      );
      final guide = tester.widget<Mascot>(find.byType(Mascot));
      expect(guide.expression, MascotExpression.listen);
      expect(guide.prop, MascotProp.headphones);
      expect(find.text('placement_intro_title'.tr()), findsOneWidget);
      expect(
        find.text(
          'placement_minutes'.plural(15, namedArgs: {'min': '12', 'max': '15'}),
        ),
        findsOneWidget,
      );
      expect(find.text('placement_dont_guess'.tr()), findsOneWidget);
      expect(find.text('placement_can_pause'.tr()), findsOneWidget);
      expect(find.byType(NoticeCard), findsNothing);

      await tester.tap(find.text('preparing_start_test'.tr()));
      expect(starts, 1);
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      expect(skips, 1);
    });

    testWidgets('an unfinished test: continue, or start over', (tester) async {
      await pumpPage(tester, status: inProgress);
      expect(
        find.text(
          'placement_unfinished_stage_1'.tr(namedArgs: {'question': '9'}),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('placement_continue'.tr()));
      expect(starts, 1);
      await tester.tap(find.text('placement_restart'.tr()));
      await tester.pump();
      await tester.pump();
      expect(starts, 2);
    });

    testWidgets('an open retake: the result, and back to the lessons', (
      tester,
    ) async {
      await pumpPage(tester, status: retake);
      expect(find.text('placement_intro_subtitle_again'.tr()), findsOneWidget);
      final line = tester.widget<Text>(
        find.descendant(
          of: find.byType(NoticeCard),
          matching: find.byType(Text),
        ),
      );
      final title = line.textSpan! as TextSpan;
      final level = title.children![1] as TextSpan;
      expect(level.text, contains('A2'));
      expect(level.style, isNot(title.style));
      await tester.tap(find.text('placement_retake'.tr()));
      expect(starts, 1);
      await tester.tap(find.text('placement_back_to_lessons'.tr()));
      expect(lessons, 1);
    });

    testWidgets('a locked retake says when, and the button waits', (
      tester,
    ) async {
      await pumpPage(tester, status: locked);
      expect(find.text('placement_retake_after'.plural(12)), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      expect(other(tester).onPressed, isNotNull);
    });

    testWidgets('offline: says why, and comes back by itself', (tester) async {
      final cubit = await pumpPage(tester, online: false);
      expect(find.text('placement_offline'.tr()), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      // The sound check needs no connection.
      await tester.tap(find.byTooltip('placement_sound_play'.tr()));
      await tester.pump();
      expect(cubit.state.trying, isTrue);
      cubit.toggleTrial();

      connectivity.online = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('placement_offline'.tr()), findsNothing);
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('the sound check changes its button and its text', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('placement_sound_try'.tr()), findsOneWidget);

      await tester.tap(find.byTooltip('placement_sound_play'.tr()));
      await tester.pump();
      expect(find.text('placement_sound_hear'.tr()), findsOneWidget);
      expect(find.byTooltip('placement_sound_stop'.tr()), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('placement_sound_try'.tr()), findsOneWidget);
    });

    testWidgets('a line over the buttons only while content is under them', (
      tester,
    ) async {
      await pumpPage(tester, status: retake, size: const Size(320, 560));
      Color line() {
        final box = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer).last,
        );
        final decoration = box.decoration! as BoxDecoration;
        return (decoration.border! as Border).top.color;
      }

      expect(line(), isNot(Colors.transparent));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1000),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(line(), Colors.transparent);
    });

    testWidgets('back goes back', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byTooltip('common_back'.tr()));
      expect(backs, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(backs, 2);
    });

    testWidgets('offline with a saved status: that state, button disabled', (
      tester,
    ) async {
      connectivity.online = false;
      final cubit = cubitWith(
        placement: FakePlacementRepository(
          const [Err(NetworkFailure())],
          const [Ok(retake)],
        ),
      );
      await cubit.start('trk');
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementIntroPage(
            onBack: () {},
            onStart: () async {},
            onSkip: () {},
            onLessons: () => lessons++,
          ),
        ),
      );
      await tester.settleEntrance(const Duration(seconds: 2));

      expect(find.text('placement_offline'.tr()), findsOneWidget);
      expect(find.textContaining('A2', findRichText: true), findsOneWidget);
      expect(find.text('placement_retake'.tr()), findsOneWidget);
      expect(find.text('preparing_start_test'.tr()), findsNothing);
      expect(button(tester).onPressed, isNull);
      await tester.tap(find.text('placement_back_to_lessons'.tr()));
      expect(lessons, 1);
    });

    testWidgets('offline with an unfinished test saved: no starting over', (
      tester,
    ) async {
      connectivity.online = false;
      final cubit = cubitWith(
        placement: FakePlacementRepository(
          const [Err(NetworkFailure())],
          const [Ok(inProgress)],
        ),
      );
      await cubit.start(null);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementIntroPage(
            onBack: () {},
            onStart: () async {},
            onSkip: () {},
            onLessons: () {},
          ),
        ),
      );
      await tester.settleEntrance(const Duration(seconds: 2));
      expect(find.text('placement_continue'.tr()), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      expect(other(tester).onPressed, isNull);
    });

    testWidgets('offline knowing nothing: promises no first test', (
      tester,
    ) async {
      await pumpPage(tester, online: false);
      expect(find.byType(TextButton), findsNothing);
      expect(button(tester).onPressed, isNull);
      expect(find.text('placement_offline'.tr()), findsOneWidget);
    });

    testWidgets('a new account offline is on its first test', (tester) async {
      connectivity.online = false;
      final placement = FakePlacementRepository(
        const [Err(NetworkFailure())],
        const [Err(NetworkFailure())],
      );
      final cubit = cubitWith(placement: placement);
      await cubit.start('trk', newAccount: true);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementIntroPage(
            onBack: () {},
            onStart: () async {},
            onSkip: () {},
            onLessons: () {},
          ),
        ),
      );
      await tester.settleEntrance(const Duration(seconds: 2));
      expect(find.text('placement_skip_plain'.tr()), findsOneWidget);
    });

    testWidgets('skipping tells the server, then moves on', (tester) async {
      final placement = FakePlacementRepository();
      final cubit = cubitWith(placement: placement);
      await cubit.start('trk');
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementIntroPage(
            onBack: () {},
            onStart: () async {},
            onSkip: () => skips++,
            onLessons: () {},
          ),
        ),
      );
      await tester.settleEntrance(const Duration(seconds: 2));
      await tester.tap(find.text('placement_skip_plain'.tr()));
      await tester.pump();
      await tester.pump();
      expect(placement.defers, 1);
      expect(skips, 1);
    });

    testWidgets('a failed skip stays, says so and retries', (tester) async {
      final placement = FakePlacementRepository(
        const [Ok(testPlacementSummary)],
        const [Ok(PlacementNotTaken())],
        const [Err(NetworkFailure()), Ok(null)],
      );
      final cubit = cubitWith(placement: placement);
      await cubit.start('trk');
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementIntroPage(
            onBack: () {},
            onStart: () async {},
            onSkip: () => skips++,
            onLessons: () {},
          ),
        ),
      );
      await tester.settleEntrance(const Duration(seconds: 2));
      await tester.tap(find.text('placement_skip_plain'.tr()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(skips, 0);
      expect(find.text('error_network'.tr()), findsOneWidget);

      await tester.tap(find.text('common_retry'.tr()));
      await tester.pump();
      await tester.pump();
      expect(placement.defers, 2);
      expect(skips, 1);
    });

    testWidgets('starting over asks the server first, and reloads on return', (
      tester,
    ) async {
      final placement = FakePlacementRepository(
        const [Ok(testPlacementSummary)],
        const [Ok(inProgress), Ok(PlacementInProgress(stage: 1, question: 1))],
      );
      final cubit = cubitWith(placement: placement);
      await cubit.start(null);
      var opened = 0;
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementIntroPage(
            onBack: () {},
            onStart: () async => opened++,
            onSkip: () {},
            onLessons: () {},
          ),
        ),
      );
      await tester.settleEntrance(const Duration(seconds: 2));
      await tester.tap(find.text('placement_restart'.tr()));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(placement.restarts, 1);
      expect(opened, 1);
      expect(placement.statusCalls, 2);
      expect(cubit.state.done, isNull);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a server failure offers a retry', (tester) async {
      final cubit = cubitWith(
        placement: FakePlacementRepository(const [
          Err(ServerFailure()),
          Ok(testPlacementSummary),
        ]),
      );
      await cubit.start(null);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: PlacementIntroPage(
            onBack: () {},
            onStart: () async {},
            onSkip: () {},
            onLessons: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('common_retry'.tr()));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('placement_intro_title'.tr()), findsOneWidget);
    });

    testWidgets('buttons meet the tap target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
