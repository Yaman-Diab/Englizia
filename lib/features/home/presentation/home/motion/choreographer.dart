import 'dart:async';
import 'dart:math' as math;

import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/motion/container_reveal.dart';
import 'package:englizia/features/home/presentation/home/motion/flight_layer.dart';
import 'package:englizia/features/home/presentation/home/motion/lesson_done_motion.dart';
import 'package:englizia/features/home/presentation/home/motion/loop_budget.dart';
import 'package:englizia/features/home/presentation/home/motion/motion_timeline.dart';
import 'package:englizia/features/home/presentation/home/motion/opening_motion.dart';
import 'package:englizia/features/home/presentation/home/motion/unit_done_motion.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/stage_controller.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

typedef _Cue = ({Duration at, VoidCallback run, VoidCallback? essential});

/// One running motion: [onFrame] draws it [t] in, after [delay] (held on
/// its first frame meanwhile); [cues] fire once as their time passes.
final class _Track {
  _Track({
    required this.length,
    required this.onFrame,
    this.delay = Duration.zero,
    this.cues = const [],
    this.onEnd,
    this.busyUntil = Duration.zero,
    this.skipTo,
  });

  final Duration length;
  final Duration delay;
  final void Function(Duration t) onFrame;
  final List<_Cue> cues;
  final VoidCallback? onEnd;
  final Duration busyUntil;

  /// Where a tap skips it to, if it can be skipped.
  final Duration? skipTo;

  /// Its first tick: a motion starts on the frame after it is asked for.
  Duration? start;
  Duration at = Duration.zero;
  final fired = <int>{};
  final done = Completer<void>();
}

/// Plays home's motions (design "Home Archipelago", M1–M14) by writing the
/// scene's overrides; the page draws [map], [header] and [forcedGuide] each
/// frame and keeps [island] and [mapLayout] up to date. Positions are the
/// stage's right-to-left frame. Under reduce motion every motion ends
/// on its last frame at once, with a [AppMotion.quick] fade where content
/// swaps, and the haptics still fire.
class HomeChoreographer extends ChangeNotifier {
  HomeChoreographer({
    required this.vsync,
    required this.reduceMotion,
    required this.stage,
    required this.cubit,
    required this.flights,
  }) : loops = HomeLoops(vsync: vsync) {
    _clock = MotionClock(vsync, _tick);
    flights.addListener(_flightsChanged);
  }

  final TickerProvider vsync;
  final bool Function() reduceMotion;
  final StageController stage;
  final HomeCubit cubit;
  final FlightLayerController flights;

  /// The ambient loops (M2), run by [budget].
  final HomeLoops loops;

  /// The current island and the map as drawn now: where the guide's
  /// flights start and land.
  IslandLayout? island;
  MapLayout? mapLayout;

  /// The guide on the map, the size it flies to and from.
  static const parkedSize = 44.0;

  /// The guide's face in the back-to-lesson button.
  static const backButtonSize = 40.0;

  /// The guide on a freeze or broke card.
  static const cardGuideSize = 56.0;

  /// The guide in the ring, and in the kids' and v0.1's 80 slot.
  static const ringGuide = 64.0;
  static const slotGuide = 80.0;

  /// The lighthouse's sparks burst this far above its stone.
  static const lighthouseSparks = 26.0;

  /// M6's camera brings the next island this far into the view: its top
  /// [cameraAbove] above the stage's anchor, [cameraLead] under the header.
  static const cameraAbove = 120.0;
  static const cameraLead = 162.0;

  /// The back button's flight starts within the view, this far in.
  static const backFlightInset = 24.0;

  /// The two taps of a unit or level done (20-40-20) are this far apart.
  static const hapticGap = Duration(milliseconds: 40);

