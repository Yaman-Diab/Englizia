import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/swap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Widget line(String text) => Swap(child: Text(text, key: ValueKey(text)));

  testWidgets('a new line fades in over the old one', (tester) async {
    await tester.pumpLocalized(line('one'));
    await tester.pumpLocalized(line('two'));
    await tester.pump(AppMotion.medium ~/ 2);

    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);

    await tester.pump(AppMotion.medium);
    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('reduce motion swaps at once', (tester) async {
    Widget reduced(String text) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: line(text),
    );
    await tester.pumpLocalized(reduced('one'));
    await tester.pumpLocalized(reduced('two'));
    await tester.pump();

    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsOneWidget);
  });
}
