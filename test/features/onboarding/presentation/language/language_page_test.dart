import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_motion.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/features/onboarding/presentation/language/pages/language_page.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Widget page({VoidCallback? onContinue, VoidCallback? onBack}) =>
      LanguagePage(onContinue: onContinue ?? () {}, onBack: onBack ?? () {});

  OnboardingOption option(WidgetTester tester, String title) => tester
      .widget<OnboardingOption>(find.widgetWithText(OnboardingOption, title));

  for (final locale in AppLocales.supported) {
    for (final size in [defaultViewport, narrowViewport]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('lays out without overflow (${locale.languageCode}, '
            '${size.width.toInt()}dp, ${mode.name})', (tester) async {
          await tester.pumpLocalized(
            page(),
            locale: locale,
            size: size,
            themeMode: mode,
          );
          await tester.pump(AppMotion.heroEntrance);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('the current language is preselected', (tester) async {
    await tester.pumpLocalized(page(), locale: AppLocales.english);
    expect(option(tester, 'English').selected, isTrue);
    expect(option(tester, 'العربية').selected, isFalse);
  });

  testWidgets('picking English switches the app to English, LTR', (
    tester,
  ) async {
    await tester.pumpLocalized(page());
    await tester.pump(AppMotion.heroEntrance);
    expect(
      Directionality.of(tester.element(find.byType(LanguagePage))),
      TextDirection.rtl,
    );

    await tester.tap(find.text('English'));
    await tester.pumpUntilLocalized();

    final context = tester.element(find.byType(LanguagePage));
    expect(context.locale, AppLocales.english);
    expect(Directionality.of(context), TextDirection.ltr);
    expect(
      find.text('Which language would you like to use for the app?'),
      findsOneWidget,
    );
    expect(option(tester, 'English').selected, isTrue);
  });

  testWidgets('continue and back are handed to the router', (tester) async {
    var continued = 0;
    var back = 0;
    await tester.pumpLocalized(
      page(onContinue: () => continued++, onBack: () => back++),
    );
    await tester.pump(AppMotion.heroEntrance);

    await tester.tap(find.text('common_continue'.tr()));
    await tester.tap(find.byTooltip('common_back'.tr()));

    expect(continued, 1);
    expect(back, 1);
  });

  testWidgets('screen readers get the step, the choices and their state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(page(), size: narrowViewport);
    await tester.pump(AppMotion.heroEntrance);

    expect(find.bySemanticsLabel('الخطوة 1 من 4'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('العربية')),
      isSemantics(
        isChecked: true,
        hasCheckedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('English')),
      isSemantics(isChecked: false, hasCheckedState: true),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('an option without onTap is disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(
      const Material(
        child: OnboardingOption(
          mark: 'A',
          title: 'Option',
          selected: false,
          onTap: null,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Option')),
      isSemantics(hasTapAction: false, hasCheckedState: true),
    );
    handle.dispose();
  });
}
