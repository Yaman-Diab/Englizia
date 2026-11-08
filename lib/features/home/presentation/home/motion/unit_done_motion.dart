import 'dart:math' as math;

import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/motion/lesson_done_motion.dart';
import 'package:englizia/features/home/presentation/home/motion/motion_timeline.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';

/// When each step of M6 starts (design "Home Archipelago"), from
/// the unit's own start, which follows M5's first steps.
abstract final class UnitDoneBeats {
  /// M5's lead-in: the ring fills, the guide flies to the last stone and it
  /// fills ([LessonDoneBeats.fill]).
  static const lead = LessonDoneBeats.fill;

  /// The bridge to the next island draws and the camera moves to it.
  static const bridge = Duration(milliseconds: 600);

  /// The next island's fog clears and its lock opens.
  static const fog = Duration(milliseconds: 1150);

  /// The guide crosses the bridge.
  static const cross = Duration(milliseconds: 1250);

  /// The next unit is the current one ([AppMotion.homeUnitEnd]).
  static const finish = AppMotion.homeUnitEnd;

  /// After [finish], the bubble pops on the new island.
  static const bubble = Duration(milliseconds: 200);

  /// [finish] from the return's first frame.
  static Duration get finishAt => lead + finish;
}

/// M6, the unit done, with M7 when it was the level's
/// last and M14 for kids: the island takes its full colour,
/// its flag rises, sparks burst at the lighthouse, the bridge draws while
/// the camera moves to the next island, its fog clears and its lock opens,
/// the guide crosses, then the next unit is the current one and its island
/// grows in. A tap skips to [UnitDoneBeats.finish].
///
/// Until the finish the map draws the day before (`MapOverrides.snapshot`),
/// its current unit all done from the unit's start.
final class UnitDoneMotion implements MotionTimeline {
  UnitDoneMotion({required this.moment, required this.collapsed})
    : _done = allDone(moment.before);

  final UnitDoneMoment moment;
  final bool collapsed;
  final HomeSnapshot _done;

  /// [before] with its current unit's lessons all done: from the unit's
  /// start the island, its lighthouse and the level's bar read it done.
  // ASSUMPTION(design): the design's code keeps the day before until the
  // finish, but its bar reads «3 من 8» from the unit's start, hence this day.
  static HomeSnapshot allDone(HomeSnapshot before) {
    final index = before.currentUnitIndex;
    if (index < 0) return before;
    return before.copyWith(
      units: [
        for (final (i, unit) in before.units.indexed)
          i == index
              ? unit.copyWith(
                  lessons: [
                    for (final lesson in unit.lessons)
                      lesson.withPhone(
                        LessonOnPhone(done: true, kept: lesson.kept),
                      ),
                  ],
                )
              : unit,
      ],
    );
  }

  int get _n => moment.before.currentUnit?.lessons.length ?? 0;
  int get _last => math.max(0, _n - 1);
  bool get _bridge => moment.nextUnit != null;
  bool get _kids => moment.after.kids;
  bool get _reach => moment.goalReached && moment.goal > 0;
  bool get _rolls => _reach && moment.streakTo != moment.streakFrom;

  @override
  Duration get busyUntil => UnitDoneBeats.finishAt;

  @override
  Duration get length {
    var tail = UnitDoneBeats.bubble + AppMotion.homeBubblePop;
    if (AppMotion.homeIsleGrow > tail) tail = AppMotion.homeIsleGrow;
    if (_reach && LessonDoneBeats.goalLength > tail) {
      tail = LessonDoneBeats.goalLength;
    }
    if (moment.levelDone) {
      final level = AppMotion.homeHorizon + AppMotion.homeLevelCardIn;
      if (level > tail) tail = level;
    }
    if (_kids && _bridge && AppMotion.homeKidSay > tail) {
      tail = AppMotion.homeKidSay;
    }
    return UnitDoneBeats.finishAt + tail;
  }

  @override
  List<TimedCue> get cues => [
    if (!collapsed) (at: LessonDoneBeats.flyToStone, cue: MotionCue.flyToStone),
    (at: UnitDoneBeats.lead, cue: MotionCue.unitDone),
    if (_bridge || moment.levelDone)
      (at: UnitDoneBeats.lead + UnitDoneBeats.bridge, cue: MotionCue.camera),
    (at: UnitDoneBeats.finishAt, cue: MotionCue.finish),
    // The goal step waits for the new unit.
    if (_reach) (at: UnitDoneBeats.finishAt, cue: MotionCue.goal),
    if (_kids && _bridge) (at: UnitDoneBeats.finishAt, cue: MotionCue.kidSay),
    if (moment.levelDone)
      (
        at: UnitDoneBeats.finishAt + AppMotion.homeHorizon,
        cue: MotionCue.levelDone,
      ),
  ];

