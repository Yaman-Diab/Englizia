import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/read_order.dart';
import 'package:flutter/material.dart';

/// What the guide says when tapped, beside the ring (design "Home
/// Archipelago"): 6 past the ring's end edge, 26 under its top,
/// its small corner toward the ring. A live region; it fills the stage's main
/// area and shows while [text] is set and the header is open
/// ([StageMetrics.sayBubbleAllowed]).
class SayBubble extends StatelessWidget {
  const SayBubble({required this.text, required this.metrics, super.key});

  final String? text;
  final StageMetrics metrics;

  /// From the layout's end edge: the ring's 20, its 96 box and a gap of 6.
  static const end = 20.0 + StageMetrics.ringBox + 6;

  /// Under the top bar's top: the ring's top and 26.
  static const top = StageMetrics.topBar + 26;
  static const maxWidth = 150.0;

  static const _radius = Radius.circular(14);
  static const _corner = Radius.circular(4);
  static const _shadow = .08;
  static const _from = .85;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final shown = text != null && metrics.sayBubbleAllowed;
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (shown)
            PositionedDirectional(
              end: end,
              top: top + metrics.topSlot,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(text),
                  tween: Tween(begin: 0, end: 1),
                  duration: AppMotion.resolve(context, AppMotion.bubbleIn),
                  curve: AppMotion.out,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: _from + (1 - _from) * t,
                      child: child,
                    ),
                  ),
                  child: _Bubble(text: text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    return Semantics(
      liveRegion: true,
      container: true,
      sortKey: HomeReadOrder.say,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: SayBubble.maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: const BorderRadiusDirectional.only(
              topStart: SayBubble._radius,
              topEnd: SayBubble._radius,
              bottomStart: SayBubble._radius,
              bottomEnd: SayBubble._corner,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: SayBubble._shadow),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Text(
              text,
              style: context.texts
                  .sized(context.texts.captionStrong, size: 13, line: 20)
                  .copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// The guide's line when tapped: «حققت هدفك اليوم!» at the
/// goal, else «باقي 3 دقائق لهدفك».
String guideSayText({required int today, required int goal}) => today >= goal
    ? 'home_say_goal'.tr()
    : 'home_say_left'.tr(args: [minutesText(goal - today)]);

/// A tap on the ring's guide: it waves for
/// [AppMotion.homeWaveHold] and says its line for [AppMotion.homeSayHold]; a
/// new tap starts both again. The page owns it and passes [waving] to the
/// ring and [say] to the [SayBubble].
class GuideTapController extends ChangeNotifier {
  bool _waving = false;
  String? _say;
  Timer? _waveTimer;
  Timer? _sayTimer;

  bool get waving => _waving;
  String? get say => _say;

  void tap(String line) {
    _waveTimer?.cancel();
    _sayTimer?.cancel();
    _waving = true;
    _say = line;
    notifyListeners();
    _waveTimer = Timer(AppMotion.homeWaveHold, () {
      _waving = false;
      notifyListeners();
    });
    _sayTimer = Timer(AppMotion.homeSayHold, () {
      _say = null;
      notifyListeners();
    });
  }

  /// Stops both at once, as when the header folds.
  void clear() {
    _waveTimer?.cancel();
    _sayTimer?.cancel();
    if (!_waving && _say == null) return;
    _waving = false;
    _say = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _sayTimer?.cancel();
    super.dispose();
  }
}
