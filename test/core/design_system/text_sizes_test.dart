import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// The context of a localized app in [locale], [scale] text.
Future<BuildContext> _context(
  WidgetTester tester,
  Locale locale, {
  double scale = 1,
}) async {
  late BuildContext context;
  await tester.pumpLocalized(
    MediaQuery.withClampedTextScaling(
      minScaleFactor: scale,
      maxScaleFactor: scale,
      child: Builder(
        builder: (inner) {
          context = inner;
          return const SizedBox();
        },
      ),
    ),
    locale: locale,
  );
  return context;
}

void main() {
  setUpAll(initLocalizationForTests);

  testWidgets('a design size: Arabic running text keeps 1.7, a line its own', (
    tester,
  ) async {
    final context = await _context(tester, AppLocales.arabic);
    final texts = context.texts;
    expect(texts.runningMinHeight, 1.7);
    final running = texts.sized(texts.caption, size: 13, line: 18);
    expect(running.fontSize, 13);
    expect(running.height, 1.7);
    final one = texts.sized(texts.caption, size: 13, line: 18, running: false);
    expect(one.height, 18 / 13);
    // Taller than the floor, the design's line stays.
    expect(texts.sized(texts.body, size: 10, line: 20).height, 2);
  });

  testWidgets('English keeps the design\'s line', (tester) async {
    final context = await _context(tester, AppLocales.english);
    final texts = context.texts;
    expect(texts.runningMinHeight, 0);
    expect(texts.sized(texts.caption, size: 13, line: 18).height, 18 / 13);
  });

  testWidgets('in a box the design sizes, the floor once the text wraps', (
    tester,
  ) async {
    var context = await _context(tester, AppLocales.arabic);
    TextStyle fitted(BuildContext context, double width) =>
        context.texts.sizedFor(
          context,
          context.texts.caption,
          text: 'درسك التالي',
          width: width,
          size: 13,
          line: 18,
        );
    expect(fitted(context, 200).height, 18 / 13, reason: 'one line');
    expect(fitted(context, 40).height, 1.7, reason: 'wrapped');

    context = await _context(tester, AppLocales.arabic, scale: 1.3);
    expect(fitted(context, 60).height, 1.7, reason: 'large text wraps it');
  });
}
