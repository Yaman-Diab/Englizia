import 'dart:math' as math;

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

  /// Things leaving: slow start, gone at full speed. Same as CSS `ease-in`.
  static const easeIn = Curves.easeIn;

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

  /// «أنا» (Me v2 design): the band's waves drift once on the day's first
  /// view, the flame beats and the freeze capsule shines; the week's bars
  /// grow one after another; the current island's ring pulses; a new track
  /// is told for a while; a copy says so for a while.
  static const meWaves = Duration(milliseconds: 3200);
  static const meWavesCurve = Cubic(.3, .6, .4, 1);
  static const meFlameBeat = Duration(milliseconds: 900);
  static const meShine = Duration(milliseconds: 700);
  static const meShineDelay = Duration(milliseconds: 750);
  static const meBarGrow = slow;
  static const meIslandPulse = Duration(milliseconds: 1800);
  static const meSwitchHold = Duration(milliseconds: 2600);

  /// How long a «نُسخ» stays before it is a copy button again.
  static const copiedHold = Duration(seconds: 2);

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

  // Home Archipelago (design "Home Archipelago", its motion notes M1–M14).

  /// The prototype's `e`: cards, the bubble's tail, the review box, the pull
  /// returning, the new island growing, the level card rising, «تابع».
  static const homeEmphasis = Cubic(0.2, 0.8, 0.2, 1);

  /// The goal ring's arc filling on the day's opening.
  static const homeRingIn = Cubic(0.16, 1, 0.3, 1);

  /// The bubble and the back button popping in.
  static const homePop = Cubic(0.34, 1.56, 0.64, 1);

  /// The flame turning over on the goal, a done unit's flag rising.
  static const homeFlip = Cubic(0.3, 1.3, 0.6, 1);

  /// The streak's number rolling to the next.
  static const homeRoll = Cubic(0.3, 1.4, 0.6, 1);

  /// Every flight of the guide across the screen.
  static const homeFlight = Curves.fastOutSlowIn;

  /// Programmatic scrolls and the unit's camera (easeInOutCubic, exact).
  static const homeScrollCurve = _PowerInOut(3);

  /// Rows of stones moving, a bridge drawing (easeInOutQuad, exact).
  static const homeRowsCurve = _PowerInOut(2);

  /// The header snapping open or shut (easeOutCubic, exact).
  static const homeSnapCurve = _PowerOut(3);

  /// The day's opening (M1): the map fades in, then each island rises, one
  /// after another, from [homeRiseDistance] below.
  static const homeMapFade = Duration(milliseconds: 200);
  static const homeIsleRise = Duration(milliseconds: 320);
  static const homeIsleDelay = Duration(milliseconds: 80);
  static const homeIsleStagger = Duration(milliseconds: 60);
  static const homeTrailDraw = Duration(milliseconds: 400);
  static const homeRingFill = Duration(milliseconds: 600);
  static const homeGuideIn = Duration(milliseconds: 380);
  static const homeBubblePop = Duration(milliseconds: 300);
  static const homeBoxIn = Duration(milliseconds: 260);
  static const homeRiseDistance = 16.0;

  /// The guide rising into the ring on the opening, from this far below.
  static const homeGuideInRise = 14.0;

  /// The bubble pops from this scale; the review box rises this far.
  static const homeBubbleFrom = 0.85;
  static const homeBoxRise = 8.0;

  /// Ambient loops (M2), each one leg: the current stone's pulse to
  /// [homePulseScale], the guide's breath, the review box floating
  /// [homeBoxFloatDistance], the waves' drift, a cloud's drift [homeFogDrift],
  /// a flag's wave [homeFlagSkew] degrees, the flame's wobble [homeFlameTilt]
  /// degrees. At most [homeMaxLoops] run at once.
  static const homePulse = Duration(milliseconds: 800);
  static const homePulseScale = 1.06;
  static const homeBreath = Duration(milliseconds: 3200);
  static const homeBreathLift = 1.5;
  static const homeBoxFloat = Duration(milliseconds: 1600);
  static const homeBoxFloatDistance = 3.0;
  static const homeWaves = Duration(milliseconds: 8000);
  static const homeFog = Duration(milliseconds: 3000);
  static const homeFogDrift = 6.0;
  static const homeFlag = Duration(milliseconds: 700);
  static const homeFlagSkew = 6.0;
  static const homeFlame = Duration(milliseconds: 700);
  static const homeFlameTilt = 4.0;
  static const homeMaxLoops = 3;

  /// The back button's guide blinks for [homeBlink], every [homeBlinkMin] plus
  /// up to [homeBlinkJitter].
  static const homeBlink = Duration(milliseconds: 140);
  static const homeBlinkMin = Duration(milliseconds: 4000);
  static const homeBlinkJitter = Duration(milliseconds: 2000);

  /// A press (M3): a stone shrinks to [homeStonePress]; a stone that can't
  /// open shakes by [homeStoneShakeOffsets]; its card grows from
  /// [homeCardFrom].
  static const homePress = Duration(milliseconds: 100);
  static const homeStonePress = 0.94;
  static const homeStoneShake = Duration(milliseconds: 200);
  static const homeStoneShakeOffsets = [0.0, -2.0, 2.0, 0.0];
  static const homeCardPop = Duration(milliseconds: 220);
  static const homeCardFrom = 0.86;

  /// «تابع» (M4): the bubble's rect grows to the screen under a blue cover.
  static const homeContainer = Duration(milliseconds: 350);
  static const homeCover = Duration(milliseconds: 420);

  /// Back from a lesson, the celebration starts this long after home shows.
  static const homeReturnDelay = Duration(milliseconds: 140);

  /// A lesson done (M5): the guide flies to the stone, the stone pops from
  /// [homeStonePopFrom] past [homeStonePopPeak], sparks burst one
  /// [homeSparkStep] apart, the guide hops [homeHopHeight] to the next stone,
  /// the tail slides, the content swaps, the guide flies home.
  static const homeFlyToStone = Duration(milliseconds: 360);
  static const homeStonePop = Duration(milliseconds: 360);
  static const homeStonePopFrom = 0.7;
  static const homeStonePopPeak = 1.12;
  static const homeSparks = Duration(milliseconds: 620);
  static const homeSparkStep = Duration(milliseconds: 20);
  static const homeHop = Duration(milliseconds: 420);
  static const homeHopHeight = 22.0;
  static const homeTail = Duration(milliseconds: 300);
  static const homeTailSide = Duration(milliseconds: 200);
  static const homeContentOut = Duration(milliseconds: 160);
  static const homeContentIn = Duration(milliseconds: 220);
  static const homeFlyHome = Duration(milliseconds: 380);

  /// A flight's path rises this far above its higher end.
  static const homeFlightApex = 36.0;

  /// The rows of stones moving when the current one starts a new row.
  static const homeRows = Duration(milliseconds: 300);
  static const homeSaturation = Duration(milliseconds: 600);
  static const homeStoneColor = Duration(milliseconds: 300);
  static const homeRingColor = Duration(milliseconds: 350);

  /// The goal reached: the guide jumps [homeGuideJumpHeight], the flame turns
  /// over and the streak rolls.
  static const homeGuideJump = Duration(milliseconds: 460);
  static const homeGuideJumpHeight = 14.0;
  static const homeFlameFlip = Duration(milliseconds: 520);
  static const homeStreakRoll = Duration(milliseconds: 340);

  /// A unit done (M6): the flag rises, the bridge draws, the camera moves,
  /// the fog clears and the lock opens, the guide crosses, the new island
  /// grows from [homeIsleFrom]; it all ends at [homeUnitEnd].
  static const homeFlagRise = Duration(milliseconds: 520);
  static const homeBridge = Duration(milliseconds: 600);
  static const homeCamera = Duration(milliseconds: 1000);
  static const homeFogClear = Duration(milliseconds: 500);
  static const homeLockOpen = Duration(milliseconds: 420);
  static const homeBridgeFlight = Duration(milliseconds: 600);
  static const homeIsleGrow = Duration(milliseconds: 360);
  static const homeIsleFrom = 0.82;
  static const homeUnitEnd = Duration(milliseconds: 1950);

  /// A level done (M7): the horizon opens, then the card rises
  /// [homeLevelCardRise].
  static const homeHorizon = Duration(milliseconds: 600);
  static const homeLevelCardIn = Duration(milliseconds: 300);
  static const homeLevelCardRise = 12.0;

  /// Scrolling (M8): the header snaps after a pause, the guide hops between
  /// the ring and the stone, the waves move at [homeWaveParallax] the speed.
  static const homeSnapDelay = Duration(milliseconds: 140);
  static const homeSnap = Duration(milliseconds: 180);
  static const homeModeHop = Duration(milliseconds: 340);
  static const homeWaveParallax = 0.35;

  /// A notice card closing: the map comes up, the guide flies to the ring.
  static const homeCardClose = Duration(milliseconds: 260);
  static const homeCardHop = Duration(milliseconds: 300);

  /// The level's bar growing to its share.
  static const homeBarGrow = Duration(milliseconds: 600);

  /// The back-to-lesson button: the guide flies in and the button pops, it
  /// glances twice then every [homeBackGlanceEvery], turns with the scroll,
  /// presses, scrolls to the lesson, lands after [homeBackLandDelay], hides.
  static const homeBackFly = Duration(milliseconds: 240);
  static const homeBackPop = Duration(milliseconds: 220);
  static const homeBackGlance2 = Duration(milliseconds: 440);
  static const homeBackGlance = Duration(milliseconds: 260);
  static const homeBackGlanceEvery = Duration(milliseconds: 5000);
  static const homeBackTurn = Duration(milliseconds: 180);
  static const homeBackPress = Duration(milliseconds: 180);
  static const homeBackScroll = Duration(milliseconds: 450);
  static const homeBackLand = Duration(milliseconds: 320);
  static const homeBackLandDelay = Duration(milliseconds: 120);
  static const homeBackHide = Duration(milliseconds: 150);

  /// A locked island tapped (M9): it shakes by [homeIslandShakeOffsets], says
  /// when it opens for [homeToastHold], then its preview opens.
  static const homeShake = Duration(milliseconds: 360);
  static const homeIslandShakeOffsets = [
    0.0,
    -4.0,
    4.0,
    -4.0,
    4.0,
    -4.0,
    4.0,
    0.0,
  ];
  static const homeToastHold = Duration(milliseconds: 700);

  /// Going to an island or a page: the scroll, the pause before the pulse,
  /// the pause after the search sheet, the double pulse, the highlight.
  static const homeGoScroll = Duration(milliseconds: 500);
  static const homeGoDelay = Duration(milliseconds: 160);
  static const homeSearchDelay = Duration(milliseconds: 200);
  static const homeDoublePulse = Duration(milliseconds: 760);
  static const homeHitHold = Duration(milliseconds: 2400);

  /// Switching track (M11): the map fades out, the new one loads for at
  /// least [homeSwitchGap], then fades in.
  static const homeSwitchOut = Duration(milliseconds: 150);
  static const homeSwitchGap = Duration(milliseconds: 160);
  static const homeSwitchIn = Duration(milliseconds: 300);

  /// Pull to refresh (M12): the pull follows the finger at [homePullFactor]
  /// up to [homePullMax]; the hanging guide shows from [homePullGuideAt];
  /// letting go past [homePullThreshold] holds at [homePullHoldAt], spins,
  /// holds and goes back.
  static const homePullSpin = Duration(milliseconds: 650);
  static const homePullHold = Duration(milliseconds: 900);
  static const homePullBack = Duration(milliseconds: 350);
  static const homePullMax = 110.0;
  static const homePullFactor = 0.55;
  static const homePullGuideAt = 30.0;
  static const homePullThreshold = 70.0;
  static const homePullHoldAt = 72.0;

  /// The guide tapped in the ring: it waves, and says how the goal stands.
  static const homeWaveHold = Duration(milliseconds: 1400);
  static const homeSayHold = Duration(milliseconds: 2000);

  /// Kids (M14): the guide says the new unit's name, or again on a tap.
  static const homeKidSay = Duration(milliseconds: 2600);
  static const homeKidReplay = Duration(milliseconds: 2200);

  /// The loading skeleton's shimmer, and how long "couldn't refresh" stays.
  static const homeShimmer = Duration(milliseconds: 1300);
  static const homeFailedHold = Duration(seconds: 4);

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

/// The design's own in-out of power [power]: `2^(p−1)·k^p` up to the middle,
/// then its mirror. Flutter's named cubics only come close.
final class _PowerInOut extends Curve {
  const _PowerInOut(this.power);

  final int power;

  @override
  double transformInternal(double t) => t < .5
      ? (math.pow(2, power - 1) * math.pow(t, power)).toDouble()
      : 1.0 - math.pow(-2 * t + 2, power) / 2;
}

/// The design's own ease-out of power [power]: `1 − (1 − k)^p`.
final class _PowerOut extends Curve {
  const _PowerOut(this.power);

  final int power;

  @override
  double transformInternal(double t) => 1.0 - math.pow(1 - t, power).toDouble();
}
