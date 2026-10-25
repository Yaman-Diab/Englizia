import 'dart:math' as math;

import 'package:englizia/core/design_system/app_text_styles.dart';
import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/mascot/mascot_motion.dart';
import 'package:englizia/core/design_system/mascot/mascot_palette.dart';
import 'package:englizia/core/design_system/mascot/mascot_pose.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Paints the guide in the 180×180 space of the approved drawing, scaled to
/// the canvas. Shapes, coordinates and layer order follow Claude Design
/// `Guide.dc.html`; [frame] adds the idle motion and triggers repaints.
class MascotPainter extends CustomPainter {
  MascotPainter({
    required MascotPose pose,
    required this.palette,
    required this.prop,
    required this.frame,
  }) : pose = prop == MascotProp.key ? _holdingKey(pose) : pose,
       super(repaint: frame);

  final MascotPose pose;
  final MascotPalette palette;
  final MascotProp prop;
  final ValueListenable<MascotFrame> frame;

  static const viewBox = 180.0;
  static const _rimWidth = 2.5;
  static const _armWidth = 14.0;
  static const _feetPivot = Offset(90, 166);

  static MascotPose _holdingKey(MascotPose pose) => pose.copyWith(
    rightArm: const MascotArm(Offset(126, 114), Offset(146, 102)),
    rightHand: MascotHand.fist,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame.value;
    canvas
      ..save()
      ..scale(size.width / viewBox, size.height / viewBox);

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(90, 171),
        width: f.shadowRadius * 2,
        height: 12,
      ),
      Paint()..color = palette.shadow,
    );

    canvas.translate(0, -f.lift);
    if (pose.tilt != 0) _rotate(canvas, pose.tilt, _feetPivot);

    final rim = palette.outline;
    if (rim != null) {
      _feet(canvas, rim, rim: true);
      _fill(canvas, _bubblePath, rim, rim: true);
      _fill(canvas, _bodyPath, rim, rim: true);
      _fill(canvas, _tailPath, rim, rim: true);
      _arms(canvas, f, rim: rim);
    }

    _feet(canvas, palette.feet);
    _fill(canvas, _bubblePath, palette.body);
    _bubbleContent(canvas);
    _fill(canvas, _bodyPath, palette.body);
    _fill(canvas, _oval(90, 134, 28, 20), palette.belly);
    _fill(canvas, _tailPath, palette.scarfDeep);
    _fill(
      canvas,
      Path()..addRRect(
        RRect.fromLTRBR(48, 106, 132, 118, const Radius.circular(6)),
      ),
      palette.scarf,
    );
    _fill(canvas, _oval(120, 112, 7, 7), palette.scarf);
    if (pose.cheeks > 0) {
      final blush = palette.blush.withValues(alpha: pose.cheeks);
      _fill(canvas, _oval(64, 93, 7, 4.5), blush);
      _fill(canvas, _oval(116, 93, 7, 4.5), blush);
    }
    _eye(canvas, 76, f);
    _eye(canvas, 104, f);
    _brows(canvas);
    _mouth(canvas);
    if (prop == MascotProp.headphones) _headphones(canvas);
    _arms(canvas, f);
    if (pose.phone) _phone(canvas);
    if (pose.sparkles) {
      for (final (x, y, s) in const [
        (20.0, 42.0, 9.0),
        (162.0, 30.0, 8.0),
        (14.0, 112.0, 6.0),
        (168.0, 120.0, 6.0),
      ]) {
        _fill(canvas, _sparkle(x, y, s), palette.spark);
      }
    }
    canvas.restore();
  }

  // ---- body parts --------------------------------------------------------

  void _feet(Canvas canvas, Color color, {bool rim = false}) {
    _fill(canvas, _oval(74, 160, 14, 7), color, rim: rim);
    _fill(canvas, _oval(106, 160, 14, 7), color, rim: rim);
  }

  /// Left arm, then the right arm rotated by the wave around its shoulder.
  /// With [rim] set, draws the thicker light rim behind the arms.
  void _arms(Canvas canvas, MascotFrame f, {Color? rim}) {
    _arm(canvas, pose.leftArm, pose.leftHand, pose.leftSplit, rim);
    if (rim == null && pose.leftHand == MascotHand.fist) {
      _fistCrease(canvas, pose.leftArm.end);
    }

    canvas.save();
    if (f.waveAngle != 0) _rotate(canvas, f.waveAngle, pose.rightArm.shoulder);
    _arm(canvas, pose.rightArm, pose.rightHand, pose.rightSplit, rim);
    if (rim == null) {
      if (pose.rightHand == MascotHand.fist) {
        _fistCrease(canvas, pose.rightArm.end);
      }
      if (pose.rightHand == MascotHand.wave && f.waveMarks > 0) {
        _stroke(
          canvas,
          Path()
            ..moveTo(163, 61)
            ..quadraticBezierTo(169, 70, 167, 80)
            ..moveTo(155, 54)
            ..quadraticBezierTo(163, 55, 169, 61),
          3.4,
          palette.spark.withValues(alpha: f.waveMarks),
        );
      }
      if (prop == MascotProp.key) _key(canvas, pose.rightArm.hand);
    }
    canvas.restore();
  }

  void _arm(
    Canvas canvas,
    MascotArm arm,
    MascotHand hand,
    double split,
    Color? rim,
  ) {
    canvas.drawLine(
      arm.shoulder,
      arm.end,
      Paint()
        ..color = rim ?? palette.arm
        ..strokeWidth = _armWidth + (rim == null ? 0 : _rimWidth * 2)
        ..strokeCap = StrokeCap.round,
    );
    final color = rim ?? palette.arm;
    final isRim = rim != null;
    final Offset(:dx, :dy) = arm.hand;
    switch (hand) {
      case MascotHand.none:
        break;
      case MascotHand.fist:
        _fill(canvas, _oval(dx, dy, 11, 11), color, rim: isRim);
      case MascotHand.palm:
        _fill(canvas, _oval(dx, dy, 11, 7), color, rim: isRim);
      case MascotHand.cup:
        _fill(canvas, _oval(dx, dy, 8, 11), color, rim: isRim);
      case MascotHand.wave || MascotHand.ball:
        _fill(canvas, _oval(dx, dy, 10, 10), color, rim: isRim);
      case MascotHand.cover:
        _coveringHand(canvas, dx, dy, split, color, isRim);
    }
  }

  void _coveringHand(
    Canvas canvas,
    double x,
    double y,
    double split,
    Color color,
    bool rim,
  ) {
    const rx = 13.0, ry = 12.0;
    if (split < .02) {
      _fill(canvas, _oval(x, y, rx, ry), color, rim: rim);
      if (!rim) {
        _stroke(
          canvas,
          Path()
            ..moveTo(x - 4.5, y - ry + 2)
            ..lineTo(x - 4.5, y - ry + 8)
            ..moveTo(x + 4.5, y - ry + 2)
            ..lineTo(x + 4.5, y - ry + 8),
          2.2,
          palette.feet,
        );
      }
      return;
    }
    final gap = 6 * split;
    final half = (rx + 2 * split - gap) / 2;
    final offset = gap + half;
    _fill(canvas, _oval(x - offset, y, half, ry), color, rim: rim);
    _fill(canvas, _oval(x + offset, y, half, ry), color, rim: rim);
  }

  void _fistCrease(Canvas canvas, Offset at) => _stroke(
    canvas,
    Path()
      ..moveTo(at.dx - 5, at.dy - 1)
      ..quadraticBezierTo(at.dx, at.dy - 5, at.dx + 5, at.dy - 1),
    2.4,
    palette.feet,
  );

  void _eye(Canvas canvas, double x, MascotFrame f) {
    const y = 80.0;
    final ink = palette.ink;
    switch (pose.eyes) {
      case MascotEyes.closed:
        _stroke(
          canvas,
          Path()
            ..moveTo(x - 7, y + 3)
            ..quadraticBezierTo(x, y - 8, x + 7, y + 3),
          4.2,
          ink,
        );
      case MascotEyes.soft:
        _stroke(
          canvas,
          Path()
            ..moveTo(x - 7, y - 1)
            ..quadraticBezierTo(x, y + 6, x + 7, y - 1),
          4,
          ink,
        );
      case MascotEyes.sleep:
        _stroke(
          canvas,
          Path()
            ..moveTo(x - 6, y + 1)
            ..quadraticBezierTo(x, y + 5, x + 6, y + 1),
          3.6,
          ink,
        );
      case MascotEyes.look:
        _blinking(canvas, x, y, f, () {
          final white = _oval(x, y, 8, 9);
          _fill(canvas, white, palette.highlight);
          canvas.drawPath(
            white,
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
          _fill(canvas, _oval(x + 2.6, y - 3.2, 4.6, 4.6), ink);
          _fill(
            canvas,
            _oval(x + 4, y - 4.8, 1.5, 1.5),
            palette.highlight.withValues(alpha: f.eyeHighlight),
          );
        });
      case MascotEyes.open || MascotEyes.wide:
        final r = pose.eyes == MascotEyes.wide ? 8.0 : 6.5;
        _blinking(canvas, x, y, f, () {
          _fill(canvas, _oval(x, y, r, r), ink);
          _fill(
            canvas,
            _oval(x + r * .32, y - r * .34, r * .32, r * .32),
            palette.highlight.withValues(alpha: f.eyeHighlight),
          );
        });
    }
  }

  void _blinking(
    Canvas canvas,
    double x,
    double y,
    MascotFrame f,
    VoidCallback draw,
  ) {
    canvas
      ..save()
      ..translate(x, y)
      ..scale(1, f.eyeOpenness)
      ..translate(-x, -y);
    draw();
    canvas.restore();
  }

  void _brows(Canvas canvas) {
    final pair = switch (pose.brows) {
      MascotBrows.up => const [
        (68.0, 67.0, 62.0, 67.0),
        (96.0, 67.0, 62.0, 67.0),
      ],
      MascotBrows.calm => const [
        (68.0, 68.0, 66.0, 68.0),
        (96.0, 68.0, 66.0, 68.0),
      ],
      MascotBrows.raise => const [
        (68.0, 68.0, 66.5, 68.0),
        (96.0, 63.0, 55.0, 61.0),
      ],
      MascotBrows.none => const <(double, double, double, double)>[],
    };
    for (final (x, y0, yc, y1) in pair) {
      _stroke(
        canvas,
        Path()
          ..moveTo(x, y0)
          ..quadraticBezierTo(x + 8, yc, x + 16, y1),
        3.2,
        palette.ink,
      );
    }
  }

  void _mouth(Canvas canvas) {
    final ink = palette.ink;
    Path curve(double x0, double y0, double cx, double cy, double x1) => Path()
      ..moveTo(x0, y0)
      ..quadraticBezierTo(cx, cy, x1, y0);
    switch (pose.mouth) {
      case MascotMouth.grin:
        final open = Path()
          ..moveTo(77, 92)
          ..quadraticBezierTo(90, 114, 103, 92)
          ..close();
        _fill(canvas, open, ink);
        canvas.drawPath(
          open,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round,
        );
        _fill(canvas, _oval(90, 103, 6, 3.5), palette.blush);
      case MascotMouth.smile:
        _stroke(canvas, curve(81, 94, 90, 102, 99), 3.2, ink);
      case MascotMouth.calm:
        _stroke(canvas, curve(80, 93, 90, 103, 100), 3.2, ink);
      case MascotMouth.soft:
        _stroke(canvas, curve(83, 95, 90, 100, 97), 3.2, ink);
      case MascotMouth.small:
        _fill(canvas, _oval(93, 97, 3, 3.6), ink);
      case MascotMouth.hmm:
        _stroke(
          canvas,
          Path()
            ..moveTo(82, 96)
            ..quadraticBezierTo(87, 99.5, 91, 96.5)
            ..quadraticBezierTo(95, 94, 99, 95),
          3.2,
          ink,
        );
      case MascotMouth.o:
        _fill(canvas, _oval(90, 97, 4, 4.8), ink);
      case MascotMouth.bigO:
        _fill(canvas, _oval(90, 98, 7.5, 8.5), ink);
        _fill(canvas, _oval(90, 103, 4.5, 2.6), palette.blush);
      case MascotMouth.tiny:
        _fill(canvas, _oval(90, 96, 2.6, 3), ink);
    }
  }

  void _bubbleContent(Canvas canvas) {
    final color = palette.belly;
    switch (pose.bubble) {
      case MascotBubble.none:
        break;
      case MascotBubble.dots:
        for (final x in const [93.0, 100.0, 107.0]) {
          _fill(canvas, _oval(x, 16, 2.3, 2.3), color);
        }
      case MascotBubble.question:
        _glyph(canvas, '?', 15, const Offset(100, 21.5), color);
      case MascotBubble.sleep:
        _glyph(canvas, 'z', 14, const Offset(100, 21), color);
    }
  }

  /// A Latin glyph centered on [baseline], like SVG `text-anchor: middle`.
  void _glyph(
    Canvas canvas,
    String glyph,
    double fontSize,
    Offset baseline,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: AppFonts.primary(
          TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final ascent = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    painter
      ..paint(
        canvas,
        Offset(baseline.dx - painter.width / 2, baseline.dy - ascent),
      )
      ..dispose();
  }

  void _headphones(Canvas canvas) {
    final rim = palette.outline;
    final band = Path()
      ..moveTo(47, 84)
      ..cubicTo(45, 20, 135, 20, 133, 84);
    if (rim != null) _stroke(canvas, band, 11, rim);
    _stroke(canvas, band, 6, palette.ink);
    for (final x in const [37.0, 127.0]) {
      final cup = Path()
        ..addRRect(
          RRect.fromLTRBR(x, 70, x + 16, 98, const Radius.circular(7)),
        );
      _fill(canvas, cup, palette.ink);
      if (rim != null) {
        canvas.drawPath(
          cup,
          Paint()
            ..color = rim
            ..style = PaintingStyle.stroke
            ..strokeWidth = _rimWidth,
        );
      }
      _fill(
        canvas,
        Path()..addRRect(
          RRect.fromLTRBR(
            x + 4.5,
            76,
            x + 11.5,
            92,
            const Radius.circular(3.5),
          ),
        ),
        palette.scarf,
      );
    }
  }

  void _key(Canvas canvas, Offset hand) {
    final Offset(dx: x, dy: y) = hand;
    canvas.drawCircle(
      Offset(x + 6, y - 33),
      6.5,
      Paint()
        ..color = palette.scarf
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(x + 5, y - 26.5)
        ..lineTo(x + 2, y - 9)
        ..moveTo(x + 4, y - 20)
        ..lineTo(x + 9.5, y - 19)
        ..moveTo(x + 3.2, y - 14.5)
        ..lineTo(x + 8, y - 13.7),
      4,
      palette.scarf,
    );
  }

  void _phone(Canvas canvas) {
    _fill(
      canvas,
      Path()..addRRect(
        RRect.fromLTRBR(72, 112, 108, 162, const Radius.circular(8)),
      ),
      palette.ink,
    );
    _fill(
      canvas,
      Path()..addRRect(
        RRect.fromLTRBR(75.5, 117, 104.5, 155, const Radius.circular(4)),
      ),
      palette.belly,
    );
    _fill(
      canvas,
      Path()
        ..moveTo(86, 129)
        ..lineTo(96, 135.5)
        ..lineTo(86, 142)
        ..close(),
      palette.body,
    );
  }

  // ---- primitives ----------------------------------------------------------

  /// Fills [path]; with [rim], also strokes it so the rim extends outward.
  void _fill(Canvas canvas, Path path, Color color, {bool rim = false}) {
    canvas.drawPath(path, Paint()..color = color);
    if (rim) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _rimWidth * 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _stroke(Canvas canvas, Path path, double width, Color color) =>
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

  static void _rotate(Canvas canvas, double degrees, Offset pivot) => canvas
    ..translate(pivot.dx, pivot.dy)
    ..rotate(degrees * math.pi / 180)
    ..translate(-pivot.dx, -pivot.dy);

  static Path _oval(double cx, double cy, double rx, double ry) => Path()
    ..addOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
    );

  static Path _sparkle(double x, double y, double s) => Path()
    ..moveTo(x, y - s)
    ..quadraticBezierTo(x, y, x + s, y)
    ..quadraticBezierTo(x, y, x, y + s)
    ..quadraticBezierTo(x, y, x - s, y)
    ..quadraticBezierTo(x, y, x, y - s)
    ..close();

  static final _bodyPath = Path()
    ..addRRect(RRect.fromLTRBR(46, 38, 134, 160, const Radius.circular(44)));

  static final _bubblePath = Path()
    ..moveTo(94, 6)
    ..lineTo(106, 6)
    ..quadraticBezierTo(116, 6, 116, 16)
    ..quadraticBezierTo(116, 26, 106, 26)
    ..lineTo(99, 26)
    ..lineTo(89, 41)
    ..lineTo(92, 26)
    ..quadraticBezierTo(84, 26, 84, 16)
    ..quadraticBezierTo(84, 6, 94, 6)
    ..close();

  static final _tailPath = Path()
    ..moveTo(114, 112)
    ..lineTo(127, 109)
    ..quadraticBezierTo(134, 123, 137, 137)
    ..quadraticBezierTo(131, 142, 124, 137)
    ..quadraticBezierTo(119, 124, 114, 112)
    ..close();

  @override
  bool shouldRepaint(MascotPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.palette != palette ||
      oldDelegate.prop != prop ||
      oldDelegate.frame != frame;
}
