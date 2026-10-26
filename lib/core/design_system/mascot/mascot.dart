import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_motion.dart';
import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/mascot/mascot_motion.dart';
import 'package:englizia/core/design_system/mascot/mascot_painter.dart';
import 'package:englizia/core/design_system/mascot/mascot_palette.dart';
import 'package:englizia/core/design_system/mascot/mascot_pose.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

export 'mascot_expression.dart'
    show MascotExpression, MascotFraming, MascotProp;

/// The app's guide character ("بلبل" for now; the name lives in the
/// `mascot_name` translation key). Drawn in code, so it is sharp at any size,
/// follows light and dark mode, and costs no image assets.
///
/// Changing [expression] moves the arms over [AppMotion.characterPose]. With
/// [animate] it floats and blinks, and with [waving] it waves its right arm.
/// All motion stops when the platform asks to reduce motion.
class Mascot extends StatefulWidget {
  const Mascot({
    this.expression = MascotExpression.welcome,
    this.prop = MascotProp.none,
    this.framing = MascotFraming.full,
    this.size = 160,
    this.animate = true,
    this.waving = false,
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
    curve: AppMotion.smoothOut,
  );

  MascotPose? _from;
  late MascotPose _target = widget.expression.pose;

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
      _target = widget.expression.pose;
      if (AppMotion.reduceMotion(context)) {
        _from = null;
      } else {
        _from = shown;
        _poseChange.forward(from: 0);
      }
    }
    _syncIdle();
  }

  MascotPose get _shownPose {
    final from = _from;
    if (from == null || _poseChange.isCompleted) return _target;
    return MascotPose.lerpGeometry(from, _target, _poseCurve.value);
  }

  void _syncIdle() {
    final run = widget.animate && !AppMotion.reduceMotion(context);
    if (run && !_idle.isActive) {
      _idle.start();
    } else if (!run && _idle.isActive) {
      _idle.stop();
      _frame.value = MascotFrame.still;
    }
  }

  void _onTick(Duration elapsed) =>
      _frame.value = MascotFrame.at(elapsed, waving: widget.waving);

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
    final palette = MascotPalette.of(Theme.of(context).brightness);
    return Semantics(
      image: true,
      label: widget.semanticLabel ?? 'mascot_name'.tr(),
      child: AnimatedBuilder(
        animation: _poseChange,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: MascotPainter(
            pose: _shownPose,
            palette: palette,
            prop: widget.prop,
            framing: widget.framing,
            frame: _frame,
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
