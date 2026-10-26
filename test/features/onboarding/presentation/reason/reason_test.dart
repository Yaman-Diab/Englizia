import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/features/onboarding/domain/entities/learning_reason.dart';
import 'package:englizia/features/onboarding/presentation/reason/cubit/reason_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reason/pages/reason_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  group('ReasonCubit', () {
    test('keeps picks in order and replies to the latest one still chosen', () {
      final cubit = ReasonCubit()
        ..toggle(LearningReason.communication)
        ..toggle(LearningReason.career)
        ..toggle(LearningReason.travel);
      expect(cubit.state.latest, LearningReason.travel);
      expect(cubit.state.canContinue, isTrue);

      cubit.toggle(LearningReason.travel);
      expect(cubit.state.latest, LearningReason.career);

      cubit
        ..toggle(LearningReason.career)
        ..toggle(LearningReason.communication);
      expect(cubit.state.latest, isNull);
      expect(cubit.state.canContinue, isFalse);
    });
  });

  group('ReasonPage', () {
    Future<ReasonCubit> pumpPage(
      WidgetTester tester, {
      TrackAudience audience = TrackAudience.self,
      ValueChanged<List<LearningReason>>? onContinue,
      LayoutCase? layout,
    }) async {
      final cubit = ReasonCubit();
      addTearDown(cubit.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: ReasonPage(
            audience: audience,
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

    testLayouts('lays out without overflow', (tester, layout) async {
      final cubit = await pumpPage(tester, layout: layout);
      for (final reason in LearningReason.values) {
        cubit.toggle(reason);
      }
      await tester.pump(AppMotion.medium);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the guide asks, then replies to the latest choice', (
      tester,
    ) async {
      final cubit = await pumpPage(tester);
      expect(find.text('onboarding_reason_question'.tr()), findsOneWidget);

      await tester.tap(find.text('onboarding_reason_travel'.tr()));
      await tester.pump(AppMotion.medium * 2);
      expect(find.text('onboarding_reason_travel_reply'.tr()), findsOneWidget);

      cubit.toggle(LearningReason.travel);
      await tester.pump(AppMotion.medium * 2);
      expect(find.text('onboarding_reason_question'.tr()), findsOneWidget);
    });

    testWidgets('continue needs a choice and hands all picks on', (
      tester,
    ) async {
      List<LearningReason>? sent;
      await pumpPage(tester, onContinue: (picks) => sent = picks);

      await tester.tap(find.text('common_continue'.tr()));
      expect(sent, isNull);

      await tester.tap(find.text('onboarding_reason_fun'.tr()));
      await tester.tap(find.text('onboarding_reason_exams'.tr()));
      await tester.pump(AppMotion.medium);
      await tester.tap(find.text('common_continue'.tr()));
      expect(sent, [LearningReason.fun, LearningReason.exams]);
    });

    testWidgets('the progress counts the path the learner is on', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, audience: TrackAudience.schoolStudent);
      expect(find.bySemanticsLabel('الخطوة 4 من 5'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reasons are checkboxes, not a radio group', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = await pumpPage(tester);
      cubit.toggle(LearningReason.career);
      await tester.pump(AppMotion.medium);

      expect(
        tester.getSemantics(find.text('onboarding_reason_career'.tr())),
        isSemantics(
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: false,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