  late final MotionClock _clock;
  final _tracks = <_Track>[];
  _Track? _sequence;
  _Track? _say;
  _Track? _hitHold;
  MotionFrame _seq = stillFrame;
  MapOverrides _map = MapOverrides.none;
  HeaderOverrides _header = HeaderOverrides.none;
  ({int island, double t})? _shake;
  ({int index, double t, bool island})? _pulse;
  int? _hit;
  double _contentShift = 0;
  double _guideHop = 0;
  double _fade = 1;
  double? _glint;
  bool _kidSaying = false;
  bool _spinning = false;
  bool _busy = false;
  bool _revealing = false;
  bool _wasFlying = false;
  double _pullSeen = 0;
  GuidePlacement? _guideHold;
  MapLayout Function()? _after;
  var _disposed = false;

  MapOverrides get map => _map;

  HeaderOverrides get header => _header;

  /// Where a motion puts the guide; null leaves it to `resolveGuide`.
  GuidePlacement? get forcedGuide {
    if (flights.flying) return const GuideFlying();
    return _seq.guide ?? _guideHold;
  }

  MascotExpression? get guideExpression => _seq.expression;

  /// M5 or M6 running: no snap, no mode flip, no back button.
  bool get busy => _busy;

  /// M6 runs to its finish: a tap skips there ([SkipLayer]).
  bool get skippable {
    final track = _sequence;
    final skip = track?.skipTo;
    return track != null && skip != null && track.at < track.delay + skip;
  }

  /// Kids: the guide says the unit's name (M14): show its bubble, play it.
  bool get kidSaying => _kidSaying;

  /// The refresh started: the hanging guide turns once.
  bool get pullSpinning => _spinning;

  /// The at-risk flame's wobble for the top bar (M10).
  Animation<double> get flameWobble => loops.flame;

  /// M1, once a day, then the cubit is told it played.
  Future<void> playOpening(HomeSnapshot home) async {
    if (!reduceMotion()) {
      final unit = home.currentUnit;
      await _playSequence(
        OpeningMotion(
          islands: home.units.length,
          segment: unit?.currentLesson ?? 0,
        ),
      );
    }
    if (!_disposed && !cubit.isClosed) cubit.openingPlayed();
  }

  /// M5, 09ب or M6 (with M7 and, for kids, M14), then the cubit is told it
  /// played. [layout] and [map] are the day before's, as drawn when the
  /// moment arrives; [after] gives the new day's map once it is drawn, for
  /// the finished unit's scroll.
  Future<void> playMoment(
    HomeMoment moment, {
    required IslandLayout layout,
    required MapLayout map,
    MapLayout Function()? after,
  }) async {
    island = layout;
    mapLayout = map;
    _after = after;
    final collapsed = stage.metrics.collapsed;
    final (motion, cues) = switch (moment) {
      LessonDoneMoment() => _lessonDone(moment, collapsed),
      UnitDoneMoment() => _unitDone(moment, collapsed),
    };
    if (reduceMotion()) {
      await _reduced(cues);
    } else {
      await _playSequence(
        motion,
        cues: cues,
        delay: AppMotion.homeReturnDelay,
        skippable: moment is UnitDoneMoment,
      );
    }
    if (!_disposed && !cubit.isClosed) cubit.momentPlayed();
  }

  /// M6 tapped: straight to the next unit; the haptics and sounds that were
  /// still to come play at once.
  void skip() {
    final track = _sequence;
    final to = track?.skipTo;
    if (track == null || to == null) return;
    final target = track.delay + to;
    if (track.at >= target) return;
    flights.cancel();
    for (final (i, cue) in track.cues.indexed) {
      if (track.fired.contains(i) || cue.at >= to) continue;
      track.fired.add(i);
      cue.essential?.call();
    }
    track.start = _clock.now - target;
    _advance(track);
    _rebuild();
  }

