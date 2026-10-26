import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

/// Hand shape drawn at the end of an arm.
enum MascotHand { none, fist, palm, cup, wave, ball, cover, thumbsUp }

enum MascotEyes { open, wide, closed, soft, sleep, look }

enum MascotBrows { up, calm, raise, confident, none }

enum MascotMouth {
  grin,
  smile,
  calm,
  soft,
  small,
  hmm,
  o,
  bigO,
  tiny,
  proud,
  laugh,
}

/// What the speech tuft above the head shows.
enum MascotBubble { none, question, dots, sleep }

/// One arm in the 180×180 drawing space: a 14-unit stroke from [shoulder] to
/// [end], with the hand drawn at [hand] (defaults to [end]). A [hand] away
/// from [end] bends the arm at [end], like an elbow.
final class MascotArm {
  const MascotArm(this.shoulder, this.end, [Offset? hand]) : _hand = hand;

  final Offset shoulder;
  final Offset end;
  final Offset? _hand;

  Offset get hand => _hand ?? end;

  static MascotArm lerp(MascotArm a, MascotArm b, double t) => MascotArm(
    Offset.lerp(a.shoulder, b.shoulder, t)!,
    Offset.lerp(a.end, b.end, t)!,
    Offset.lerp(a.hand, b.hand, t),
  );

  @override
  bool operator ==(Object other) =>
      other is MascotArm &&
      other.shoulder == shoulder &&
      other.end == end &&
      other.hand == hand;

  @override
  int get hashCode => Object.hash(shoulder, end, hand);
}

/// Everything that differs between expressions, as plain data. Coordinates
/// are in the 180×180 space of the approved drawing (Claude Design
/// `Guide.dc.html`), so a new expression from the designers is one entry.
final class MascotPose {
  const MascotPose({
    this.tilt = 0,
    this.leftArm = restLeft,
    this.rightArm = restRight,
    this.leftHand = MascotHand.none,
    this.rightHand = MascotHand.none,
    this.leftSplit = 0,
    this.rightSplit = 0,
    this.eyes = MascotEyes.open,
    this.brows = MascotBrows.calm,
    this.mouth = MascotMouth.smile,
    this.cheeks = 0,
    this.bubble = MascotBubble.none,
    this.sparkles = false,
    this.glint = false,
    this.phone = false,
  });

  static const restLeft = MascotArm(Offset(54, 120), Offset(40, 146));
  static const restRight = MascotArm(Offset(126, 120), Offset(140, 146));

  /// Degrees, rotating the whole figure around its feet (90, 166).
  final double tilt;
  final MascotArm leftArm;
  final MascotArm rightArm;
  final MascotHand leftHand;
  final MascotHand rightHand;

  /// 0 = covering hand closed, 1 = fingers parted (peeking).
  final double leftSplit;
  final double rightSplit;
  final MascotEyes eyes;
  final MascotBrows brows;
  final MascotMouth mouth;

  /// Opacity of the blush, 0–1.
  final double cheeks;
  final MascotBubble bubble;
  final bool sparkles;

  /// One small sparkle beside the right hand (a thumbs-up "ting").
  final bool glint;

  /// Holds a phone out with both hands (handing it to a parent).
  final bool phone;

  /// Where in an expression change the face, hands and effects swap, as a
  /// fraction of its linear progress; the eyes are shut at that moment.
  static const faceSwitch = .4;

  MascotPose copyWith({
    double? tilt,
    MascotArm? leftArm,
    MascotArm? rightArm,
    MascotHand? leftHand,
    MascotHand? rightHand,
    double? leftSplit,
    double? rightSplit,
    bool? sparkles,
    bool? glint,
    bool? phone,
  }) => MascotPose(
    tilt: tilt ?? this.tilt,
    leftArm: leftArm ?? this.leftArm,
    rightArm: rightArm ?? this.rightArm,
    leftHand: leftHand ?? this.leftHand,
    rightHand: rightHand ?? this.rightHand,
    leftSplit: leftSplit ?? this.leftSplit,
    rightSplit: rightSplit ?? this.rightSplit,
    eyes: eyes,
    brows: brows,
    mouth: mouth,
    cheeks: cheeks,
    bubble: bubble,
    sparkles: sparkles ?? this.sparkles,
    glint: glint ?? this.glint,
    phone: phone ?? this.phone,
  );

  /// The in-between pose of an expression change. Arms, tilt and finger
  /// split follow [motion], which may overshoot 1; the blush fades over the
  /// linear [progress]; face, hands and effects swap at [faceSwitch], while
  /// the eyes are shut ([changeBlink]).
  static MascotPose blend(
    MascotPose from,
    MascotPose to, {
    required double motion,
    required double progress,
  }) {
    final face = progress < faceSwitch ? from : to;
    return MascotPose(
      tilt: lerpDouble(from.tilt, to.tilt, motion)!,
      leftArm: MascotArm.lerp(from.leftArm, to.leftArm, motion),
      rightArm: MascotArm.lerp(from.rightArm, to.rightArm, motion),
      leftHand: face.leftHand,
      rightHand: face.rightHand,
      leftSplit: lerpDouble(from.leftSplit, to.leftSplit, motion)!,
      rightSplit: lerpDouble(from.rightSplit, to.rightSplit, motion)!,
      eyes: face.eyes,
      brows: face.brows,
      mouth: face.mouth,
      cheeks: lerpDouble(from.cheeks, to.cheeks, progress)!.clamp(0, 1),
      bubble: face.bubble,
      sparkles: face.sparkles,
      glint: face.glint,
      phone: face.phone,
    );
  }

  /// How shut the eyes are during an expression change: closing towards
  /// [faceSwitch], open again before the end.
  static double changeBlink(double progress) {
    const span = faceSwitch * 2;
    if (progress <= 0 || progress >= span) return 0;
    return .9 * math.sin(math.pi * progress / span);
  }

  /// Extra height of the figure during an expression change, as a fraction:
  /// a small crouch, then a stretch as it lands in the new pose.
  static double changeStretch(double progress) {
    if (progress <= 0 || progress >= 1) return 0;
    return progress < .5
        ? -.05 * math.sin(math.pi * progress / .5)
        : .02 * math.sin(math.pi * (progress - .5) / .5);
  }
}
