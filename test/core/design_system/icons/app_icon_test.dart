import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  testWidgets('every icon is a valid SVG that draws', (tester) async {
    await tester.pumpLocalized(
      Wrap(
        children: [
          for (final icon in AppIcon.values)
            AppIconView(icon, color: Colors.blue, size: 48),
        ],
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.byType(SvgPicture), findsNWidgets(AppIcon.values.length));
    expect(tester.takeException(), isNull);
  });

  test('each icon is a 24×24 stroked drawing in the designs\' style', () {
    for (final icon in AppIcon.values) {
      expect(icon.svg, contains('viewBox="0 0 24 24"'), reason: '$icon');
      expect(icon.svg, contains('stroke-width="2"'), reason: '$icon');
      expect(icon.svg, contains('stroke-linecap="round"'), reason: '$icon');
    }
  });

  testWidgets('the icon is decorative for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(
      const AppIconView(AppIcon.plane, color: Colors.blue),
    );
    expect(
      find.descendant(
        of: find.byType(AppIconView),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    handle.dispose();
  });
}
