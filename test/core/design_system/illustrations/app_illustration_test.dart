import 'package:englizia/core/design_system/illustrations/app_illustration.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('every illustration draws in ${themeMode.name} mode', (
      tester,
    ) async {
      await tester.pumpLocalized(
        Wrap(
          children: [
            for (final illustration in AppIllustration.values)
              AppIllustrationView(illustration),
          ],
        ),
        themeMode: themeMode,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(
        find.byType(SvgPicture),
        findsNWidgets(AppIllustration.values.length),
      );
      expect(
        find.byType(Mascot),
        findsNWidgets(AppIllustration.values.length),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the illustration is decorative for screen readers', (
    tester,
  ) async {
    await tester.pumpLocalized(
      const AppIllustrationView(AppIllustration.hatching),
    );
    expect(
      find.descendant(
        of: find.byType(AppIllustrationView),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });
}
