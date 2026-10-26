import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/pulse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Widget pulse(Object trigger) =>
      Pulse(trigger: trigger, child: const Text('flame'));

  double scale(WidgetTester tester) => tester
      .widgetList<Transform>(
        find.ancestor(of: find.text('flame'), matching: find.byType(Transform)),
      )
      .first
      .transform
      .getMaxScaleOnAxis();

  testWidgets('rests on the first build', (tester) async {
    await tester.pumpLocalized(pulse(1));
    expect(scale(tester), closeTo(1, 1e-9));
  });

  testWidgets('beats once when the trigger changes', (tester) async {
    await tester.pumpLocalized(pulse(1));
    await tester.pumpLocalized(pulse(2));
    await tester.pump(AppMotion.medium ~/ 2);
    expect(scale(tester), greaterThan(1.1));

    await tester.pump(AppMotion.medium);
    expect(scale(tester), closeTo(1, 1e-9));
  });

  testWidgets('stays still under reduce motion', (tester) async {
    Widget reduced(Object trigger) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: pulse(trigger),
    );
    await tester.pumpLocalized(reduced(1));
    await tester.pumpLocalized(reduced(2));
    await tester.pump(AppMotion.medium ~/ 2);
    expect(scale(tester), closeTo(1, 1e-9));
  });
}
