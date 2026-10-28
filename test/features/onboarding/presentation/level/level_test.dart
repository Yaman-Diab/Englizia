import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/english_level_choice.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/level/cubit/level_cubit.dart';
import 'package:englizia/features/onboarding/presentation/level/pages/level_page.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_placement_repository.dart';
import '../../../../helpers/fake_track_repository.dart';
import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

const _summary = testPlacementSummary;

const _firstLevel = TrackLevel(
  id: 'lvl_prea1',
  order: 1,
  name: LocalizedText(ar: 'Pre-A1 · البداية', en: 'Pre-A1 · Starter'),
);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeConnectivityService connectivity;

  setUp(() => connectivity = FakeConnectivityService());
  tearDown(() => connectivity.dispose());

  LevelCubit buildCubit({
    List<Result<PlacementSummary>> summaries = const [Ok(_summary)],
    FakeTrackRepository? tracks,
  }) => LevelCubit(
    FakePlacementRepository(summaries),
    tracks ??
        FakeTrackRepository(
          levels: const [
            Ok([_firstLevel]),
          ],
        ),
    connectivity,
  );

  group('LevelCubit', () {
    test('loads the test summary and the track\'s first level', () async {
      final tracks = FakeTrackRepository(
        levels: const [
          Ok([_firstLevel]),
        ],
      );
      final cubit = buildCubit(tracks: tracks);
      addTearDown(cubit.close);

      await cubit.start('trk_general');

      expect(tracks.levelRequests, ['trk_general']);
      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.summary, _summary);
      expect(cubit.state.firstLevel, _firstLevel);
    });

    test('a path without a track loads only the summary', () async {
      final tracks = FakeTrackRepository();
      final cubit = buildCubit(tracks: tracks);
      addTearDown(cubit.close);

      await cubit.start(null);

      expect(tracks.levelRequests, isEmpty);
      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.firstLevel, isNull);
    });

    test('the test needs the "some" answer and a connection', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.start('trk_general');

      cubit.choose(EnglishLevelChoice.beginner);
      expect(cubit.state.canTakeTest, isFalse);

      cubit.choose(EnglishLevelChoice.some);
      expect(cubit.state.canTakeTest, isTrue);

      connectivity.online = false;
      await pumpEventQueue();
      expect(cubit.state.online, isFalse);
      expect(cubit.state.canTakeTest, isFalse);

      connectivity.online = true;
      await pumpEventQueue();
      expect(cubit.state.canTakeTest, isTrue);
    });

    test('starts offline when the phone is offline', () async {
      connectivity.online = false;
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.start('trk_general');

      expect(cubit.state.online, isFalse);
    });

    test('a failed load can be retried', () async {
      final cubit = buildCubit(
        summaries: const [Err(NetworkFailure()), Ok(_summary)],
      );
      addTearDown(cubit.close);

      await cubit.start('trk_general');
      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.failure, isA<NetworkFailure>());

      await cubit.load();
      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.failure, isNull);
    });

    test('no published test hides it but keeps the first level', () async {
      final cubit = buildCubit(summaries: const [Err(NotFoundFailure())]);
      addTearDown(cubit.close);

      await cubit.start('trk_general');
      cubit.choose(EnglishLevelChoice.some);

      expect(cubit.state.testUnavailable, isTrue);
      expect(cubit.state.canTakeTest, isFalse);
      expect(cubit.state.firstLevel, _firstLevel);
    });
  });

  group('LevelPage', () {
    Future<LevelCubit> pumpPage(
      WidgetTester tester, {
      List<Result<PlacementSummary>> summaries = const [Ok(_summary)],
      ValueChanged<TrackLevel?>? onStartFromBeginning,
      VoidCallback? onTakeTest,
      ValueChanged<TrackLevel?>? onTestLater,
      LayoutCase? layout,
    }) async {
      final cubit = buildCubit(summaries: summaries);
      addTearDown(cubit.close);
      unawaited(cubit.start('trk_general'));
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: LevelPage(
            path: OnboardingPath.assumed,
            onStartFromBeginning: onStartFromBeginning ?? (_) {},
            onTakeTest: onTakeTest ?? () {},
            onTestLater: onTestLater ?? (_) {},
            onBack: () {},
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.settleEntrance(QuestionEntrance.settled);
      return cubit;
    }

    /// One frame starts the swap and resize animations, the next ends them.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.medium * 2);
    }

    FilledButton continueButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testLayouts('lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(tester, layout: layout);
      cubit.choose(EnglishLevelChoice.beginner);
      await settle(tester);
      expect(tester.takeException(), isNull);

      connectivity.online = false;
      cubit.choose(EnglishLevelChoice.some);
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the guide asks, then replies to the answer', (tester) async {
      final cubit = await pumpPage(tester);
      expect(find.text('onboarding_level_question'.tr()), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(find.text('onboarding_level_beginner'.tr()));
      await settle(tester);
      expect(find.text('onboarding_level_beginner_reply'.tr()), findsOneWidget);

      cubit.choose(EnglishLevelChoice.some);
      await settle(tester);
      expect(find.text('onboarding_level_some_reply'.tr()), findsOneWidget);
    });

    testWidgets('a beginner sees where they start and starts there', (
      tester,
    ) async {
      var started = false;
      await pumpPage(
        tester,
        onStartFromBeginning: (level) => started = level == _firstLevel,
      );

      await tester.tap(find.text('onboarding_level_beginner'.tr()));
      await settle(tester);

      expect(find.text('ستبدأ من Pre-A1 · البداية'), findsOneWidget);
      expect(find.text('onboarding_level_test_later'.tr()), findsNothing);
      await tester.tap(find.text('onboarding_level_beginner_cta'.tr()));
      expect(started, isTrue);
    });

    testWidgets('"some" shows what the test takes, from the server', (
      tester,
    ) async {
      var tested = false;
      var later = false;
      await pumpPage(
        tester,
        onTakeTest: () => tested = true,
        onTestLater: (level) => later = level == _firstLevel,
      );

      await tester.tap(find.text('onboarding_level_some'.tr()));
      await settle(tester);

      expect(
        find.text('${Unicode.LRI}12–15${Unicode.PDI} دقيقة'),
        findsOneWidget,
      );
      expect(find.text('مرحلتان، وقد تُضاف مرحلة ثالثة قصيرة'), findsOneWidget);
      expect(find.text('onboarding_level_dont_know'.tr()), findsOneWidget);
      expect(
        find.text('ستبدأ من Pre-A1 · البداية، والاختبار متاح من ملفك الشخصي'),
        findsOneWidget,
      );

      await tester.tap(find.text('onboarding_level_take_test'.tr()));
      await tester.tap(find.text('onboarding_level_test_later'.tr()));
      expect((tested, later), (true, true));
    });

    testWidgets('offline, the test waits for the connection; later does not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var later = false;
      final cubit = await pumpPage(tester, onTestLater: (_) => later = true);
      cubit.choose(EnglishLevelChoice.some);
      connectivity.online = false;
      await settle(tester);

      expect(find.text('onboarding_level_offline'.tr()), findsOneWidget);
      expect(
        tester.getSemantics(find.text('onboarding_level_offline'.tr())),
        isSemantics(isLiveRegion: true),
      );
      expect(continueButton(tester).onPressed, isNull);
      await tester.tap(find.text('onboarding_level_test_later'.tr()));
      expect(later, isTrue);

      connectivity.online = true;
      await settle(tester);
      expect(find.text('onboarding_level_offline'.tr()), findsNothing);
      expect(continueButton(tester).onPressed, isNotNull);
      handle.dispose();
    });

    testWidgets('with no published test, it says so and stays disabled', (
      tester,
    ) async {
      final cubit = await pumpPage(
        tester,
        summaries: const [Err(NotFoundFailure())],
      );
      cubit.choose(EnglishLevelChoice.some);
      await settle(tester);

      expect(
        find.text('onboarding_level_test_unavailable'.tr()),
        findsOneWidget,
      );
      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('a failed summary offers a retry', (tester) async {
      final cubit = await pumpPage(
        tester,
        summaries: const [Err(NetworkFailure()), Ok(_summary)],
      );
      cubit.choose(EnglishLevelChoice.some);
      await settle(tester);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(find.text('onboarding_level_dont_know'.tr()), findsOneWidget);
    });

    testWidgets('the progress counts the path the learner is on', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      expect(find.bySemanticsLabel('الخطوة 6 من 8'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the answers are a radio group with good tap targets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final cubit = await pumpPage(tester);
      cubit.choose(EnglishLevelChoice.some);
      await settle(tester);

      expect(
        tester.getSemantics(find.text('onboarding_level_some'.tr())),
        isSemantics(
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
