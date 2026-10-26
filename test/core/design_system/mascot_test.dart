import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/mascot/mascot_motion.dart';
import 'package:englizia/core/design_system/mascot/mascot_painter.dart';
import 'package:englizia/core/design_system/mascot/mascot_palette.dart';
import 'package:englizia/core/design_system/mascot/mascot_pose.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Duration at(Duration period, double fraction) =>
      Duration(microseconds: (period.inMicroseconds * fraction).round());

  group('idle motion follows the design keyframes', () {
    test('starts at rest', () {
      final f = MascotFrame.at(Duration.zero, waving: false);
      expect(f.lift, 0);
      expect(f.shadowRadius, 42);
      expect(f.eyeOpenness, 1);
      expect(f.waveAngle, 0);
    });

    test('floats 5 units up and shrinks the shadow halfway through', () {
      final f = MascotFrame.at(at(AppMotion.characterFloat, .5), waving: false);
      expect(f.lift, closeTo(5, 1e-6));
      expect(f.shadowRadius, closeTo(35, 1e-6));
    });

    test('blinks near the end of each blink cycle', () {
      final f = MascotFrame.at(
        at(AppMotion.characterBlink, .94),
        waving: false,
      );
      expect(f.eyeOpenness, closeTo(.11, 1e-6));
    });

    test('waves only when asked', () {
      final peak = at(AppMotion.characterWave, .11);
      expect(MascotFrame.at(peak, waving: true).waveAngle, closeTo(-22, 1e-6));
      expect(MascotFrame.at(peak, waving: false).waveAngle, 0);
      final rest = at(AppMotion.characterWave, .8);
      expect(MascotFrame.at(rest, waving: true).waveAngle, 0);
      expect(MascotFrame.at(rest, waving: true).waveMarks, 0);
    });
  });

  test('a pose change moves the arms and swaps the face at once', () {
    final from = MascotExpression.welcome.pose;
    final to = MascotExpression.happy.pose;
    final mid = MascotPose.lerpGeometry(from, to, .5);
    expect(
      mid.rightArm.end,
      Offset.lerp(from.rightArm.end, to.rightArm.end, .5),
    );
    expect(mid.leftArm.end, Offset.lerp(from.leftArm.end, to.leftArm.end, .5));
    expect(mid.eyes, to.eyes);
    expect(mid.mouth, to.mouth);
  });

  test('holding the key raises the right hand as a fist', () {
    final painter = MascotPainter(
      pose: MascotExpression.welcome.pose,
      palette: MascotPalette.light,
      prop: MascotProp.key,
      frame: ValueNotifier(MascotFrame.still),
    );
    expect(painter.pose.rightHand, MascotHand.fist);
    expect(painter.pose.rightArm.end, const Offset(146, 102));
  });

  test('the head framing drops arms, tilt and effects', () {
    final painter = MascotPainter(
      pose: MascotExpression.happy.pose,
      palette: MascotPalette.light,
      prop: MascotProp.none,
      framing: MascotFraming.head,
      frame: ValueNotifier(MascotFrame.still),
    );
    expect(painter.pose.leftArm, MascotPose.restLeft);
    expect(painter.pose.rightArm, MascotPose.restRight);
    expect(painter.pose.sparkles, isFalse);
    expect(painter.pose.tilt, 0);
    // The face is kept.
    expect(painter.pose.mouth, MascotExpression.happy.pose.mouth);
  });

  test('hats replace the speech tuft', () {
    expect(MascotProp.beanie.isHat, isTrue);
    expect(MascotProp.gradCap.isHat, isTrue);
    expect(MascotProp.glasses.isHat, isFalse);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('every expression and prop paints (${mode.name})', (
      tester,
    ) async {
      await tester.pumpLocalized(
        SingleChildScrollView(
          child: Wrap(
            children: [
              for (final expression in MascotExpression.values)
                for (final prop in MascotProp.values)
                  for (final framing in MascotFraming.values)
                    Mascot(
                      expression: expression,
                      prop: prop,
                      framing: framing,
                      size: 60,
                      animate: false,
                    ),
            ],
          ),
        ),
        themeMode: mode,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(Mascot),
        findsNWidgets(
          MascotExpression.values.length *
              MascotProp.values.length *
              MascotFraming.values.length,
        ),
      );
    });
  }

  MascotPainter painterOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(Mascot),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as MascotPainter;

  testWidgets('changing the expression animates the arms', (tester) async {
    Widget mascot(MascotExpression e) => Mascot(expression: e, animate: false);

    await tester.pumpLocalized(mascot(MascotExpression.welcome));
    await tester.pumpLocalized(mascot(MascotExpression.happy));
    await tester.pump(AppMotion.characterPose ~/ 2);

    final happy = MascotExpression.happy.pose.leftArm.end;
    final welcome = MascotExpression.welcome.pose.leftArm.end;
    final shown = painterOf(tester).pose.leftArm.end;
    expect(shown, isNot(happy));
    expect(shown, isNot(welcome));

    await tester.pump(AppMotion.characterPose);
    expect(painterOf(tester).pose.leftArm.end, happy);
  });

  testWidgets('idle loop runs, and stops when motion is reduced', (
    tester,
  ) async {
    await tester.pumpLocalized(const Mascot(waving: true));
    await tester.pump(at(AppMotion.characterFloat, .5));
    expect(painterOf(tester).frame.value, isNot(MascotFrame.still));

    await tester.pumpLocalized(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Mascot(waving: true),
      ),
    );
    await tester.pump(at(AppMotion.characterFloat, .5));
    expect(painterOf(tester).frame.value, MascotFrame.still);
  });

  testWidgets('expression changes are instant when motion is reduced', (
    tester,
  ) async {
    Widget mascot(MascotExpression e) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Mascot(expression: e),
    );
    await tester.pumpLocalized(mascot(MascotExpression.welcome));
    await tester.pumpLocalized(mascot(MascotExpression.happy));
    expect(
      painterOf(tester).pose.leftArm.end,
      MascotExpression.happy.pose.leftArm.end,
    );
  });

  testWidgets('screen readers hear the guide by name', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(const Mascot(animate: false));
    expect(find.bySemanticsLabel('بلبل، المرشد'), findsOneWidget);
    handle.dispose();
  });
}
