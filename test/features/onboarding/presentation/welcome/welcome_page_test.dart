import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_motion.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/features/onboarding/presentation/welcome/pages/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Widget page({VoidCallback? onStart, VoidCallback? onSignIn}) =>
      WelcomePage(onStart: onStart ?? () {}, onSignIn: onSignIn ?? () {});

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
          expect(find.text('welcome_title'.tr()), findsOneWidget);
          expect(find.text('app_name'.tr()), findsOneWidget);
        });
      }
    }
  }

  testWidgets('the buttons hand navigation to the router', (tester) async {
    var started = 0;
    var signedIn = 0;
    await tester.pumpLocalized(
      page(onStart: () => started++, onSignIn: () => signedIn++),
    );
    await tester.pump(AppMotion.heroEntrance);

    await tester.tap(find.text('welcome_start'.tr()));
    await tester.tap(find.text('welcome_have_account'.tr()));

    expect(started, 1);
    expect(signedIn, 1);
  });

  testWidgets('has no undersized or unlabeled tap targets', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(page(), size: narrowViewport);
    await tester.pump(AppMotion.heroEntrance);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  double titleOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('welcome_title'.tr()),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  testWidgets('content fades in with the entrance', (tester) async {
    await tester.pumpLocalized(page());
    expect(titleOpacity(tester), lessThan(1));

    await tester.pump(AppMotion.heroEntrance);
    expect(titleOpacity(tester), 1);
  });

  testWidgets('the entrance is skipped when motion is reduced', (tester) async {
    await tester.pumpLocalized(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: page(),
      ),
    );
    expect(titleOpacity(tester), 1);
  });
}