  /// M8: the guide hops between the ring and the current stone as the
  /// header passes half folded.
  Future<void> modeFlip({required bool collapsed}) async {
    if (reduceMotion() ||
        busy ||
        _seq.guide != null ||
        _guideHold != null ||
        stage.programmatic) {
      return;
    }
    final spot = _spot(_guideStone());
    if (spot == null) return;
    final ring = _ringPose();
    final face = _ringExpression();
    if (collapsed) {
      await flights.fly(
        ring.centre,
        ring.size,
        spot,
        parkedSize,
        AppMotion.homeModeHop,
        face,
      );
    } else {
      await flights.fly(
        spot,
        parkedSize,
        ring.centre,
        ring.size,
        AppMotion.homeModeHop,
        face,
      );
    }
  }

  /// A freeze or broke card closed: the map and the level
  /// header rise [dh] into its place while the guide flies from the card's
  /// guide ([cardGuide], stage frame) to the ring and lands with a hop.
  Future<void> cardClosed({required Rect cardGuide, required double dh}) async {
    if (reduceMotion()) return;
    final shift = _run(
      _Track(
        length: AppMotion.homeCardClose,
        onFrame: (t) => _contentShift =
            dh *
            (1 -
                phase(
                  msOf(t),
                  Duration.zero,
                  AppMotion.homeCardClose,
                  AppMotion.homeEmphasis,
                )),
        onEnd: () => _contentShift = 0,
      ),
    );
    final ring = _ringPose();
    await flights.fly(
      cardGuide.center,
      cardGuide.shortestSide,
      ring.centre,
      ring.size,
      AppMotion.homeModeHop,
      MascotExpression.happy,
    );
    if (_disposed) return;
    await _run(
      _Track(
        length: AppMotion.homeCardHop,
        onFrame: (t) =>
            _guideHop = phase(msOf(t), Duration.zero, AppMotion.homeCardHop),
        onEnd: () => _guideHop = 0,
      ),
    ).done.future;
    await shift.done.future;
  }

  /// M11: the stage fades out, [load] runs (for at least
  /// [AppMotion.homeSwitchGap]), the new one fades in. Reduce motion: only
  /// the fade in, over [AppMotion.quick].
  Future<void> switchTrack(Future<void> Function() load) async {
    final reduced = reduceMotion();
    if (!reduced) {
      _run(
        _Track(
          length: AppMotion.homeSwitchOut,
          onFrame: (t) => _fade =
              1 -
              phase(
                msOf(t),
                Duration.zero,
                AppMotion.homeSwitchOut,
                AppMotion.easeIn,
              ),
        ),
      );
    }
    await Future.wait([load(), if (!reduced) _wait(AppMotion.homeSwitchGap)]);
    if (_disposed) return;
    final fadeIn = reduced ? AppMotion.quick : AppMotion.homeSwitchIn;
    await _run(
      _Track(
        length: fadeIn,
        onFrame: (t) => _fade = phase(
          msOf(t),
          Duration.zero,
          fadeIn,
          reduced ? AppMotion.linear : AppMotion.out,
        ),
        onEnd: () => _fade = 1,
      ),
    ).done.future;
  }

  /// M9: the locked island shakes, with a light tap.
  Future<void> lockedTap(int island) async {
    unawaited(AppHaptics.lightImpact());
    if (reduceMotion()) return;
    await _run(
      _Track(
        length: AppMotion.homeShake,
        onFrame: (t) => _shake = (
          island: island,
          t: phase(msOf(t), Duration.zero, AppMotion.homeShake),
        ),
        onEnd: () => _shake = null,
      ),
    ).done.future;
  }

  /// A double pulse of stone [index], or of compact [island] [index]; a
  /// page found ([hit]) also rings the stone for [AppMotion.homeHitHold].
  Future<void> pulseStone(
    int index, {
    bool island = false,
    bool hit = false,
  }) async {
    if (hit && !island) {
      final held = _hitHold;
      if (held != null) _end(held, notify: false);
      _hit = index;
      _hitHold = _run(
        _Track(
          length: AppMotion.homeHitHold,
          onFrame: (_) {},
          onEnd: () {
            _hit = null;
            _hitHold = null;
          },
        ),
      );
    }
    if (reduceMotion()) return;
    await _run(
      _Track(
        length: AppMotion.homeDoublePulse,
        onFrame: (t) => _pulse = (
          index: index,
          t: phase(msOf(t), Duration.zero, AppMotion.homeDoublePulse),
          island: island,
        ),
        onEnd: () => _pulse = null,
      ),
    ).done.future;
  }

