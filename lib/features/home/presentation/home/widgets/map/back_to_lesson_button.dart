import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot_palette.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/read_order.dart';
import 'package:flutter/material.dart';

/// Which way the current lesson is from the screen: [up] above it (the
/// learner scrolled toward later units), [down] below.
enum BackDirection { up, down }

/// The guide's face in a circle at the bottom of the end side, looking
/// toward the current lesson when it is off screen (board 07أ): a tap
/// takes the map back to it. The eyes alone say which way; there is no
/// arrow.
///
/// A [direction] shows it (it pops in), a change turns the face, null hides
/// it. Under reduce motion it only fades.
class BackToLessonButton extends StatefulWidget {
  const BackToLessonButton({
    required this.direction,
    required this.kids,
    required this.lessonTitle,
    required this.reviewFirst,
    required this.arrivedByFlight,
    required this.onPressed,
    super.key,
  });

  /// Null hides it.
  final BackDirection? direction;
  final bool kids;

  /// The current lesson, for the screen reader.
  final String lessonTitle;

  /// The review is the current stop: «راجع اليوم».
  final bool reviewFirst;

  /// The guide flew into it: it looks around twice as it lands.
  final bool arrivedByFlight;

  /// Scrolls back to the lesson; the button ticks the phone first.
  final VoidCallback onPressed;

  /// 56, kids 64.
  static double sizeOf({required bool kids}) => kids ? 64 : 56;

  /// Where it stands: [endInset] from the end, [bottomInset] above the tab
  /// bar.
  static const endInset = 18.0;
  static const bottomInset = 20.0;

  @override
  State<BackToLessonButton> createState() => _BackToLessonButtonState();
}

