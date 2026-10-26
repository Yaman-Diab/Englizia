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

  group('idle motion has a personality per expression', () {
    test('calm expressions drift, lively ones bounce', () {
      final sleep = MascotExpression.sleep.idle;
      final happy = MascotExpression.happy.idle;
      expect(happy.lift, greaterThan(sleep.lift));
      expect(happy.period, lessThan(sleep.period));
    });

    test('the float follows the expression\'s height and pace', () {
      final happy = MascotExpression.happy.idle;
      final top = MascotFrame.at(
        at(happy.period, .5),
        waving: false,
        idle: happy,
      );
      expect(top.lift, closeTo(happy.lift, 1e-6));
      expect(top.stretch, closeTo(happy.stretch, 1e-6));
      final bottom = MascotFrame.at(Duration.zero, waving: false, idle: happy);
      expect(bottom.stretch, closeTo(-happy.stretch, 1e-6));
    });

    test('a gesture swings the arm at the top of each float', () {
      final confident = MascotExpression.confident.idle;
      final top = MascotFrame.at(
        Duration.zero,
        waving: false,
        idle: confident,
        floatPhase: .5,
      );
      expect(top.swing, closeTo(confident.swing, 1e-6));
      expect(
        MascotFrame.at(
          Duration.zero,
          waving: false,
          idle: confident,
          floatPhase: 0,
        ).swing,
        0,
      );
    });

    test('a sway rocks the figure either way', () {
      const idle = MascotIdle(sway: 2);
      double sway(double phase) => MascotFrame.at(
        Duration.zero,
        waving: false,
        idle: idle,
        floatPhase: phase,
      ).sway;
      expect(sway(.25), closeTo(2, 1e-6));
      expect(sway(.75), closeTo(-2, 1e-6));
    });

    test('staggered loops peak in turn and wrap around', () {
      expect(MascotFrame.bump(.2, center: .2), 1);
      expect(MascotFrame.bump(.6, center: .2), 0);
      expect(MascotFrame.bump(.99, center: .04, width: .2), closeTo(.5, 1e-6));
    });

    test('the still frame keeps the small loops at rest', () {
      expect(MascotFrame.still.pulse, isNull);
      expect(MascotFrame.at(Duration.zero, waving: false).pulse, 0);
    });
  });

  group('changing expression', () {
    final from = MascotExpression.welcome.pose;
    final to = MascotExpression.happy.pose;

    test('the arms follow the motion, even past the target', () {
      final mid = MascotPose.blend(from, to, motion: .5, progress: .5);
      expect(
        mid.leftArm.end,
        Offset.lerp(from.leftArm.end, to.leftArm.end, .5),
      );
      final over = MascotPose.blend(from, to, motion: 1.1, progress: .9);
      expect(
        over.leftArm.end,
        Offset.lerp(from.leftArm.end, to.leftArm.end, 1.1),
      );
    });

    test('the face swaps midway, while the eyes are shut', () {
      const before = MascotPose.faceSwitch - .01;
      const after = MascotPose.faceSwitch + .01;
      expect(
        MascotPose.blend(from, to, motion: .3, progress: before).mouth,
        from.mouth,
      );
      expect(
        MascotPose.blend(from, to, motion: .5, progress: after).mouth,
        to.mouth,
      );
      expect(MascotPose.changeBlink(MascotPose.faceSwitch), closeTo(.9, 1e-6));
      expect(MascotPose.changeBlink(0), 0);
      expect(MascotPose.changeBlink(1), 0);
    });

    test('the figure crouches, then lands back at full height', () {
      expect(MascotPose.changeStretch(.25), lessThan(0));
      expect(MascotPose.changeStretch(.75), greaterThan(0));
      expect(MascotPose.changeStretch(0), 0);
      expect(MascotPose.changeStretch(1), 0);
    });
  });

  test('confident gives a thumbs-up with the other hand on the hip', () {
    final pose = MascotExpression.confident.pose;
    expect(pose.rightHand, MascotHand.thumbsUp);
    expect(pose.leftArm.hand, isNot(pose.leftArm.end));
    expect(pose.mouth, MascotMouth.proud);
    expect(pose.glint, isTrue);
  });

  test('the silhouette is one flat color with no shadow', () {
    for (final palette in [
      MascotPalette.silhouette,
      MascotPalette.silhouetteDark,
    ]) {
      expect(palette.isSilhouette, isTrue);
      expect({
        palette.body,
        palette.ink,
        palette.highlight,
        palette.scarf,
      }, hasLength(1));
      expect(palette.shadow.a, 0);
      expect(palette.outline, isNull);
    }
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
    expect(painter.pose.glint, isFalse);
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
              for (final expression in MascotExpression.values)
                Mascot(
                  expression: expression,
                  silhouette: true,
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
                  MascotFraming.values.length +
              MascotExpression.values.length,
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
    expect(painterOf(tester).blink, 0);
    expect(painterOf(tester).stretch, 0);
  });

  testWidgets('the face swaps behind a blink during the change', (
    tester,
  ) async {
    Widget mascot(MascotExpression e) => Mascot(expression: e, animate: false);

    await tester.pumpLocalized(mascot(MascotExpression.welcome));
    await tester.pumpLocalized(mascot(MascotExpression.happy));
    await tester.pump(
      AppMotion.characterPose * MascotPose.faceSwitch -
          const Duration(milliseconds: 1),
    );
    expect(painterOf(tester).blink, greaterThan(.8));
    expect(painterOf(tester).pose.mouth, MascotExpression.welcome.pose.mouth);

    await tester.pump(const Duration(milliseconds: 20));
    expect(painterOf(tester).pose.mouth, MascotExpression.happy.pose.mouth);
  });

  testWidgets('the idle keeps its rhythm across an expression change', (
    tester,
  ) async {
    Widget mascot(MascotExpression e) => Mascot(expression: e);

    await tester.pumpLocalized(mascot(MascotExpression.sleep));
    await tester.pump(const Duration(milliseconds: 500));
    final before = painterOf(tester).frame.value.lift;
    await tester.pumpLocalized(mascot(MascotExpression.happy));
    await tester.pump(const Duration(milliseconds: 16));
    final after = painterOf(tester).frame.value.lift;
    expect((after - before).abs(), lessThan(1));
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