  /// M4: the bubble ([bubble], global coordinates) grows to the screen, then
  /// [push]. Under reduce motion, or before the layer is mounted, a
  /// plain [push]. While one grows, another is ignored: one lesson opens.
  Future<void> openLesson(Rect bubble, VoidCallback push) async {
    if (busy || _revealing) return;
    final context = flights.overlayContext;
    if (reduceMotion() || context == null || !context.mounted) {
      push();
      return;
    }
    _revealing = true;
    try {
      await ContainerReveal.run(context, from: bubble, push: push);
    } finally {
      _revealing = false;
    }
  }

  /// A freeze was used: the flame's one glint of snow.
  // ASSUMPTION(design): the design gives no numbers; «أنا»'s shine is reused
  // (meShine after meShineDelay), INFO-tinted by the flame's painter.
  Future<void> freezeGlint() async {
    if (reduceMotion()) return;
    final length = AppMotion.meShineDelay + AppMotion.meShine;
    await _run(
      _Track(
        length: length,
        onFrame: (t) => _glint = t < AppMotion.meShineDelay
            ? null
            : phase(msOf(t), AppMotion.meShineDelay, AppMotion.meShine),
        onEnd: () => _glint = null,
      ),
    ).done.future;
  }

  /// Kids: the speaker on the banner says the name again (M14); a tap
  /// while it speaks starts it over.
  void sayUnit() => _sayFor(AppMotion.homeKidReplay);

  /// The back-to-lesson button shows: the guide flies into it from beside
  /// the stone (collapsed) or out of the ring.
  Future<void> backButtonShown() async {
    _guideHold = const GuideInBackButton();
    _rebuild();
    if (reduceMotion()) return;
    final m = stage.metrics;
    final Offset from;
    final double size;
    if (m.collapsed) {
      final spot = _spot(_guideStone());
      if (spot == null) return;
      from = Offset(
        spot.dx,
        spot.dy.clamp(
          StageMetrics.topBar + StageMetrics.levelHeader + backFlightInset,
          math.max(
            StageMetrics.topBar + StageMetrics.levelHeader + backFlightInset,
            StageMetrics.topBar + m.view - backFlightInset,
          ),
        ),
      );
      size = parkedSize;
    } else {
      final ring = _ringPose();
      from = ring.centre;
      size = ring.size;
    }
    await flights.fly(
      from,
      size,
      m.backButtonCentre,
      backButtonSize,
      AppMotion.homeBackFly,
      MascotExpression.encourage,
    );
  }

  /// The back button was pressed and the map is at the lesson: a beat later
  /// the guide flies out of it to beside the stone.
  Future<void> backButtonLanded() async {
    if (reduceMotion()) {
      backButtonHidden();
      return;
    }
    await _wait(AppMotion.homeBackLandDelay);
    if (_disposed) return;
    final spot = _spot(_guideStone());
    final from = stage.metrics.backButtonCentre;
    _guideHold = null;
    _rebuild();
    if (spot == null) return;
    await flights.fly(
      from,
      backButtonSize,
      spot,
      parkedSize,
      AppMotion.homeBackLand,
      MascotExpression.encourage,
    );
  }

  /// The back button hid as the stone came back on screen.
  void backButtonHidden() {
    if (_guideHold == null) return;
    _guideHold = null;
    _rebuild();
  }

  /// The stage is pulled to [pull]: a tick as it passes the threshold.
  void pullMoved(double pull) {
    if (_pullSeen <= AppMotion.homePullThreshold &&
        pull > AppMotion.homePullThreshold) {
      unawaited(AppHaptics.selectionClick());
    }
    _pullSeen = pull;
  }

