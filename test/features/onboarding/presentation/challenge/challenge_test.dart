import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/challenge/cubit/challenge_cubit.dart';
import 'package:englizia/features/onboarding/presentation/challenge/pages/challenge_page.dart';
import 'package:englizia/features/onboarding/presentation/challenge/widgets/streak_calendar.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_settings_repository.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  ChallengeCubit buildCubit([
    List<Result<EffectiveSettings>> results = const [Ok(testSettings)],
  ]) => ChallengeCubit(FakeSettingsRepository(results));

  group('ChallengeCubit', () {
    test('preselects the configured default', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.selected, 7);
      expect(cubit.state.canContinue, isTrue);
    });

    test('coming back keeps the earlier choice while it is on offer', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.load(chosen: 30);
      expect(cubit.state.selected, 30);

      await cubit.load(chosen: 21);
      expect(cubit.state.selected, 7);
    });

    test('a failed load can be retried', () async {
      final cubit = buildCubit(const [Err(NetworkFailure()), Ok(testSettings)]);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, LoadStatus.failure);

      await cubit.load();
      expect(cubit.state.selected, 7);
    });
  });

  group('ChallengePage', () {
    Future<ChallengeCubit> pumpPage(
      WidgetTester tester, {
      List<Result<EffectiveSettings>> results = const [Ok(testSettings)],
      ValueChanged<int>? onContinue,
      LayoutCase? layout,
      Size? size,
    }) async {
      final cubit = buildCubit(results);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: ChallengePage(
            path: OnboardingPath.assumed,
            onContinue: onContinue ?? (_) {},
            onBack: () {},
          ),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: size ?? layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      await tester.settleEntrance(QuestionEntrance.settled);
      return cubit;
    }

    /// One frame starts the swap and resize animations, the next ends them.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.slow * 2);
    }

    testLayouts('lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(tester, layout: layout);
      for (final days in [14, 30, 40, 7]) {
        cubit.select(days);
        await settle(tester);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the guide asks the panel\'s question; 7 days preselected', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(
        find.text('من يحدد هدفًا يستمر أكثر. كم يومًا تتحدى نفسك؟'),
        findsOneWidget,
      );
      expect(find.text('7 أيام'), findsOneWidget);
      expect(find.text('14 يومًا'), findsOneWidget);
      expect(find.text('مثالي'), findsOneWidget);
      expect(find.text('onboarding_challenge_helper'.tr()), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('the calendar follows the choice', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('30 يومًا'));
      await settle(tester);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });

    testWidgets('confirming sends the chosen days', (tester) async {
      int? sent;
      await pumpPage(tester, onContinue: (days) => sent = days);

      await tester.tap(find.text('40 يومًا'));
      await settle(tester);
      await tester.tap(find.text('onboarding_challenge_cta'.tr()));
      expect(sent, 40);
    });

    testWidgets('on a short screen the calendar shrinks, then steps aside', (
      tester,
    ) async {
      await pumpPage(tester, size: const Size(360, 640));
      final shrunk = tester.getSize(find.byType(StreakCalendar)).height;
      expect(shrunk, lessThanOrEqualTo(640 * .25));
      expect(tester.takeException(), isNull);

      // Too short to read: the calendar steps aside.
      await tester.pumpLocalized(
        const StreakCalendar(days: 7),
        size: const Size(360, 220),
      );
      expect(find.text('7'), findsNothing);
    });

    testWidgets('while loading, the app asks in its own words', (tester) async {
      await pumpPage(tester, results: const [Err(NetworkFailure())]);
      expect(find.text('onboarding_challenge_question'.tr()), findsOneWidget);
      expect(find.text('common_retry'.tr()), findsOneWidget);
    });

    testWidgets('English reads naturally', (tester) async {
      await pumpPage(
        tester,
        layout: (
          locale: const Locale('en'),
          size: defaultViewport,
          themeMode: ThemeMode.light,
        ),
      );
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Confirm goal'), findsOneWidget);
    });

    testWidgets('the progress counts the path the learner is on', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      expect(find.bySemanticsLabel('الخطوة 5 من 8'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the lengths are a radio group; the calendar is decorative', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);

      expect(
        tester.getSemantics(find.text('7 أيام')),
        isSemantics(
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('7'), findsNothing);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