  @override
  MotionFrame frameAt(Duration t) {
    final ms = msOf(t);
    final lead = UnitDoneBeats.lead;
    final finishAt = UnitDoneBeats.finishAt;
    final leadIn = ms < msOf(lead);
    final finished = ms >= msOf(finishAt);
    final unit = moment.before.currentUnit;
    final from = unit == null
        ? 1.0
        : HomeRules.saturation(unit, doneOverride: _last);
    final MapOverrides map;
    if (finished) {
      final grow = phase(
        ms,
        finishAt,
        AppMotion.homeIsleGrow,
        AppMotion.homeEmphasis,
      );
      map = MapOverrides(
        islandGrow: _bridge && grow < 1
            ? (
                scale: lerp(AppMotion.homeIsleFrom, 1, grow),
                opacity: lerp(.4, 1, grow),
              )
            : null,
        bubbleIn: _bridge
            ? phase(
                ms,
                finishAt + UnitDoneBeats.bubble,
                AppMotion.homeBubblePop,
              )
            : 1,
        horizonOpen: moment.levelDone
            ? phase(ms, finishAt, AppMotion.homeHorizon, AppMotion.out)
            : null,
        // ASSUMPTION(design): the card's rise has no curve in the design;
        // the home's emphasis, after the horizon.
        levelCardIn: moment.levelDone
            ? phase(
                ms,
                finishAt + AppMotion.homeHorizon,
                AppMotion.homeLevelCardIn,
              )
            : 1,
      );
    } else {
      final next = moment.nextUnit;
      map = MapOverrides(
        snapshot: leadIn ? moment.before : _done,
        cur: leadIn ? _last : _n,
        bubbleVisible: leadIn,
        saturation: leadIn
            ? from
            : lerp(
                from,
                1,
                phase(ms, lead, AppMotion.homeSaturation, AppMotion.out),
              ),
        flagUp: leadIn
            ? 0
            : phase(ms, lead, AppMotion.homeFlagRise, AppMotion.homeFlip),
        bridges: next == null
            ? const {}
            : {
                moment.unit: phase(
                  ms,
                  lead + UnitDoneBeats.bridge,
                  AppMotion.homeBridge,
                  AppMotion.homeRowsCurve,
                ),
              },
        cloudsIsland: next,
        clouds: next == null
            ? 0
            : phase(
                ms,
                lead + UnitDoneBeats.fog,
                AppMotion.homeFogClear,
                AppMotion.out,
              ),
        lockOpen: next == null
            ? 0
            : phase(
                ms,
                lead + UnitDoneBeats.fog,
                AppMotion.homeLockOpen,
                AppMotion.easeIn,
              ),
        guideExpression: MascotExpression.happy,
      );
    }
    return (
      map: map,
      header: goalHeader(
        ms,
        moment: moment,
        reach: _reach,
        rolls: _rolls,
        goalAt: finishAt,
      ),
      guide: _guide(ms),
      expression: finished ? null : MascotExpression.happy,
    );
  }

  GuidePlacement? _guide(double ms) {
    final finishAt = msOf(UnitDoneBeats.finishAt);
    if (ms >= finishAt) {
      return _kids && _bridge && ms < finishAt + msOf(AppMotion.homeKidSay)
          ? const GuideOnBanner()
          : null;
    }
    final lead = msOf(UnitDoneBeats.lead);
    if (ms < lead) {
      if (collapsed) return GuideBesideStone(_last);
      return ms < msOf(LessonDoneBeats.flyToStone) ? null : const GuideFlying();
    }
    final cross = lead + msOf(UnitDoneBeats.cross);
    if (_bridge && ms >= cross) {
      return GuideOnBridge(
        moment.unit,
        phase(
          ms,
          UnitDoneBeats.lead + UnitDoneBeats.cross,
          AppMotion.homeBridgeFlight,
          AppMotion.homeFlight,
        ),
      );
    }
    return GuideBesideStone(_last);
  }
}