  /// Let go at [pull] (M12): past the threshold it holds, refreshes, spins
  /// the guide and goes back after [AppMotion.homePullHold]; short of it, it
  /// just goes back. [onPull] moves the stage.
  Future<void> pullReleased(
    double pull, {
    required ValueChanged<double> onPull,
  }) async {
    _pullSeen = 0;
    var from = pull;
    if (pull > AppMotion.homePullThreshold) {
      from = AppMotion.homePullHoldAt;
      onPull(from);
      unawaited(cubit.refresh(byUser: true));
      if (!reduceMotion()) {
        _spinning = true;
        _rebuild();
        _run(
          _Track(
            length: AppMotion.homePullSpin,
            onFrame: (_) {},
            onEnd: () => _spinning = false,
          ),
        );
      }
      await _wait(AppMotion.homePullHold);
      if (_disposed) return;
    }
    if (reduceMotion()) {
      onPull(0);
      return;
    }
    final start = from;
    await _run(
      _Track(
        length: AppMotion.homePullBack,
        onFrame: (t) => onPull(
          start *
              (1 -
                  phase(
                    msOf(t),
                    Duration.zero,
                    AppMotion.homePullBack,
                    AppMotion.homeEmphasis,
                  )),
        ),
      ),
    ).done.future;
  }

  /// Runs the ambient loops that fit the budget among those [visible] (M2):
  /// after the map settles, when what shows changes, and with nothing when
  /// the app leaves the screen.
  void budget(
    Map<HomeLoop, bool> visible, {
    Map<HomeLoop, int> counts = const {},
  }) {
    if (reduceMotion()) {
      loops.rest();
      return;
    }
    loops.run(LoopBudget.pick(visible: visible, counts: counts));
  }

  // The moments' plans.

  (MotionTimeline, List<_Cue>) _lessonDone(LessonDoneMoment m, bool collapsed) {
    final motion = LessonDoneMotion(
      moment: m,
      collapsed: collapsed,
      rows: _rowsMove(m),
    );
    final done = m.lesson;
    final next = m.next;
    return (
      motion,
      [
        for (final cue in motion.cues)
          switch (cue.cue) {
            MotionCue.flyToStone => (
              at: cue.at,
              run: () => _flyFromRing(done, AppMotion.homeFlyToStone),
              essential: null,
            ),
            MotionCue.fillStone => (
              at: cue.at,
              run: () {
                unawaited(AppHaptics.lightImpact());
                _burstAtStone(done);
              },
              essential: () => unawaited(AppHaptics.lightImpact()),
            ),
            MotionCue.flyHome => (
              at: cue.at,
              run: () => _flyToRing(
                next,
                m.goalReached
                    ? MascotExpression.happy
                    : MascotExpression.encourage,
              ),
              essential: null,
            ),
            _ => _commonCue(cue, m),
          },
      ],
    );
  }

  (MotionTimeline, List<_Cue>) _unitDone(UnitDoneMoment m, bool collapsed) {
    final motion = UnitDoneMotion(moment: m, collapsed: collapsed);
    final last = math.max(0, (m.before.currentUnit?.lessons.length ?? 1) - 1);
    return (
      motion,
      [
        for (final cue in motion.cues)
          switch (cue.cue) {
            MotionCue.flyToStone => (
              at: cue.at,
              run: () => _flyFromRing(last, AppMotion.homeFlyToStone),
              essential: null,
            ),
            MotionCue.unitDone => (
              at: cue.at,
              run: () {
                _celebrate(HomeCheer.unit);
                _burstAtLighthouse(last);
              },
              essential: () => _celebrate(HomeCheer.unit),
            ),
            MotionCue.camera => (
              at: cue.at,
              run: () => _camera(m.nextUnit),
              essential: null,
            ),
            MotionCue.finish => (
              at: cue.at,
              run: _finishScroll,
              essential: _finishScroll,
            ),
            MotionCue.levelDone => (
              at: cue.at,
              run: () => _celebrate(HomeCheer.level),
              essential: () => _celebrate(HomeCheer.level),
            ),
            MotionCue.kidSay => (
              at: cue.at,
              run: () => _sayFor(AppMotion.homeKidSay),
              essential: () => _sayFor(AppMotion.homeKidSay),
            ),
            _ => _commonCue(cue, m),
          },
      ],
    );
  }

