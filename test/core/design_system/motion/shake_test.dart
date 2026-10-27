import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/shake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Widget shake(Object trigger) =>
      Shake(trigger: trigger, child: const Text('field'));

  double offset(WidgetTester tester) => tester
      .widgetList<Transform>(
        find.ancestor(of: find.text('field'), matching: find.byType(Transform)),
      )
      .first
      .transform
      .getTranslation()
      .x;

  testWidgets('rests on the first build', (tester) async {
    await tester.pumpLocalized(shake(1));
    expect(offset(tester), 0);
  });

  testWidgets('shakes once when the trigger changes, then rests', (
    tester,
  ) async {
    await tester.pumpLocalized(shake(1));
    await tester.pumpLocalized(shake(2));
    await tester.pump(AppMotion.shake ~/ 8);
    expect(offset(tester).abs(), greaterThan(1));

    await tester.pump(AppMotion.shake);
    expect(offset(tester), closeTo(0, 1e-9));
  });

  testWidgets('stays still under reduce motion', (tester) async {
    Widget reduced(Object trigger) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: shake(trigger),
    );
    await tester.pumpLocalized(reduced(1));
    await tester.pumpLocalized(reduced(2));
    await tester.pump(AppMotion.shake ~/ 8);
    expect(offset(tester), 0);
  });
}
