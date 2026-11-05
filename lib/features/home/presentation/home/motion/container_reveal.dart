import 'dart:async';

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/app_page_transitions.dart';
import 'package:englizia/features/home/presentation/home/motion/motion_timeline.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How the reveal looks at one moment: the growing card, its corners, the
/// blue over it, the whole layer's opacity.
typedef RevealFrame = ({
  Rect rect,
  double radius,
  double cover,
  double opacity,
});

/// «تابع» (design "Home Archipelago", motion §6, D22): the bubble's rect
/// grows to the screen under a blue cover that clears from 45 %; the lesson
/// opens under it with the theme's own page transition, then the layer
/// fades away. CLAUDE.md keeps per-route transitions out, so this is an
/// overlay above home, not a route.
abstract final class ContainerReveal {
  /// The bubble's corners, which square off as it grows.
  static const radius = 24.0;

  /// The cover stays solid for this share of [AppMotion.homeCover].
  static const coverHold = .45;

  /// The lesson is pushed once the card fills the screen.
  static const pushAt = AppMotion.homeContainer;

  /// The layer starts to clear once the push's transition has run
  /// ([AppPageTransitionsBuilder.transitionDuration]).
  static Duration get fadeAt =>
      pushAt + const AppPageTransitionsBuilder().transitionDuration;

  static Duration get length => fadeAt + AppMotion.quick;

  /// The reveal [t] in, from [from] to the whole of [full].
  static RevealFrame frame(
    Duration t, {
    required Rect from,
    required Size full,
  }) {
    final ms = msOf(t);
    final grow = phase(
      ms,
      Duration.zero,
      AppMotion.homeContainer,
      AppMotion.homeEmphasis,
    );
    return (
      rect: Rect.lerp(from, Offset.zero & full, grow)!,
      radius: lerp(radius, 0, grow),
      cover: keyframes(phase(ms, Duration.zero, AppMotion.homeCover), const [
        (0, 1),
        (coverHold, 1),
        (1, 0),
      ]),
      opacity: 1 - phase(ms, fadeAt, AppMotion.quick),
    );
  }

  /// Grows [from] (global coordinates: the bubble's box on the screen) to the
  /// screen, calls [push] under it, and clears once the new page is in.
  /// Under reduce motion it only calls [push] (D30).
  static Future<void> run(
    BuildContext context, {
    required Rect from,
    required VoidCallback push,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (AppMotion.reduceMotion(context) || overlay == null) {
      push();
      return;
    }
    final box = overlay.context.findRenderObject();
    final local = box is RenderBox && box.hasSize
        ? Rect.fromPoints(
            box.globalToLocal(from.topLeft),
            box.globalToLocal(from.bottomRight),
          )
        : from;
    final clock = ValueNotifier(Duration.zero);
    final done = Completer<void>();
    var pushed = false;
    late final Ticker ticker;
    final entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: ExcludeSemantics(
          child: ValueListenableBuilder(
            valueListenable: clock,
            builder: (context, t, _) => CustomPaint(
              painter: RevealPainter(
                from: local,
                t: t,
                surface: context.colors.surface,
                cover: context.colors.primaryStrong,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    ticker = Ticker((elapsed) {
      clock.value = elapsed;
      if (!pushed && elapsed >= pushAt) {
        pushed = true;
        push();
      }
      if (elapsed >= length && !done.isCompleted) done.complete();
    });
    overlay.insert(entry);
    unawaited(ticker.start());
    await done.future;
    ticker.dispose();
    entry
      ..remove()
      ..dispose();
    clock.dispose();
  }
}

/// The reveal's card over the screen at [t].
class RevealPainter extends CustomPainter {
  const RevealPainter({
    required this.from,
    required this.t,
    required this.surface,
    required this.cover,
  });

  final Rect from;
  final Duration t;
  final Color surface;
  final Color cover;

  @override
  void paint(Canvas canvas, Size size) {
    final f = ContainerReveal.frame(t, from: from, full: size);
    if (f.opacity <= 0) return;
    final shape = RRect.fromRectAndRadius(f.rect, Radius.circular(f.radius));
    canvas
      ..drawRRect(
        shape,
        Paint()..color = surface.withValues(alpha: surface.a * f.opacity),
      )
      ..drawRRect(
        shape,
        Paint()..color = cover.withValues(alpha: cover.a * f.opacity * f.cover),
      );
  }

  @override
  bool shouldRepaint(RevealPainter old) =>
      old.t != t ||
      old.from != from ||
      old.surface != surface ||
      old.cover != cover;
}
