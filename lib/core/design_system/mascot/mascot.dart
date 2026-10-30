import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/mascot/mascot_motion.dart';
import 'package:englizia/core/design_system/mascot/mascot_painter.dart';
import 'package:englizia/core/design_system/mascot/mascot_palette.dart';
import 'package:englizia/core/design_system/mascot/mascot_pose.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

export 'mascot_expression.dart'
    show MascotExpression, MascotFraming, MascotProp;

/// The app's guide character ("بلبل" for now; the name lives in the
/// `mascot_name` translation key). Drawn in code, so it is sharp at any size,
/// follows light and dark mode, and costs no image assets.
///
/// Changing [expression] moves the arms over [AppMotion.characterPose] with a
/// small overshoot, a crouch and a blink that hides the face swap. With
/// [animate] it idles in the expression's own way (`MascotExpression.idle`:
/// float, sway, a repeated gesture, talking dots, twinkling sparkles), blinks,
/// and with [waving] it waves its right arm. [silhouette] draws the shape
/// alone. All motion stops when the platform asks to reduce motion.
class Mascot extends StatefulWidget {
  const Mascot({
    this.expression = MascotExpression.welcome,
    this.prop = MascotProp.none,
    this.framing = MascotFraming.full,
    this.size = 160,
    this.animate = true,
    this.waving = false,
    this.silhouette = false,
    this.sparkles = true,
    this.semanticLabel,
    super.key,
  });

  final MascotExpression expression;
  final MascotProp prop;
  final MascotFraming framing;

  /// Width and height in logical pixels.
  final double size;
  final bool animate;
  final bool waving;

  /// One flat color, no face or effects (the design's "الخيال").
  final bool silhouette;

  /// False leaves out the expression's sparkles: glad, without a celebration.
  final bool sparkles;

  /// Defaults to the guide's name.
  final String? semanticLabel;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  final _frame = ValueNotifier(MascotFrame.still);
  late final Ticker _idle = createTicker(_onTick);
  late final AnimationController _poseChange = AnimationController(
    vsync: this,
    duration: AppMotion.characterPose,
  );
  late final _poseCurve = CurvedAnimation(
    parent: _poseChange,
    curve: AppMotion.bounce,
  );

  MascotPose? _from;
  late MascotPose _target = widget.expression.pose;
  MascotIdle _fromIdle = MascotIdle.standard;
  late MascotIdle _targetIdle = widget.expression.idle;

  /// Float cycles so far. Advanced by each frame's time over the current
  /// period, so a change of pace never jumps the figure.
  double _floatPhase = 0;
  Duration _lastTick = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIdle();
  }

  @override
  void didUpdateWidget(Mascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      final shown = _shownPose;
      _fromIdle = _shownIdle;
      _target = widget.expression.pose;
      _targetIdle = widget.expression.idle;
      if (AppMotion.reduceMotion(context)) {
        _from = null;
        _poseChange.value = 1;
      } else {
        _from = shown;
        _poseChange.forward(from: 0);
      }
    }
    _syncIdle();
  }

  bool get _changing => _from != null && !_poseChange.isCompleted;

  MascotPose get _shownPose {
    final from = _from;
    if (from == null || _poseChange.isCompleted) return _target;
    return MascotPose.blend(
      from,
      _target,
      motion: _poseCurve.value,
      progress: _poseChange.value,
    );
  }

  MascotIdle get _shownIdle => _changing
      ? MascotIdle.lerp(_fromIdle, _targetIdle, _poseChange.value)
      : _targetIdle;

  void _syncIdle() {
    final run = widget.animate && !AppMotion.reduceMotion(context);
    if (run && !_idle.isActive) {
      _idle.start();
    } else if (!run && _idle.isActive) {
      _idle.stop();
      _lastTick = Duration.zero;
      _frame.value = MascotFrame.still;
    }
  }

  void _onTick(Duration elapsed) {
    final idle = _shownIdle;
    final step = elapsed - _lastTick;
    _lastTick = elapsed;
    if (!step.isNegative) {
      _floatPhase += step.inMicroseconds / idle.period.inMicroseconds;
    }
    _frame.value = MascotFrame.at(
      elapsed,
      waving: widget.waving,
      idle: idle,
      floatPhase: _floatPhase,
    );
  }

  @override
  void dispose() {
    _idle.dispose();
    _poseCurve.dispose();
    _poseChange.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final palette = widget.silhouette
        ? (brightness == Brightness.dark
              ? MascotPalette.silhouetteDark
              : MascotPalette.silhouette)
        : MascotPalette.of(brightness);
    return Semantics(
      image: true,
      label: widget.semanticLabel ?? 'mascot_name'.tr(),
      child: AnimatedBuilder(
        animation: _poseChange,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: MascotPainter(
            pose: widget.sparkles
                ? _shownPose
                : _shownPose.copyWith(sparkles: false),
            palette: palette,
            prop: widget.prop,
            framing: widget.framing,
            frame: _frame,
            blink: _changing ? MascotPose.changeBlink(_poseChange.value) : 0,
            stretch: _changing
                ? MascotPose.changeStretch(_poseChange.value)
                : 0,
          ),
        ),
      ),
    );
  }
}

/// The soft circle the guide stands in on hero screens (welcome).
class MascotStage extends StatelessWidget {
  const MascotStage({required this.child, this.diameter = 248, super.key});

  final Widget child;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final palette = MascotPalette.of(Theme.of(context).brightness);
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.stageRing),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              // Inset of the filled disc inside the ring, from the design.
              padding: EdgeInsets.all(diameter * 14 / 248),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.stageFill,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