  _Cue _commonCue(TimedCue cue, HomeMoment m) => switch (cue.cue) {
    MotionCue.goal => (at: cue.at, run: _goalTap, essential: _goalTap),
    _ => (at: cue.at, run: () {}, essential: null),
  };

  void _goalTap() {
    unawaited(AppHaptics.mediumImpact());
    if (!cubit.isClosed) cubit.cheer(HomeCheer.goal);
  }

  /// The unit's and the level's pattern (20-40-20) and sound.
  // ASSUMPTION(design): the design's vibration lengths map to the platform's
  // impacts: 8–12 ms light, 20–30 ms medium.
  void _celebrate(HomeCheer cheer) {
    unawaited(AppHaptics.mediumImpact());
    unawaited(_wait(hapticGap).then((_) => AppHaptics.mediumImpact()));
    if (!cubit.isClosed) cubit.cheer(cheer);
  }

  /// 09ب: whether the current stone moving to [LessonDoneMoment.next] moves
  /// the bubble's gap to another row.
  ({int from, int to})? _rowsMove(LessonDoneMoment m) {
    final unit = m.before.currentUnit;
    if (unit == null) return null;
    final frame = MapFrame(stage.width);
    final station = HomeRules.reviewFirst(m.before);
    int clearAt(int current) => IslandLayout.compute(
      lessons: unit.lessons.length,
      current: current,
      kids: m.before.kids,
      frame: frame,
      reviewStation: station,
    ).clear;
    final from = clearAt(m.lesson);
    final to = clearAt(m.next);
    return from == to ? null : (from: from, to: to);
  }

  /// Reduce motion: the haptics, sounds and jumps at once, then the new
  /// day with its bubble's content fading in.
  Future<void> _reduced(List<_Cue> cues) async {
    for (final cue in cues) {
      cue.essential?.call();
    }
    await _playSequence(const _QuickFade());
  }

  // Geometry.

  /// Where the guide parks: the review station in review-first, else the
  /// current stone (the last once all are done).
  int? _guideStone() {
    final home = cubit.state.home;
    final unit = home?.currentUnit;
    if (home == null || unit == null || unit.lessons.isEmpty) return null;
    if (HomeRules.reviewFirst(home)) return -1;
    return math.min(unit.lessons.length - 1, unit.currentLesson);
  }

  double? get _islandTop {
    final map = mapLayout;
    final index = map?.currentIndex;
    if (map == null || index == null || index >= map.islands.length) {
      return null;
    }
    return map.islands[index].rect.top;
  }

  /// Beside stone [k] on the stage.
  Offset? _spot(int? k) {
    final layout = island;
    final top = _islandTop;
    if (k == null || layout == null || top == null) return null;
    if (k >= layout.stones.length) return null;
    final spot = layout.spot(k);
    return stage.metrics.toMain(Offset(spot.dx, top + spot.dy));
  }

  /// Stone [k]'s centre on the stage, [lift] above it.
  Offset? _stone(int k, {double lift = 0}) {
    final layout = island;
    final top = _islandTop;
    if (layout == null || top == null || k < 0 || k >= layout.stones.length) {
      return null;
    }
    final stone = layout.stones[k];
    return stage.metrics.toMain(Offset(stone.dx, top + stone.dy - lift));
  }

  ({Offset centre, double size}) _ringPose() {
    final m = stage.metrics;
    final s = m.ringScale;
    final home = cubit.state.home;
    final slot = m.kids || (home?.v01 ?? false);
    if (!slot) return (centre: m.ringCenter, size: ringGuide * s);
    // The 80 slot sits 8 in and 4 down in the ring's 96 box.
    return (
      centre: Offset(m.ringLeft + 48 * s, m.ringTop + 44 * s),
      size: slotGuide * s,
    );
  }

