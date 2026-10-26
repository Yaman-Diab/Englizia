import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  const delay = Duration(milliseconds: 200);
  final settled = delay + AppMotion.entrance;

  double opacityOf(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(Entrance),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  for (final motion in EntranceMotion.values) {
    testWidgets('${motion.name} waits for its delay, then arrives', (
      tester,
    ) async {
      await tester.pumpLocalized(
        Entrance(motion: motion, delay: delay, child: const Text('hi')),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(delay ~/ 2);
      expect(opacityOf(tester), 0);

      await tester.settleEntrance(settled);
      expect(opacityOf(tester), 1);
    });
  }

  testWidgets('reduce motion shows the child as is', (tester) async {
    await tester.pumpLocalized(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Entrance(
          motion: EntranceMotion.up,
          delay: delay,
          child: Text('hi'),
        ),
      ),
    );
    expect(find.byType(Animate), findsNothing);
    expect(find.text('hi'), findsOneWidget);
  });
}
