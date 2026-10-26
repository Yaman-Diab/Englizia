import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/settle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Widget settle(Object trigger) =>
      Settle(trigger: trigger, child: const Text('preview'));

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.ancestor(of: find.text('preview'), matching: find.byType(Opacity)),
      )
      .opacity;

  testWidgets('rests on the first build', (tester) async {
    await tester.pumpLocalized(settle(1));
    expect(opacity(tester), 1);
  });

  testWidgets('dips and settles back when the trigger changes', (tester) async {
    await tester.pumpLocalized(settle(1));
    await tester.pumpLocalized(settle(2));
    expect(opacity(tester), lessThan(1));

    await tester.pump(AppMotion.medium);
    expect(opacity(tester), 1);
  });

  testWidgets('stays still under reduce motion', (tester) async {
    Widget reduced(Object trigger) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: settle(trigger),
    );
    await tester.pumpLocalized(reduced(1));
    await tester.pumpLocalized(reduced(2));
    expect(opacity(tester), 1);
  });
}