  /// The ring's guide: glad at the goal, cheering on short of it, waving
  /// hello before the day's first minute.
  MascotExpression _ringExpression() {
    final home = cubit.state.home;
    final f = home == null
        ? 0.0
        : LessonDoneMotion.fraction(home.todayMinutes, home.goalMinutes);
    if (f >= 1) return MascotExpression.happy;
    if (f > 0) return MascotExpression.encourage;
    return MascotExpression.welcome;
  }

  void _flyFromRing(int stone, Duration length) {
    final spot = _spot(stone);
    if (spot == null) return;
    final ring = _ringPose();
    unawaited(
      flights.fly(
        ring.centre,
        ring.size,
        spot,
        parkedSize,
        length,
        MascotExpression.happy,
      ),
    );
  }

  void _flyToRing(int stone, MascotExpression face) {
    final spot = _spot(stone);
    if (spot == null) return;
    final ring = _ringPose();
    unawaited(
      flights.fly(
        spot,
        parkedSize,
        ring.centre,
        ring.size,
        AppMotion.homeFlyHome,
        face,
      ),
    );
  }

  void _burstAtStone(int k) {
    final centre = _stone(k);
    if (centre != null) unawaited(flights.burst(centre, 6));
  }

  void _burstAtLighthouse(int k) {
    final centre = _stone(k, lift: lighthouseSparks);
    if (centre != null) unawaited(flights.burst(centre, 8));
  }

  double _maxScroll(MapLayout map) {
    final m = stage.metrics;
    return math.max(0, m.pt + map.height - m.view);
  }

  /// M6's camera, to the next island, or to the horizon at the level's end.
  void _camera(int? next) {
    final map = mapLayout;
    if (map == null) return;
    final m = stage.metrics;
    final most = _maxScroll(map);
    final target = next == null || next >= map.islands.length
        ? most
        : math.min(
            most,
            map.islands[next].rect.top - cameraAbove + m.pt - cameraLead,
          );
    unawaited(
      stage.scrollTo(
        math.max(0, target),
        AppMotion.homeCamera,
        foldHeader: false,
      ),
    );
  }