class _BackToLessonButtonState extends State<BackToLessonButton>
    with TickerProviderStateMixin {
  late final _presence = AnimationController(vsync: this)
    ..addStatusListener(_presenceChanged);
  late final _press = AnimationController(
    vsync: this,
    duration: AppMotion.homeBackPress,
  );

  /// 0 looking up, 1 down.
  late final _turn = AnimationController(
    vsync: this,
    duration: AppMotion.homeBackTurn,
  );
  late final _glance = AnimationController(vsync: this);
  late final _blink = AnimationController(
    vsync: this,
    duration: AppMotion.homeBlink,
  );
  final _random = math.Random();
  final _timers = <Timer>[];

  /// What the face shows; kept while it hides.
  BackDirection? _shown;
  var _hiding = false;
  var _twice = false;
  var _glances = 0;
  var _started = false;

  static const _glancesAfterLanding = 3;

  bool get _reduce => AppMotion.reduceMotion(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.direction != null) _appear();
  }

  @override
  void didUpdateWidget(BackToLessonButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final direction = widget.direction;
    if (direction == oldWidget.direction) return;
    if (direction == null) {
      _hide();
    } else if (_shown == null || _hiding) {
      _appear();
    } else {
      _shown = direction;
      final target = direction == BackDirection.down ? 1.0 : 0.0;
      if (_reduce) {
        _turn.value = target;
      } else {
        _turn.animateTo(target, curve: AppMotion.out);
      }
      _idle(glanceTwice: false);
    }
  }

  void _appear() {
    final direction = widget.direction!;
    _hiding = false;
    if (_shown == null) _turn.value = direction == BackDirection.down ? 1 : 0;
    _shown = direction;
    _presence.duration = _reduce ? AppMotion.quick : AppMotion.homeBackPop;
    _presence.forward(from: _presence.value == 1 ? 0 : _presence.value);
    _idle(glanceTwice: widget.arrivedByFlight);
  }

  void _hide() {
    if (_shown == null) return;
    _hiding = true;
    _cancelTimers();
    _presence.duration = _reduce ? AppMotion.quick : AppMotion.homeBackHide;
    _presence.reverse();
    setState(() {});
  }

  void _presenceChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _hiding && mounted) {
      setState(() {
        _hiding = false;
        _shown = null;
      });
    }
  }

  /// Blinks now and then; glances every few seconds, three times; the
  /// landing's double glance first.
  void _idle({required bool glanceTwice}) {
    _cancelTimers();
    _glances = 0;
    if (_reduce) return;
    if (glanceTwice) {
      // The double glance follows the landing, as long as the flight in.
      _after(AppMotion.homeBackFly, () => _look(twice: true));
    }
    _nextBlink();
    _nextGlance();
  }

  void _nextBlink() {
    final jitter =
        AppMotion.homeBlinkJitter.inMilliseconds * _random.nextDouble();
    _after(AppMotion.homeBlinkMin + Duration(milliseconds: jitter.round()), () {
      _blink.forward(from: 0);
      _nextBlink();
    });
  }

  void _nextGlance() => _after(AppMotion.homeBackGlanceEvery, () {
    if (_glances >= _glancesAfterLanding) return;
    _glances++;
    _look(twice: false);
    _nextGlance();
  });

  void _look({required bool twice}) {
    _twice = twice;
    _glance
      ..duration = twice ? AppMotion.homeBackGlance2 : AppMotion.homeBackGlance
      ..forward(from: 0);
  }

  void _after(Duration delay, VoidCallback run) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (mounted) run();
    });
    _timers.add(timer);
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _tap() {
    if (!_reduce) _press.forward(from: 0);
    AppHaptics.lightImpact();
    widget.onPressed();
  }

  @override
  void dispose() {
    _cancelTimers();
    _presence.dispose();
    _press.dispose();
    _turn.dispose();
    _glance.dispose();
    _blink.dispose();
    super.dispose();
  }

  /// The circle's scale and opacity as it pops in (.6 → 1.06 at .7 → 1,
  /// eased by the pop) or shrinks away (to .6, eased in).
  ({double scale, double opacity}) _presenceFrame(double t) {
    if (_reduce) return (scale: 1, opacity: AppMotion.out.transform(t));
    if (_hiding) {
      final e = AppMotion.easeIn.transform(1 - t);
      return (scale: lerpDouble(1, _from, e)!, opacity: 1 - e);
    }
    if (t >= 1) return (scale: 1, opacity: 1);
    final e = AppMotion.homePop.transform(t);
    if (e <= _peakAt) {
      final k = e / _peakAt;
      return (scale: lerpDouble(_from, _peak, k)!, opacity: k);
    }
    return (
      scale: lerpDouble(_peak, 1, (e - _peakAt) / (1 - _peakAt))!,
      opacity: 1,
    );
  }

  static const _from = .6;
  static const _peak = 1.06;
  static const _peakAt = .7;

  /// 1 → .94 at .45 → 1, eased out.
  double _pressScale(double t) {
    if (t <= 0 || t >= 1) return 1;
    final e = AppMotion.out.transform(t);
    const low = .45;
    return e <= low
        ? lerpDouble(1, AppMotion.homeStonePress, e / low)!
        : lerpDouble(AppMotion.homeStonePress, 1, (e - low) / (1 - low))!;
  }

  /// How far the glance has looked, 0 → 1 → 0 (twice: at .22 and .72).
  double _glanceAt(double t) {
    if (t <= 0 || t >= 1) return 0;
    final e = AppMotion.inOut.transform(t);
    double leg(double from, double to, double a, double b) =>
        lerpDouble(a, b, (e - from) / (to - from))!;
    if (!_twice) return e <= .4 ? leg(0, .4, 0, 1) : leg(.4, 1, 1, 0);
    if (e <= .22) return leg(0, .22, 0, 1);
    if (e <= .5) return leg(.22, .5, 1, 0);
    if (e <= .72) return leg(.5, .72, 0, 1);
    return leg(.72, 1, 1, 0);
  }

  /// 1 → .1 at .5 → 1, linear.
  double _blinkAt(double t) {
    if (t <= 0 || t >= 1) return 1;
    return t <= .5
        ? lerpDouble(1, .1, t / .5)!
        : lerpDouble(.1, 1, (t - .5) / .5)!;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final size = BackToLessonButton.sizeOf(kids: widget.kids);
    if (shown == null) return SizedBox.square(dimension: size);
    final colors = context.colors;
    final scheme = context.scheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = MascotPalette.of(Theme.of(context).brightness);
    final title = widget.reviewFirst
        ? 'home_review_title'.tr()
        : widget.lessonTitle;
    final circle = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(color: scheme.outline),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: dark ? .4 : .14),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_turn, _glance, _blink]),
        builder: (context, _) => CustomPaint(
          size: Size.square(size),
          painter: BackFacePainter(
            pose: BackFacePose.at(
              _turn.value,
              glance: _glanceAt(_glance.value),
              up: shown == BackDirection.up,
            ),
            blink: _blinkAt(_blink.value),
            palette: palette,
          ),
        ),
      ),
    );
    return IgnorePointer(
      ignoring: _hiding,
      child: ExcludeSemantics(
        excluding: _hiding,
        child: Semantics(
          button: true,
          sortKey: HomeReadOrder.back,
          label: 'home_back_semantics'.tr(args: [title]),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: Listenable.merge([_presence, _press]),
                builder: (context, child) {
                  final frame = _presenceFrame(_presence.value);
                  return Opacity(
                    opacity: frame.opacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: frame.scale * _pressScale(_press.value),
                      child: child,
                    ),
                  );
                },
                child: SizedBox.square(dimension: size, child: circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the face looks: [turn] 0 up … 1 down, plus a [glance] toward it.
@immutable
final class BackFacePose {
  const BackFacePose({
    required this.faceDy,
    required this.tilt,
    required this.glanceDy,
    required this.pupilDy,
    required this.lid,
  });

  /// The face and pupils shift 2.5 toward the look and the face tilts 4°;
  /// looking down, the lids come half down. A glance adds
  /// 1.6 to the face and .9 to the pupils, toward the look.
  factory BackFacePose.at(double turn, {double glance = 0, required bool up}) {
    final toward = up ? -1.0 : 1.0;
    return BackFacePose(
      faceDy: lerpDouble(-_shift, _shift, turn)!,
      tilt: lerpDouble(-_tilt, _tilt, turn)! * math.pi / 180,
      glanceDy: toward * _faceGlance * glance,
      pupilDy:
          lerpDouble(-_shift, _shift, turn)! + toward * _pupilGlance * glance,
      lid: turn.clamp(0.0, 1.0),
    );
  }

  static const _shift = 2.5;
  static const _tilt = 4.0;
  static const _faceGlance = 1.6;
  static const _pupilGlance = .9;

  /// The whole face, about (28, 34) of the drawing.
  final double faceDy;

  /// Radians.
  final double tilt;

  /// The glance's own shift, inside the tilted face.
  final double glanceDy;
  final double pupilDy;

  /// How far the lids are down: 0 open, 1 half closed.
  final double lid;
}

/// The face in the back button, drawn from the design's 54 viewBox (from
/// 1, 1) inside the 1-px border, in the guide's own colours.
class BackFacePainter extends CustomPainter {
  const BackFacePainter({
    required this.pose,
    required this.blink,
    required this.palette,
  });

  final BackFacePose pose;

  /// The eyes' height, 1 open … .1 shut.
  final double blink;
  final MascotPalette palette;

  static const _eyes = [21.6, 34.4];
  static const _eyeY = 27.5;
  static const _lidTop = 20.6;
  static const _lidHeight = 6.4;

  @override
  void paint(Canvas canvas, Size size) {
    final s = (size.width - 2) / 54;
    canvas
      ..save()
      ..translate(1, 1)
      ..scale(s)
      ..translate(-1, -1)
      ..clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(28, 28), radius: 27)),
      )
      // The face turns about its middle; the glance moves inside it.
      ..translate(28, 34)
      ..translate(0, pose.faceDy)
      ..rotate(pose.tilt)
      ..translate(-28, -34)
      ..translate(0, pose.glanceDy);

    final fill = Paint()..style = PaintingStyle.fill;
    final crest = Path()
      ..moveTo(32.5, 4.5)
      ..relativeLineTo(7, 0)
      ..relativeArcToPoint(
        const Offset(0, 7.2),
        radius: const Radius.circular(3.6),
      )
      ..relativeLineTo(-3.4, 0)
      ..relativeLineTo(-4.6, 4.3)
      ..relativeLineTo(.9, -4.3)
      ..relativeArcToPoint(
        const Offset(.1, -7.2),
        radius: const Radius.circular(3.6),
      )
      ..close();
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(9, 13, 38, 58),
      const Radius.circular(19),
    );
    final outline = palette.outline;
    if (outline != null) {
      // A light rim under the fill keeps the shape on dark ground.
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = outline;
      canvas
        ..drawPath(crest, rim)
        ..drawRRect(body, rim);
    }
    canvas
      ..drawPath(crest, fill..color = palette.body)
      ..drawRRect(body, fill..color = palette.body)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(7.5, 45, 41, 7),
          const Radius.circular(3.5),
        ),
        fill..color = palette.scarf,
      )
      ..drawCircle(
        const Offset(41, 48.5),
        3.6,
        fill..color = palette.scarfDeep,
      );
    final blush = Paint()..color = palette.blush.withValues(alpha: .9);
    for (final cx in const [13.6, 42.4]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 37.2), width: 6.2, height: 4),
        blush,
      );
    }

    // The eyes blink about their middle.
    canvas
      ..save()
      ..translate(28, 27.2)
      ..scale(1, blink)
      ..translate(-28, -27.2);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.ink
      ..strokeCap = StrokeCap.round;
    Rect eye(double cx) =>
        Rect.fromCenter(center: Offset(cx, _eyeY), width: 11.4, height: 12.6);
    for (final cx in _eyes) {
      canvas
        ..drawOval(eye(cx), fill..color = palette.highlight)
        ..drawOval(eye(cx), ink..strokeWidth = 1.5);
    }
    canvas
      ..save()
      ..translate(0, pose.pupilDy);
    for (final cx in _eyes) {
      canvas
        ..drawCircle(Offset(cx, _eyeY), 3.2, fill..color = palette.ink)
        ..drawCircle(
          Offset(cx + 1.1, 26.3),
          1.05,
          fill..color = palette.highlight,
        );
    }
    canvas.restore();
    for (final cx in _eyes) {
      final lidY = _lidTop + _lidHeight * pose.lid;
      canvas
        ..save()
        ..clipPath(Path()..addOval(eye(cx)));
      if (pose.lid > 0) {
        canvas.drawRect(
          Rect.fromLTWH(cx - 6.5, _lidTop, 13, _lidHeight * pose.lid),
          fill..color = palette.body,
        );
      }
      canvas
        ..drawLine(
          Offset(cx - 6.5, lidY),
          Offset(cx + 6.5, lidY),
          ink..strokeWidth = 1.7,
        )
        ..restore();
    }
    canvas.restore();

    canvas
      ..drawPath(
        Path()
          ..moveTo(24.8, 39.4)
          ..relativeQuadraticBezierTo(3.2, 3, 6.4, 0),
        ink..strokeWidth = 2,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(BackFacePainter oldDelegate) =>
      oldDelegate.pose.faceDy != pose.faceDy ||
      oldDelegate.pose.tilt != pose.tilt ||
      oldDelegate.pose.glanceDy != pose.glanceDy ||
      oldDelegate.pose.pupilDy != pose.pupilDy ||
      oldDelegate.pose.lid != pose.lid ||
      oldDelegate.blink != blink ||
      oldDelegate.palette != palette;
}
