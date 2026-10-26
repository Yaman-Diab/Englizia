import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/goal/cubit/goal_cubit.dart';
import 'package:englizia/features/onboarding/presentation/goal/pages/goal_page.dart';
import 'package:englizia/features/onboarding/presentation/goal/widgets/goal_preview.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_settings_repository.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  GoalCubit buildCubit([
    List<Result<EffectiveSettings>> results = const [Ok(testSettings)],
  ]) => GoalCubit(FakeSettingsRepository(results));

  group('GoalCubit', () {
    test('preselects the configured default', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.selected, 10);
      expect(cubit.state.selectedIndex, 1);
      expect(cubit.state.canContinue, isTrue);
    });

    test('coming back keeps the earlier choice while it is on offer', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.load(chosen: 20);
      expect(cubit.state.selected, 20);

      await cubit.load(chosen: 12);
      expect(cubit.state.selected, 10);
    });

    test('a choice is kept across a reload', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();

      cubit.select(15);
      await cubit.load();
      expect(cubit.state.selected, 15);
    });

    test('a failed load can be retried', () async {
      final cubit = buildCubit(const [Err(NetworkFailure()), Ok(testSettings)]);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.canContinue, isFalse);

      await cubit.load();
      expect(cubit.state.status, LoadStatus.ready);
      expect(cubit.state.failure, isNull);
    });
  });

  group('GoalPreview lines', () {
    // 10-minute lessons, as in the contract's example.
    Future<String?> line(
      WidgetTester tester,
      int minutes, {
      int? lesson,
    }) async {
      await tester.pumpLocalized(const SizedBox());
      return GoalPreview.lessonsLine(minutes, lesson ?? 10);
    }

    testWidgets('goals read in half lessons, as the designs do', (
      tester,
    ) async {
      expect(await line(tester, 5), '≈ نصف درس يوميًا');
      expect(await line(tester, 10), '≈ درس واحد يوميًا');
      expect(await line(tester, 15), '≈ درس ونصف يوميًا');
      expect(await line(tester, 20), '≈ درسان يوميًا');
      expect(await line(tester, 30), '≈ 3 دروس يوميًا');
      expect(await line(tester, 25), '≈ درسان ونصف يوميًا');
      expect(await line(tester, 55), '≈ 5 دروس ونصف يوميًا');
      expect(await line(tester, 120), '≈ 12 درسًا يوميًا');
    });

    testWidgets('a tiny goal is never less than half a lesson', (tester) async {
      expect(await line(tester, 1), '≈ نصف درس يوميًا');
    });

    testWidgets('without a lesson length there is no lessons line', (
      tester,
    ) async {
      await tester.pumpLocalized(const SizedBox());
      expect(GoalPreview.lessonsLine(10, null), isNull);
    });

    testWidgets('English words them too', (tester) async {
      await tester.pumpLocalized(const SizedBox(), locale: const Locale('en'));
      expect(GoalPreview.lessonsLine(5, 10), '≈ half a lesson a day');
      expect(GoalPreview.lessonsLine(10, 10), '≈ 1 lesson a day');
      expect(GoalPreview.lessonsLine(15, 10), '≈ 1½ lessons a day');
      expect(GoalPreview.lessonsLine(20, 10), '≈ 2 lessons a day');
    });
  });

  group('GoalPage', () {
    Future<GoalCubit> pumpPage(
      WidgetTester tester, {
      List<Result<EffectiveSettings>> results = const [Ok(testSettings)],
      ValueChanged<int>? onContinue,
      LayoutCase? layout,
    }) async {
      final cubit = buildCubit(results);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: GoalPage(
            path: OnboardingPath.assumed,
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

    MascotExpression guide(WidgetTester tester) =>
        tester.widget<Mascot>(find.byType(Mascot)).expression;

    testLayouts('lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(tester, layout: layout);
      for (final minutes in [5, 15, 20, 10]) {
        cubit.select(minutes);
        await settle(tester);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the standard goal is preselected, with its preview', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('onboarding_goal_question'.tr()), findsOneWidget);
      expect(find.text('10 دقائق / يوم'), findsOneWidget);
      expect(find.text('قياسي'), findsOneWidget);
      expect(find.text('≈ درس واحد يوميًا'), findsOneWidget);
      expect(find.text('70 دقيقة في الأسبوع'), findsOneWidget);
      expect(find.text('onboarding_goal_helper'.tr()), findsOneWidget);
    });

    testWidgets('the options read in Arabic plural forms', (tester) async {
      await pumpPage(tester);
      expect(find.text('5 دقائق / يوم'), findsOneWidget);
      expect(find.text('15 دقيقة / يوم'), findsOneWidget);
      expect(find.text('20 دقيقة / يوم'), findsOneWidget);
    });

    testWidgets('the preview and the guide follow the goal', (tester) async {
      await pumpPage(tester);
      expect(guide(tester), MascotExpression.confident);

      await tester.tap(find.text('5 دقائق / يوم'));
      await settle(tester);
      expect(find.text('≈ نصف درس يوميًا'), findsOneWidget);
      expect(find.text('35 دقيقة في الأسبوع'), findsOneWidget);
      expect(guide(tester), MascotExpression.calm);

      await tester.tap(find.text('15 دقيقة / يوم'));
      await settle(tester);
      expect(find.text('≈ درس ونصف يوميًا'), findsOneWidget);
      expect(find.text('105 دقائق في الأسبوع'), findsOneWidget);
      expect(guide(tester), MascotExpression.excited);

      await tester.tap(find.text('20 دقيقة / يوم'));
      await settle(tester);
      expect(find.text('≈ درسان يوميًا'), findsOneWidget);
      expect(find.text('140 دقيقة في الأسبوع'), findsOneWidget);
      expect(guide(tester), MascotExpression.ecstatic);
    });

    testWidgets('continuing sends the chosen goal', (tester) async {
      int? sent;
      await pumpPage(tester, onContinue: (minutes) => sent = minutes);

      await tester.tap(find.text('15 دقيقة / يوم'));
      await settle(tester);
      await tester.tap(find.text('onboarding_goal_cta'.tr()));
      expect(sent, 15);
    });

    testWidgets('without a lesson length only the weekly total shows', (
      tester,
    ) async {
      const settings = EffectiveSettings(
        reminder: ReminderSettings(
          presets: [
            ReminderPreset(
              slot: ReminderSlot.evening,
              time: ReminderTime(20, 0),
            ),
          ],
          defaultSlot: ReminderSlot.evening,
          title: _text,
          body: _text,
        ),
        dailyGoal: DailyGoalSettings(
          options: [DailyGoalOption(minutes: 10, label: _text)],
          defaultMinutes: 10,
        ),
      );
      await pumpPage(tester, results: const [Ok(settings)]);

      expect(find.text('70 دقيقة في الأسبوع'), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
    });

    testWidgets('goals that fail to load offer a retry', (tester) async {
      await pumpPage(
        tester,
        results: const [Err(NetworkFailure()), Ok(testSettings)],
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );

      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(find.text('10 دقائق / يوم'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNotNull,
      );
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
      expect(find.text('10 minutes / day'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('≈ 1 lesson a day'), findsOneWidget);
      expect(find.text('70 minutes a week'), findsOneWidget);
    });

    testWidgets('the progress counts the path the learner is on', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      expect(find.bySemanticsLabel('الخطوة 4 من 7'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the goals are a radio group with good tap targets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);

      expect(
        tester.getSemantics(find.text('10 دقائق / يوم')),
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

const _text = LocalizedText(ar: 'نص');
