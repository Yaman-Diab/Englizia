import 'dart:ui' show Offset;

import 'package:englizia/core/design_system/mascot/mascot_motion.dart';
import 'package:englizia/core/design_system/mascot/mascot_pose.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';

/// The guide's expressions (requirements v3.0 §22), one pose and one idle
/// style each. To add one: append a value with its [MascotPose] and give it
/// an [idle]; nothing else changes.
enum MascotExpression {
  welcome(
    MascotPose(
      rightArm: MascotArm(Offset(126, 112), Offset(150, 76)),
      rightHand: MascotHand.wave,
      brows: MascotBrows.up,
      mouth: MascotMouth.grin,
      cheeks: .6,
    ),
  ),
  curious(
    MascotPose(
      tilt: -7,
      leftArm: MascotArm(Offset(54, 116), Offset(68, 100)),
      leftHand: MascotHand.fist,
      eyes: MascotEyes.look,
      brows: MascotBrows.raise,
      mouth: MascotMouth.hmm,
      bubble: MascotBubble.question,
    ),
  ),
  focused(
    MascotPose(
      eyes: MascotEyes.look,
      brows: MascotBrows.raise,
      mouth: MascotMouth.small,
    ),
  ),
  happy(
    MascotPose(
      leftArm: MascotArm(Offset(54, 112), Offset(30, 78)),
      rightArm: MascotArm(Offset(126, 112), Offset(150, 78)),
      leftHand: MascotHand.ball,
      rightHand: MascotHand.ball,
      eyes: MascotEyes.closed,
      brows: MascotBrows.up,
      mouth: MascotMouth.grin,
      cheeks: 1,
      sparkles: true,
    ),
  ),
  encourage(
    MascotPose(
      rightArm: MascotArm(Offset(126, 112), Offset(148, 88)),
      rightHand: MascotHand.fist,
      brows: MascotBrows.up,
      mouth: MascotMouth.calm,
      cheeks: .5,
    ),
  ),
  listen(
    MascotPose(
      tilt: 6,
      rightArm: MascotArm(Offset(126, 108), Offset(148, 70)),
      rightHand: MascotHand.cup,
      eyes: MascotEyes.wide,
      brows: MascotBrows.up,
      mouth: MascotMouth.o,
    ),
  ),
  talk(
    MascotPose(
      rightArm: MascotArm(Offset(126, 114), Offset(150, 104)),
      rightHand: MascotHand.palm,
      brows: MascotBrows.up,
      mouth: MascotMouth.bigO,
      bubble: MascotBubble.dots,
      cheeks: .4,
    ),
  ),
  understand(
    MascotPose(
      tilt: -5,
      rightArm: MascotArm(Offset(126, 118), Offset(152, 124)),
      rightHand: MascotHand.palm,
      eyes: MascotEyes.soft,
      mouth: MascotMouth.soft,
      cheeks: .4,
    ),
  ),
  sleep(
    MascotPose(
      tilt: 6,
      eyes: MascotEyes.sleep,
      brows: MascotBrows.none,
      mouth: MascotMouth.tiny,
      bubble: MascotBubble.sleep,
    ),
  ),

  /// Holds the phone out to the parent (kids' welcome).
  handoff(
    MascotPose(
      leftArm: MascotArm(Offset(54, 118), Offset(72, 134)),
      rightArm: MascotArm(Offset(126, 118), Offset(108, 134)),
      leftHand: MascotHand.ball,
      rightHand: MascotHand.ball,
      brows: MascotBrows.up,
      mouth: MascotMouth.grin,
      cheeks: .6,
      phone: true,
    ),
  ),

  /// Covers its eyes (e.g. while a password is typed).
  cover(
    MascotPose(
      leftArm: MascotArm(Offset(54, 120), Offset(71, 96), Offset(76, 80)),
      rightArm: MascotArm(Offset(126, 120), Offset(109, 96), Offset(104, 80)),
      leftHand: MascotHand.cover,
      rightHand: MascotHand.cover,
      eyes: MascotEyes.closed,
      brows: MascotBrows.up,
      cheeks: .9,
    ),
  ),

  /// Peeks between its fingers (e.g. when the password is shown).
  peek(
    MascotPose(
      leftArm: MascotArm(Offset(54, 120), Offset(71, 96), Offset(76, 80)),
      rightArm: MascotArm(Offset(126, 120), Offset(109, 96), Offset(104, 80)),
      leftHand: MascotHand.cover,
      rightHand: MascotHand.cover,
      leftSplit: 1,
      eyes: MascotEyes.wide,
      brows: MascotBrows.raise,
      cheeks: .6,
    ),
  ),

  /// Thumbs up with the other hand on the hip: sure the learner can do it.
  /// Drawn in the character sheet's style (the sheet has none) and approved
  /// by the owner.
  confident(
    MascotPose(
      leftArm: MascotArm(Offset(54, 114), Offset(34, 125), Offset(49, 139)),
      rightArm: MascotArm(Offset(126, 112), Offset(146, 88), Offset(148, 84)),
      leftHand: MascotHand.ball,
      rightHand: MascotHand.thumbsUp,
      brows: MascotBrows.confident,
      mouth: MascotMouth.proud,
      cheeks: .3,
      glint: true,
    ),
  );

  const MascotExpression(this.pose);

  final MascotPose pose;

  /// How the expression moves while it rests, after the onboarding designs'
  /// moods: calm ones drift slowly, lively ones bounce, gestures repeat.
  MascotIdle get idle => switch (this) {
    welcome => MascotIdle.standard,
    curious => const MascotIdle(lift: 3, sway: 1.5),
    focused => const MascotIdle(lift: 3, period: AppMotion.characterFloatCalm),
    happy => const MascotIdle(
      lift: 7,
      period: AppMotion.characterFloatLively,
      stretch: .02,
    ),
    encourage => const MascotIdle(
      lift: 6,
      period: AppMotion.characterFloatLively,
      swing: -8,
      stretch: .018,
    ),
    listen => const MascotIdle(lift: 4, sway: 2),
    talk => const MascotIdle(lift: 4, swing: -6),
    understand => const MascotIdle(
      lift: 3,
      period: AppMotion.characterFloatCalm,
      sway: 1.5,
    ),
    sleep => const MascotIdle(
      lift: 2,
      period: AppMotion.characterFloatCalm,
      stretch: .02,
    ),
    handoff || cover => const MascotIdle(lift: 3),
    peek => const MascotIdle(lift: 3, sway: 1),
    confident => const MascotIdle(
      period: AppMotion.characterFloatBrisk,
      swing: -7,
    ),
  };
}

/// Something the guide holds or wears, on top of any expression.
enum MascotProp {
  none,

  /// Holds a key in the raised right hand (forgot-password screens).
  key,

  /// Wears headphones (placement test).
  headphones,

  /// Round glasses: the adult learner on "who will learn".
  // ASSUMPTION(design): glasses, beanie and graduation cap are proposals for
  // the "who will learn" avatars, not yet in the approved drawing.
  glasses,

  /// A kid's cap with a little propeller: the child learner.
  beanie,

  /// A graduation cap with a tassel: the school student.
  gradCap;

  /// Hats replace the speech tuft, which would poke through them.
  bool get isHat => this == beanie || this == gradCap;
}

/// How much of the guide is shown.
enum MascotFraming {
  /// The whole figure with its ground shadow.
  full,

  /// Head and shoulders, for avatars; arms, tilt and effects are dropped.
  head,
}
