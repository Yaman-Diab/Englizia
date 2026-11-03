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

  /// A step of a flow leaving, then the next one arriving ([SlideSwap]).
  static const stepOut = Duration(milliseconds: 110);

  /// A thank-you stays on the screen this long.
  static const toastHold = Duration(seconds: 3);

  /// What follows a word taken out closes up.
  static const closeUp = Duration(milliseconds: 200);

  /// A wrong pair stays marked this long, then the cards go back.
  static const pairWrongHold = Duration(milliseconds: 600);

  /// A right pair shows its check this long, then fades out of the way.
  static const pairLock = Duration(milliseconds: 450);

  /// From the last pair to the end of the question.
  static const pairsDone = Duration(milliseconds: 400);
  static const stepOutReduced = Duration(milliseconds: 100);

  /// A number counting up to its value (`CountUp`), slowing as it lands.
  static const countUp = Duration(milliseconds: 600);
  static const countUpCurve = Curves.easeOutCubic;

  /// The star turning once as points land (`XpAmount`).
  static const xpLanding = Duration(milliseconds: 360);

  /// One number rolling into the next (`RollingNumber`).
  static const numberRoll = Duration(milliseconds: 320);

  /// Passes its mark a little and comes back: what lands with some life.
  static const overshoot = Cubic(.3, 1.5, .6, 1);

  /// A round of the dots while the AI judges, and how far apart they go.
  static const aiDots = Duration(milliseconds: 1100);
  static const aiDotsOffset = Duration(milliseconds: 180);

  /// A new part joining a progress bar.
  static const barGrow = Duration(milliseconds: 450);

  /// ✦ glinting while the AI writes an explanation, and when the lines
  /// through the wrong words start to draw once it arrives.
  static const aiGlint = Duration(milliseconds: 1600);
  static const strikeDelay = Duration(milliseconds: 240);

  /// A bottom sheet coming up, and going down a little faster.
  static const sheetIn = Duration(milliseconds: 300);
  static const sheetOut = Duration(milliseconds: 220);

  /// A vocabulary card flying off, and the one behind coming forward.
  static const cardSwap = Duration(milliseconds: 300);

  /// A conversation (Talk design): the character's halo breathing in or out,
  /// its ring pulsing once with its voice, the microphone's ring while it
  /// records, a bubble joining, and a done task's panel staying open.
  static const characterBreath = Duration(milliseconds: 1200);
  static const voiceRing = Duration(milliseconds: 350);
  static const micRing = Duration(milliseconds: 1100);
  static const bubbleIn = Duration(milliseconds: 200);
  static const taskPanelHold = Duration(milliseconds: 1900);

  /// A done task's circle pops after the panel opens, its check after it, and
  /// the count rolls once the panel has been read.
  static const taskPop = Duration(milliseconds: 360);
  static const taskPopDelay = Duration(milliseconds: 200);
  static const taskTickDelay = Duration(milliseconds: 420);
  static const taskCountDelay = Duration(milliseconds: 900);

  /// A summary's done tasks are marked one after another, this far apart; a
  /// chosen reply flies from its card into the conversation.
  static const summaryMarkStep = Duration(milliseconds: 150);
  static const replyFlight = Duration(milliseconds: 380);

  /// A kids' lesson (Kid Lesson design): a screen sliding in, a right answer's
  /// star flying to the bar and the bar's star beating as it lands, the right
  /// card pulsing after two misses, the guide dancing at the end, and a star
  /// of the end filling.
  static const kidScreenIn = Duration(milliseconds: 360);
  static const kidStarFlight = Duration(milliseconds: 600);
  static const kidStarFlightDelay = Duration(milliseconds: 280);
  static const kidHintPulse = Duration(milliseconds: 560);
  static const kidHintDelay = Duration(milliseconds: 800);
  static const kidDance = Duration(milliseconds: 640);
  static const kidStarFill = Duration(milliseconds: 380);

  /// A unit's chain after a lesson (Unit design): its mark fills, its line
  /// grows, then the next lesson's card opens with its button. The kids'
  /// current card breathes, and a skeleton pulses while it loads.
  static const unitMarkFill = Duration(milliseconds: 380);
  static const unitLineDelay = Duration(milliseconds: 320);
  static const unitLineGrow = slow;
  static const unitMoveOn = Duration(milliseconds: 760);
  static const unitCardIn = Duration(milliseconds: 320);
  static const unitButtonDelay = Duration(milliseconds: 120);
  static const unitButtonIn = Duration(milliseconds: 280);
  static const kidCurrentPulse = Duration(milliseconds: 1600);
  static const skeletonPulse = Duration(milliseconds: 1400);

  /// One nod of the guide while it listens.
  static const characterNod = Duration(milliseconds: 900);

  /// One cycle of the small loops inside an expression: the talking dots,
  /// the drifting "z", sparkles twinkling.
  static const characterPulse = Duration(milliseconds: 1200);

  /// A change of expression: the arms settle with a small overshoot
  /// ([bounce]) and the face swaps behind a blink.
  static const characterPose = slow;

  /// One turn of `AppSpinner`, from the account designs. Essential motion
  /// (it says the app is working), so it keeps turning under reduce motion.
  static const spinnerTurn = Duration(milliseconds: 800);

  /// How long a tapped word stays highlighted, and the guide waves, after
  /// a tap (kids designs).
  static const highlightHold = Duration(milliseconds: 1500);

  /// A field that refused the input shakes this long (account designs).
  static const shake = slow;

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

  /// A status mark (a check, a cross) grows in from this (designs).
  static const scaleMark = 0.8;

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