  /// The next unit is the current one: once its map is drawn, the header
  /// folds and the map jumps to its anchor.
  void _finishScroll() {
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      if (_disposed) return;
      final map = _after?.call() ?? mapLayout;
      if (map == null) return;
      final m = stage.metrics;
      final anchor = map.initialScroll(pt: m.pt, view: m.view);
      unawaited(
        stage.scrollTo(
          math.min(_maxScroll(map), anchor + m.head),
          Duration.zero,
        ),
      );
    });
    binding.ensureVisualUpdate();
  }

  void _sayFor(Duration length) {
    final say = _say;
    if (say != null) _end(say, notify: false);
    if (!cubit.isClosed) unawaited(cubit.sayUnit());
    _kidSaying = true;
    _say = _run(
      _Track(
        length: length,
        onFrame: (_) {},
        onEnd: () {
          _kidSaying = false;
          _say = null;
        },
      ),
    );
  }

  // The engine.

  Future<void> _playSequence(
    MotionTimeline motion, {
    List<_Cue>? cues,
    Duration delay = Duration.zero,
    bool skippable = false,
  }) {
    final running = _sequence;
    if (running != null) _end(running, notify: false, essentials: true);
    final timed =
        cues ??
        [
          for (final cue in motion.cues)
            (at: cue.at, run: () {}, essential: null),
        ];
    late final _Track track;
    track = _run(
      _Track(
        length: motion.length,
        delay: delay,
        busyUntil: motion.busyUntil,
        skipTo: skippable ? motion.busyUntil : null,
        cues: timed,
        onFrame: (t) {
          _seq = motion.frameAt(t);
          _busy = t < motion.busyUntil;
        },
        onEnd: () {
          if (_sequence == track) {
            _sequence = null;
            _seq = stillFrame;
            _busy = false;
          }
        },
      ),
    );
    _sequence = track;
    _busy = motion.busyUntil > Duration.zero;
    _rebuild();
    return track.done.future;
  }

  Future<void> _wait(Duration length) =>
      _run(_Track(length: length, onFrame: (_) {})).done.future;

  _Track _run(_Track track) {
    if (_disposed) {
      track.done.complete();
      return track;
    }
    _tracks.add(track);
    _clock.start();
    track.onFrame(Duration.zero);
    _rebuild();
    return track;
  }

  void _tick() {
    final before = _shown;
    for (final track in [..._tracks]) {
      _advance(track);
    }
    if (_tracks.isEmpty) _clock.stop();
    _rebuild(unless: before);
  }

  void _advance(_Track track) {
    if (!_tracks.contains(track)) return;
    final elapsed = _clock.now - (track.start ??= _clock.now);
    track.at = elapsed;
    var t = elapsed - track.delay;
    if (t.isNegative) t = Duration.zero;
    if (!elapsed.isNegative && elapsed >= track.delay) {
      for (final (i, cue) in track.cues.indexed) {
        if (track.fired.contains(i) || cue.at > t) continue;
        track.fired.add(i);
        cue.run();
        if (!_tracks.contains(track)) return;
      }
    }
    if (t >= track.length) {
      track.onFrame(track.length);
      _end(track, notify: false);
    } else {
      track.onFrame(t);
    }
  }

  void _end(_Track track, {required bool notify, bool essentials = false}) {
    if (!_tracks.remove(track)) return;
    if (essentials) {
      for (final (i, cue) in track.cues.indexed) {
        if (track.fired.add(i)) cue.essential?.call();
      }
    }
    track.onEnd?.call();
    if (!track.done.isCompleted) track.done.complete();
    if (notify) _rebuild();
  }

  /// Everything home draws from this, to tell a frame that changes nothing.
  List<Object?> get _shown => [
    _map,
    _header,
    forcedGuide,
    guideExpression,
    _busy,
    skippable,
    _kidSaying,
    _spinning,
  ];

  /// Recomputes the overrides and tells home, unless all it shows is still
  /// [unless]: a frame of a track that draws nothing (a hold, a wait)
  /// rebuilds nothing.
  void _rebuild({List<Object?>? unless}) {
    if (_disposed) return;
    final base = _seq.map;
    final shake = _shake;
    _map = base.copyWith(
      shakeIsland: shake?.island,
      shakeT: shake?.t,
      pulse: _pulse,
      hit: _hit,
      mapOpacity: base.mapOpacity * _fade,
    );
    _header = _seq.header.copyWith(
      contentShift: _contentShift == 0 ? null : _contentShift,
      guideHop: _guideHop == 0 ? null : _guideHop,
      freezeGlint: _glint,
    );
    if (unless != null && listEquals(unless, _shown)) return;
    notifyListeners();
  }

  void _flightsChanged() {
    final flying = flights.flying;
    if (flying == _wasFlying) return;
    _wasFlying = flying;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final track in [..._tracks]) {
      _tracks.remove(track);
      if (!track.done.isCompleted) track.done.complete();
    }
    _clock.dispose();
    loops.dispose();
    flights.removeListener(_flightsChanged);
    super.dispose();
  }
}

/// Reduce motion's end of a moment: the new day at once, its changed
/// content fading in over [AppMotion.quick].
final class _QuickFade implements MotionTimeline {
  const _QuickFade();

  @override
  Duration get length => AppMotion.quick;

  @override
  Duration get busyUntil => Duration.zero;

  @override
  List<TimedCue> get cues => const [];

  @override
  MotionFrame frameAt(Duration t) {
    final v = phase(msOf(t), Duration.zero, AppMotion.quick);
    return (
      map: MapOverrides(bubbleContent: v),
      header: HeaderOverrides.none,
      guide: null,
      expression: null,
    );
  }
}
