import 'dart:math' as math;

import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/motion/motion_timeline.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';

/// When each step of M5 starts (design "Home Archipelago", motion §7), from
/// the return's first frame.
abstract final class LessonDoneBeats {
  /// The guide leaves the ring for the finished stone.
  static const flyToStone = Duration(milliseconds: 320);

  /// It lands there ([flyToStone] + [AppMotion.homeFlyToStone]): the stone
  /// fills, sparks, the bubble's content goes, the island takes colour.
  static const fill = Duration(milliseconds: 680);

  /// The trail to the next stone draws and the guide hops to it.
  static const hop = Duration(milliseconds: 820);

  /// The next stone is the current one; the tail slides, rows may move.
  static const next = Duration(milliseconds: 1300);

  /// When the rows moved, the new content waits for them this long.
  static const rowsDelay = Duration(milliseconds: 160);

  /// The guide flies back to the ring.
  static const flyHome = Duration(milliseconds: 1650);

  /// It is home ([flyHome] + [AppMotion.homeFlyHome]); the goal step starts
  /// if this lesson reached it.
  static const goal = Duration(milliseconds: 2030);

  /// The goal step, to its last spark
  /// ([AppMotion.homeSparks] + five [AppMotion.homeSparkStep]).
  static const goalLength = Duration(milliseconds: 720);
}

/// M5, a lesson done, and its new-row variant 09ب (motion §7, §7.1, D23,
/// D24, D29): the ring fills, the guide flies to the finished stone, the
/// stone fills with sparks, the trail draws on as the guide hops to the next
/// stone, the bubble follows it, the guide flies home and, when this lesson
/// reached today's goal, the goal step plays.
///
/// With the header [collapsed] the guide stays on the map: it starts beside
/// the finished stone and ends beside the next (D23).
final class LessonDoneMotion implements MotionTimeline {
  const LessonDoneMotion({
    required this.moment,
    required this.collapsed,
    this.rows,
  });

  final LessonDoneMoment moment;
  final bool collapsed;

  /// 09ب: the bubble's gap moves from after row [from] to after row [to] as
  /// the next stone opens a row; null when it stays.
  final ({int from, int to})? rows;

  int get _done => moment.lesson;
  int get _next => moment.next;

  bool get _reach => moment.goalReached && moment.goal > 0;

  bool get _rolls => _reach && moment.streakTo != moment.streakFrom;

  static const _hopEnd = Duration(milliseconds: 1240);

  @override
  Duration get length =>
      _reach ? LessonDoneBeats.goal + LessonDoneBeats.goalLength : busyUntil;

  @override
  Duration get busyUntil => LessonDoneBeats.goal;

  @override
  List<TimedCue> get cues => [
    if (!collapsed) (at: LessonDoneBeats.flyToStone, cue: MotionCue.flyToStone),
    (at: LessonDoneBeats.fill, cue: MotionCue.fillStone),
    if (!collapsed) (at: LessonDoneBeats.flyHome, cue: MotionCue.flyHome),
    if (_reach) (at: LessonDoneBeats.goal, cue: MotionCue.goal),
  ];

  /// Today's share of the goal.
  static double fraction(int minutes, int goal) =>
      goal <= 0 ? 0 : math.min(1, minutes / goal);

