import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget sized(double height, {bool reduce = false}) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: SmoothSize(child: SizedBox(width: 100, height: height)),
      ),
    ),
  );

  testWidgets('eases to its new size', (tester) async {
    await tester.pumpWidget(sized(10));
    await tester.pumpWidget(sized(100));
    await tester.pump(const Duration(milliseconds: 50));

    final midway = tester.getSize(find.byType(SmoothSize)).height;
    expect(midway, inExclusiveRange(10, 100));

    await tester.pump(const Duration(seconds: 1));
    expect(tester.getSize(find.byType(SmoothSize)).height, 100);
  });

  testWidgets('under reduce motion it is at its new size at once', (
    tester,
  ) async {
    await tester.pumpWidget(sized(10, reduce: true));
    await tester.pumpWidget(sized(100, reduce: true));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SmoothSize)).height, 100);
  });

  testWidgets('what it replaces fails there, which is why it exists', (
    tester,
  ) async {
    Widget raw(double height) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: AnimatedSize(
          duration: Duration.zero,
          child: SizedBox(width: 100, height: height),
        ),
      ),
    );
    await tester.pumpWidget(raw(10));
    await tester.pumpWidget(raw(100));

    expect(tester.takeException(), isNotNull);
  });
}
