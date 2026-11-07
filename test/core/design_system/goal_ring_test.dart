import 'dart:math' as math;

import 'package:englizia/core/design_system/widgets/goal_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  test('the arc sweeps clockwise by the share, none at 0', () {
    expect(GoalRing.sweepOf(0), 0);
    expect(GoalRing.sweepOf(.7), closeTo(2 * math.pi * .7, 1e-9));
    expect(GoalRing.sweepOf(1.4), closeTo(2 * math.pi, 1e-9));
    expect(GoalRing.sweepOf(-1), 0);
  });

  testWidgets('its track and arc keep inside its size at any stroke', (
    tester,
  ) async {
    await tester.pumpLocalized(
      const Center(
        child: GoalRing(
          share: .5,
          color: Color(0xFF2563EB),
          track: Color(0xFFDBEAFE),
          size: 96,
          stroke: 8,
          child: SizedBox.square(dimension: 72),
        ),
      ),
    );
    final ring = find.byType(GoalRing);
    expect(tester.getSize(ring), const Size.square(96));
    expect(
      tester.getCenter(find.byType(SizedBox).last),
      tester.getCenter(ring),
    );
    // Radius 44: the 8 stroke's outer edge on the box.
    expect(
      ring,
      paints
        ..something((method, args) {
          if (method != #drawOval) return false;
          final paint = args[1] as Paint;
          return args[0] == const Rect.fromLTWH(4, 4, 88, 88) &&
              paint.color.toARGB32() == 0xFFDBEAFE &&
              paint.strokeWidth == 8;
        })
        ..arc(color: const Color(0xFF2563EB), strokeWidth: 8),
    );
  });

  testWidgets('with no child it is only the ring', (tester) async {
    await tester.pumpLocalized(
      const Center(
        child: GoalRing(share: 0, color: Color(0xFF2563EB), size: 40),
      ),
    );
    expect(tester.getSize(find.byType(GoalRing)), const Size.square(40));
    expect(find.byType(GoalRing), isNot(paints..arc()));
  });
}