  @override
  MotionFrame frameAt(Duration t) {
    final ms = msOf(t);
    final filled = ms >= msOf(LessonDoneBeats.fill);
    final moved = ms >= msOf(LessonDoneBeats.next);
    final rows = this.rows;
    final rowsMoving =
        rows != null &&
        moved &&
        ms < msOf(LessonDoneBeats.next + AppMotion.homeRows);
    final contentIn = rows == null
        ? LessonDoneBeats.next
        : LessonDoneBeats.next + LessonDoneBeats.rowsDelay;
    final unit = moment.after.currentUnit;
    final saturation = unit == null
        ? null
        : lerp(
            HomeRules.saturation(unit, doneOverride: _done),
            HomeRules.saturation(unit, doneOverride: _done + 1),
            phase(
              ms,
              LessonDoneBeats.fill,
              AppMotion.homeSaturation,
              AppMotion.out,
            ),
          );
    final popping =
        filled && ms < msOf(LessonDoneBeats.fill + AppMotion.homeStonePop);
    final sliding =
        moved && ms < msOf(LessonDoneBeats.next + AppMotion.homeTail);
    final map = MapOverrides(
      doneN: !filled ? _done : (!moved ? _done + 1 : null),
      cur: !moved ? _done : null,
      segments: {
        _done + 1: phase(
          ms,
          LessonDoneBeats.hop,
          AppMotion.homeTrailDraw,
          AppMotion.inOut,
        ),
      },
      saturation: saturation,
      rowFrom: rowsMoving ? rows.from : null,
      rowT: rowsMoving
          ? phase(
              ms,
              LessonDoneBeats.next,
              AppMotion.homeRows,
              AppMotion.homeRowsCurve,
            )
          : 1,
      tail: sliding
          ? (
              a: _done,
              b: _next,
              t: phase(
                ms,
                LessonDoneBeats.next,
                AppMotion.homeTail,
                AppMotion.homeEmphasis,
              ),
            )
          : null,
      bubbleContent: !filled
          ? 1
          : !moved
          ? 1 - phase(ms, LessonDoneBeats.fill, AppMotion.homeContentOut)
          : phase(ms, contentIn, AppMotion.homeContentIn, AppMotion.out),
      stonePop: popping
          ? (
              index: _done,
              t: phase(ms, LessonDoneBeats.fill, AppMotion.homeStonePop),
            )
          : null,
      guideExpression: MascotExpression.happy,
    );
    return (
      map: map,
      header: goalHeader(
        ms,
        moment: moment,
        reach: _reach,
        rolls: _rolls,
        goalAt: LessonDoneBeats.goal,
      ),
      guide: _guide(ms),
      expression: MascotExpression.happy,
    );
  }

  GuidePlacement? _guide(double ms) {
    final hop = msOf(LessonDoneBeats.hop);
    final hopEnd = msOf(_hopEnd);
    GuidePlacement hopping() => GuideHop(
      _done,
      _next,
      phase(ms, LessonDoneBeats.hop, AppMotion.homeHop, AppMotion.homeFlight),
    );
    if (collapsed) {
      if (ms < hop) return GuideBesideStone(_done);
      if (ms < hopEnd) return hopping();
      return GuideBesideStone(_next);
    }
    if (ms < msOf(LessonDoneBeats.flyToStone)) return null;
    if (ms < msOf(LessonDoneBeats.fill)) return const GuideFlying();
    if (ms < hop) return GuideBesideStone(_done);
    if (ms < hopEnd) return hopping();
    if (ms < msOf(LessonDoneBeats.flyHome)) return GuideBesideStone(_next);
    if (ms < msOf(LessonDoneBeats.goal)) return const GuideFlying();
    return null;
  }
}

/// The header through a lesson's return (M5 and the lead-in of M6): the
/// ring fills to today's new share at once, then, when the lesson reached
/// the goal, from [goalAt] the ring turns green and sparks, the guide jumps,
/// the flame turns over and the streak rolls to its new number.
HeaderOverrides goalHeader(
  double ms, {
  required HomeMoment moment,
  required bool reach,
  required bool rolls,
  required Duration goalAt,
}) {
  final f0 = LessonDoneMotion.fraction(moment.minutesFrom, moment.goal);
  final f1 = LessonDoneMotion.fraction(moment.minutesTo, moment.goal);
  final goalOn = reach && ms >= msOf(goalAt);
  return HeaderOverrides(
    ringFraction: lerp(
      f0,
      f1,
      phase(ms, Duration.zero, AppMotion.homeRingFill, AppMotion.homeEmphasis),
    ),
    minutes: moment.minutesTo,
    ringSuccess: reach ? goalOn : null,
    streak: rolls
        ? (
            from: moment.streakFrom,
            to: goalOn ? moment.streakTo : moment.streakFrom,
          )
        : null,
    streakRoll: rolls
        ? (goalOn ? phase(ms, goalAt, AppMotion.homeStreakRoll) : 1)
        : null,
    flameFlip: goalOn ? phase(ms, goalAt, AppMotion.homeFlameFlip) : 0,
    guideJump: goalOn ? phase(ms, goalAt, AppMotion.homeGuideJump) : 0,
    ringSparks: goalOn ? phase(ms, goalAt, LessonDoneBeats.goalLength) : null,
  );
}
