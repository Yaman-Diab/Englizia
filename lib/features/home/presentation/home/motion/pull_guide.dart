import 'dart:math' as math;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:flutter/widgets.dart';

/// The guide hanging on a thread from the top bar while the map is pulled
/// (design "Home Archipelago", motion §14, header §12), stretched by the
/// pull, spinning once when let go past the threshold. It shows from
/// [AppMotion.homePullGuideAt], where the ring lets go of it (D26). Fill the
/// stage with it: it hangs from the top bar's bottom, centred.
class PullGuide extends StatefulWidget {
  const PullGuide({required this.pull, required this.spinning, super.key});

  /// How far the stage is pulled down.
  final double pull;

  /// The refresh started: the guide turns once.
  final bool spinning;

  static const size = 48.0;

  /// The thread shows once the pull passes this.
  static const threadFrom = 50.0;
  static const threadWidth = 2.0;

  /// The thread's length at [pull].
  static double thread(double pull) => math.max(0, pull - threadFrom);

  /// The guide stretches with the pull: thinner, longer.
  static ({double x, double y}) stretch(double pull) =>
      (x: 1 - pull / 1100, y: 1 + pull / 520);

  static bool shows(double pull) => pull >= AppMotion.homePullGuideAt;

  @override
  State<PullGuide> createState() => _PullGuideState();
}

class _PullGuideState extends State<PullGuide>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: AppMotion.homePullSpin,
  );
  late final _turns = CurvedAnimation(parent: _spin, curve: AppMotion.inOut);

  @override
  void didUpdateWidget(PullGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning &&
        !oldWidget.spinning &&
        !AppMotion.reduceMotion(context)) {
      _spin.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pull = widget.pull;
    if (pull <= 0 || !PullGuide.shows(pull)) return const SizedBox.shrink();
    final stretch = PullGuide.stretch(pull);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: StageMetrics.topBar),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.diagonal3Values(stretch.x, stretch.y, 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ColoredBox(
                    color: context.scheme.outline,
                    child: SizedBox(
                      width: PullGuide.threadWidth,
                      height: PullGuide.thread(pull),
                    ),
                  ),
                  RotationTransition(
                    turns: _turns,
                    child: const Mascot(
                      expression: MascotExpression.curious,
                      size: PullGuide.size,
                      animate: false,
                      sparkles: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
