import 'package:flutter/widgets.dart';

/// Motion scale for every animation in the app: durations, curves, distances
/// and scales. Read the values from here; never hardcode a `Duration` or curve
/// in a widget.
///
/// Values adapted from the transitions.dev motion tokens (free transitions,
/// used under its license; see docs/adr/0007-motion-tokens.md). Blur tokens
/// are left out on purpose: blur is costly on the low-end Android phones most
/// of the audience uses.
///
/// Respect the user's reduce-motion setting with [resolve] or [reduceMotion].
abstract final class AppMotion {
  /// Offset between items in a staggered list.
  static const stagger = Duration(milliseconds: 40);

  /// Short delays and the segments of an error shake.
  static const micro = Duration(milliseconds: 80);

  /// Closing a sheet or menu, swapping text, showing a tooltip.
  static const quick = Duration(milliseconds: 150);

  /// Opening a sheet or menu, icon swap, sliding tabs, page slide.
  static const fast = Duration(milliseconds: 250);

  /// Closing a panel or toast.
  static const medium = Duration(milliseconds: 350);

  /// Opening a panel, revealing loaded content.
  static const slow = Duration(milliseconds: 400);

  /// Emphasis: success check, badge appearing, text reveal.
  static const verySlow = Duration(milliseconds: 500);

  /// Fast start, soft landing. Default for anything that opens, closes or
  /// moves position. CSS `cubic-bezier(0.22, 1, 0.36, 1)`.
  static const smoothOut = Cubic(0.22, 1, 0.36, 1);

  /// Cross-fades in place (icon swap, text swap). Same as CSS `ease-in-out`.
  static const inOut = Curves.easeInOut;

  /// Tooltips. Same as CSS `ease-out`.
  static const out = Curves.easeOut;

  /// Loops: shimmer, skeleton pulse, spinner.
  static const linear = Curves.linear;

  /// Small overshoot for things that pop in (badge, star).
  /// CSS `cubic-bezier(0.34, 1.36, 0.64, 1)`.
  static const bounce = Cubic(0.34, 1.36, 0.64, 1);

  /// Slow symmetric in-out for floating loops. CSS `cubic-bezier(.45, 0, .55, 1)`.
  static const float = Cubic(0.45, 0, 0.55, 1);

  /// Idle loops of the guide character, from the welcome screen design:
  /// one wave per [characterWave], a float per [characterFloat], a blink per
  /// [characterBlink].
  static const characterWave = Duration(milliseconds: 2800);
  static const characterFloat = Duration(milliseconds: 3200);
  static const characterBlink = Duration(milliseconds: 4000);

  /// Float cycles of calmer (sleep, understand) and livelier (happy,
  /// encourage) expressions, after the onboarding designs' moods.
  static const characterFloatCalm = Duration(milliseconds: 4000);
  static const characterFloatBrisk = Duration(milliseconds: 2600);
  static const characterFloatLively = Duration(milliseconds: 1800);

  /// The fastest bounce, for the most thrilled expression.
  static const characterFloatQuick = Duration(milliseconds: 800);

  /// One cycle of the small loops inside an expression: the talking dots,
  /// the drifting "z", sparkles twinkling.
  static const characterPulse = Duration(milliseconds: 1200);

  /// A change of expression: the arms settle with a small overshoot
  /// ([bounce]) and the face swaps behind a blink.
  static const characterPose = slow;

  /// How long one element of a staggered screen entrance takes to arrive.
  /// When each one starts lives in `entrance_choreography.dart`.
  static const entrance = Duration(milliseconds: 600);

  /// Travel distances in logical pixels. Not scaled with the screen.
  static const distanceMicro = 4.0;
  static const distanceSmall = 6.0;
  static const distanceBase = 8.0;
  static const distanceMedium = 12.0;
  static const distanceLarge = 30.0;

  /// Starting scale for elements that grow into place.
  static const scaleLarge = 0.96;
  static const scaleMedium = 0.97;
  static const scaleSmall = 0.98;
  static const scaleTiny = 0.99;

  /// Whether the platform asks for animations to be removed or reduced
  /// (for example Android's "Remove animations").
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or [Duration.zero] when [reduceMotion] is on: the state
  /// still changes, only the movement is dropped. Purely decorative motion
  /// (shake, bounce) should check [reduceMotion] and skip itself instead.
  static Duration resolve(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}
