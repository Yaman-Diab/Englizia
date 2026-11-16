import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/reminder/cubit/reminder_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reminder/pages/reminder_page.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_settings_repository.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  ReminderCubit buildCubit({
    List<Result<EffectiveSettings>> results = const [Ok(testSettings)],
  }) => ReminderCubit(FakeSettingsRepository(results));

  group('ReminderCubit', () {
    test('preselects the configured default time', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.slot, ReminderSlot.evening);
      expect(cubit.state.time, const ReminderTime(20, 0));
    });

    test('a custom time is kept when a preset is chosen again', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      cubit.setCustom(const ReminderTime(21, 30));
      expect(cubit.state.time, const ReminderTime(21, 30));

      cubit.choose(ReminderSlot.morning);
      expect(cubit.state.time, const ReminderTime(8, 0));
      expect(cubit.state.custom, const ReminderTime(21, 30));
    });

    test('nothing can be chosen before the times arrive', () async {
      final cubit = buildCubit(results: const [Err(NetworkFailure())]);
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.canEnable, isFalse);
    });
  });

  group('ReminderPage', () {
    Future<ReminderCubit> pumpPage(
      WidgetTester tester, {
      List<Result<EffectiveSettings>> results = const [Ok(testSettings)],
      ValueChanged<ReminderTime?>? onContinue,
      OnboardingPath path = OnboardingPath.assumed,
      LayoutCase? layout,
    }) async {
      final cubit = buildCubit(results: results);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: ReminderPage(
            path: path,
            onContinue: onContinue ?? (_) {},
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
      await tester.pump(AppMotion.slow * 2);
    }

    FilledButton continueButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton).last);

    testLayouts('lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(tester, layout: layout);
      expect(tester.takeException(), isNull);

      cubit.setCustom(const ReminderTime(21, 45));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the preview shows the chosen time and the panel\'s text', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('onboarding_reminder_question'.tr()), findsOneWidget);
      expect(find.text('إنجليزيا • 8:00 م'), findsOneWidget);
      expect(find.text('حان وقت درسك اليومي'), findsOneWidget);
      expect(
        find.text('10 دقائق فقط وتحافظ على أيامك المتتالية'),
        findsOneWidget,
      );

      await tester.tap(find.text('onboarding_reminder_morning'.tr()));
      await settle(tester);
      expect(find.text('إنجليزيا • 8:00 ص'), findsOneWidget);
    });

    testWidgets('the preview speaks of the goal the learner chose', (
      tester,
    ) async {
      await pumpPage(
        tester,
        path: OnboardingPath.assumed.copyWith(dailyGoalMinutes: 20),
      );
      expect(
        find.text('20 دقائق فقط وتحافظ على أيامك المتتالية'),
        findsOneWidget,
      );
    });

    testWidgets('"another time" opens the picker and keeps what is saved', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(find.text('onboarding_reminder_other'.tr()));
      await settle(tester);
      expect(find.text('onboarding_reminder_sheet_title'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);

      // From the selected 8:00 PM: two hours on, then the morning.
      await tester.drag(
        find.byType(ListWheelScrollView).first,
        const Offset(0, -88),
      );
      await settle(tester);
      await tester.tap(find.text('ص').last);
      await tester.pump();
      await tester.tap(find.text('common_save'.tr()));
      await settle(tester);

      expect(find.text('onboarding_reminder_sheet_title'.tr()), findsNothing);
      expect(find.text('إنجليزيا • 10:00 ص'), findsOneWidget);
      expect(find.text('10:00 ص'), findsOneWidget);
    });

    testWidgets('«فعّل التذكير» goes on with the time, asking the phone '
        'nothing yet', (tester) async {
      final sent = <ReminderTime?>[];
      await pumpPage(tester, onContinue: sent.add);

      await tester.tap(find.text('onboarding_reminder_enable'.tr()));
      await settle(tester);
      expect(sent, [const ReminderTime(20, 0)]);
    });

    testWidgets('"no reminder" goes on without a time', (tester) async {
      final sent = <ReminderTime?>[];
      await pumpPage(tester, onContinue: sent.add);

      await tester.tap(find.text('onboarding_reminder_skip'.tr()));
      expect(sent, [null]);
    });

    testWidgets('times that fail to load offer a retry; skipping still works', (
      tester,
    ) async {
      final sent = <ReminderTime?>[];
      await pumpPage(
        tester,
        results: const [Err(NetworkFailure()), Ok(testSettings)],
        onContinue: sent.add,
      );
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(find.text('onboarding_reminder_skip'.tr()));
      expect(sent, [null]);

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(find.text('onboarding_reminder_evening'.tr()), findsOneWidget);
      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('the progress counts the path the learner is on', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      expect(find.bySemanticsLabel('الخطوة 7 من 8'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the times are a radio group with good tap targets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);

      expect(
        tester.getSemantics(find.text('onboarding_reminder_evening'.tr())),
        isSemantics(
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('onboarding_reminder_preview'.tr())),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the picker wheels are adjustable for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      await tester.tap(find.text('onboarding_reminder_other'.tr()));
      await settle(tester);

      expect(
        find.bySemanticsLabel('onboarding_reminder_hour'.tr()),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('onboarding_reminder_hour'.tr()),
        ),
        isSemantics(
          value: '8',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
