import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/child_profile/cubit/child_profile_cubit.dart';
import 'package:englizia/features/onboarding/presentation/child_profile/pages/child_profile_page.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  group('ChildProfileCubit', () {
    test('needs a non-blank name and an age', () {
      final cubit = ChildProfileCubit();
      expect(cubit.state.canContinue, isFalse);

      cubit.setName('   ');
      cubit.setAge(6);
      expect(cubit.state.canContinue, isFalse);

      cubit.setName('  ليان ');
      expect(cubit.state.canContinue, isTrue);
      expect(cubit.state.displayName, 'ليان');
    });
  });

  group('ChildProfilePage', () {
    Future<ChildProfileCubit> pumpPage(
      WidgetTester tester, {
      ValueChanged<ChildProfileState>? onContinue,
      Locale locale = AppLocales.arabic,
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final cubit = ChildProfileCubit();
      addTearDown(cubit.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: ChildProfilePage(
            path: const OnboardingPath(
              audience: TrackAudience.child,
              entryMethod: TrackEntryMethod.directStart,
            ),
            onContinue: onContinue ?? (_) {},
            onBack: () {},
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await tester.settleEntrance(QuestionEntrance.settled);
      return cubit;
    }

    testLayouts('lays out without overflow', (tester, layout) async {
      await pumpPage(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await tester.enterText(find.byType(TextField), 'Alexandria');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the greeting follows the typed name', (tester) async {
      await pumpPage(tester);
      expect(find.text('مرحبًا!'), findsOneWidget);

      await tester.enterText(find.byType(TextField), ' ليان ');
      await tester.pump();
      expect(find.text('مرحبًا ليان!'), findsOneWidget);
    });

    testWidgets('continue waits for a name and an age, then hands them on', (
      tester,
    ) async {
      ChildProfileState? sent;
      await pumpPage(tester, onContinue: (state) => sent = state);

      await tester.enterText(find.byType(TextField), 'ليان');
      await tester.pump();
      await tester.tap(find.text('common_continue'.tr()));
      expect(sent, isNull);

      await tester.tap(find.text('6'));
      await tester.pump(AppMotion.fast);
      await tester.tap(find.text('common_continue'.tr()));
      expect(sent?.displayName, 'ليان');
      expect(sent?.age, 6);
    });

    testWidgets('the name is capped at 20 characters', (tester) async {
      final cubit = await pumpPage(tester);
      await tester.enterText(find.byType(TextField), 'a' * 30);
      await tester.pump();
      expect(cubit.state.name.length, 20);
    });

    testWidgets('ages are radios read as "N سنوات"', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = await pumpPage(tester, size: narrowViewport);
      cubit.setAge(7);
      await tester.pump();

      expect(find.bySemanticsLabel('7 سنوات'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('7 سنوات')),
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
