import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/motion/loop_budget.dart';
import 'package:englizia/features/home/presentation/home/paint/bridges_layer.dart';
import 'package:englizia/features/home/presentation/home/paint/island_art.dart';
import 'package:englizia/features/home/presentation/home/paint/sea_layer.dart';
import 'package:englizia/features/home/presentation/home/paint/waves_layer.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/level_complete_card.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/island_banner.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/kid_say_bubble.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/lesson_bubble.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/review_box.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/stone.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/stone_card.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/compact_island.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/horizon_flag.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/locked_toast.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The sea a track's map is drawn in: Emar's, the kids', or the general one.
SeaTone toneOf(HomeEnrollment enrollment) {
  if (enrollment.kidsMode || enrollment.audience == TrackAudience.child) {
    return SeaTone.kids;
  }
  return enrollment.audience == TrackAudience.schoolStudent
      ? SeaTone.emar
      : SeaTone.general;
}

/// What the map draws, worked out once per change of the data, the header's
/// height or a motion's frame: the snapshot drawn, its islands and the
/// current one's stones (design "Home Archipelago", map §2, §3, §9).
@immutable
final class HomeMapScene {
  const HomeMapScene({
    required this.home,
    required this.frame,
    required this.map,
    required this.island,
    required this.unitIndex,
    required this.current,
    required this.doneN,
    required this.reviewFirst,
    required this.reviewBox,
    required this.bubbleMode,
    required this.bubbleLesson,
    required this.bubbleFrame,
    required this.bubbleHeight,
  });

  /// The snapshot drawn: the state's, or the one a motion holds on to.
  final HomeSnapshot home;
  final MapFrame frame;
  final MapLayout map;

  /// The current island's layout; null when the level is done.
  final IslandLayout? island;

  /// The current unit, -1 when none is.
  final int unitIndex;

  /// The current lesson as drawn, and the lessons done.
  final int current;
  final int doneN;
  final bool reviewFirst;
  final bool reviewBox;
  final BubbleMode bubbleMode;
  final HomeLesson? bubbleLesson;

  /// Null hides the bubble.
  final BubbleFrame? bubbleFrame;
  final double bubbleHeight;

  HomeUnit? get unit => unitIndex < 0 ? null : home.units[unitIndex];
  bool get kids => home.kids;
  bool get emar => home.enrollment.audience == TrackAudience.schoolStudent;
  SeaTone get tone => toneOf(home.enrollment);

  /// The current island's top on the map.
  double get islandTop => map.current?.rect.top ?? 0;

  /// The stone the bubble and the back button point at: the station when
  /// the review comes first.
  Offset? get target {
    final island = this.island;
    if (island == null) return null;
    if (reviewFirst) return island.station;
    return island.stones[math.min(island.n - 1, math.max(0, current))];
  }

  /// The last stone is drawn as a lighthouse or a gate (D8).
  LastStone get lastStone {
    final unit = this.unit;
    return unit == null ? LastStone.none : lastStoneOf(unit, kids: kids);
  }

  bool lessonDone(int k, MapOverrides overrides) {
    final doneN = overrides.doneN;
    if (doneN != null) return k < doneN;
    return unit!.lessons[k].done;
  }

  StoneState stoneState(int k, MapOverrides overrides) {
    if (lessonDone(k, overrides)) return StoneState.done;
    if (k == current) return StoneState.current;
    return home.enrollment.ordered ? StoneState.locked : StoneState.open;
  }
}

/// What the map's buttons do; the page decides.
@immutable
final class HomeMapActions {
  const HomeMapActions({
    required this.onBubble,
    required this.onStone,
    required this.onStation,
    required this.onBanner,
    required this.onKidListen,
    required this.onReviewBox,
    required this.onIsland,
    required this.onStartLevel,
    required this.onCloseCard,
    required this.onReplay,
    required this.onStart,
  });

  final VoidCallback onBubble;
  final ValueChanged<int> onStone;
  final VoidCallback onStation;
  final VoidCallback onBanner;
  final VoidCallback onKidListen;
  final VoidCallback onReviewBox;
  final ValueChanged<int> onIsland;
  final VoidCallback onStartLevel;
  final VoidCallback onCloseCard;

  /// A stone's card: «أعد» and Emar's «ابدأ».
  final ValueChanged<int> onReplay;
  final ValueChanged<int> onStart;
}

/// The map: sea, islands, bridges, stones and the bubble, in the design's
/// order (map §13), as tall as the map's layout. The screen reader reads it
/// as one group in the board's order: done units, the banner, the review
/// box, the stones along the trail, the bubble, the lighthouse, the units
/// ahead and the horizon (map §18).
///
/// Reads [overrides]' `isleRise`, `boxIn`, `levelCardIn` and `pulse.t` as
/// linear progress and gives them the design's curves; `islandGrow` and the
/// rest as values.
class HomeMap extends StatelessWidget {
  const HomeMap({
    required this.scene,
    required this.overrides,
    required this.guide,
    required this.guideExpression,
    required this.offline,
    required this.loops,
    required this.scroll,
    required this.actions,
    this.card,
    this.toast,
    this.levelCard = false,
    this.kidSaying = false,
    this.bubbleKey,
    super.key,
  });

  final HomeMapScene scene;
  final MapOverrides overrides;
  final GuidePlacement guide;
  final MascotExpression guideExpression;
  final bool offline;

  /// The ambient loops the budget lets run (M2), and their clocks.
  final HomeLoops loops;

  /// The map's scroll, for the waves' parallax.
  final ValueListenable<double> scroll;
  final HomeMapActions actions;

  /// The stone whose card is open.
  final int? card;

  /// The locked island saying when it opens (M9).
  final int? toast;

  /// The level card stands at the horizon (D12).
  final bool levelCard;

  /// Kids: the guide says the unit's name (M14).
  final bool kidSaying;

  /// The bubble's box, for the lesson's container transform (M4).
  final GlobalKey? bubbleKey;

  /// A stone's box, centred on its point: room for the kids' 80 with its halo.
  static const stoneBox = 96.0;

  /// The last stone's target stands on its point (map §5.2).
  static const landmarkLift = Stone.lastBox / 2;

  /// The review station keeps 2 from the screen's edge (map §5.3).
  static const _stationLeast = 2.0 + 27;

  /// The parked guide (motion §2).
  static const guideSize = 44.0;

  /// The guide on a bridge: lifted and leaning (map §12).
  static const bridgeLift = 40.0;
  static const bridgeLean = -8.0;

  /// Kids: where the guide stands by the banner, and the say bubble above.
  static const bannerGuide = Offset(14, 6);
  static const kidSayEnd = 46.0;
  static const kidSayTop = -50.0;

  /// The level card at the open horizon (map §11).
  static const levelCardSide = 20.0;
  static const levelCardTop = 24.0;

  /// The screen reader's order of the map's parts (map §18).
  static const _doneOrder = 0.0;
  static const _bannerOrder = 100.0;
  static const _boxOrder = 200.0;
  static const _stoneOrder = 300.0;
  static const _bubbleOrder = 400.0;
  static const _cardOrder = 450.0;
  static const _landmarkOrder = 500.0;
  static const _aheadOrder = 600.0;
  static const _horizonOrder = 700.0;
  static const _levelCardOrder = 800.0;
  static const _statusOrder = 900.0;

  /// The double pulse's keyframes (1 → 1.2 at .3 → 1 at .55 → 1.12 at .78).
  static double pulseScale(double t) {
    if (t <= 0 || t >= 1) return 1;
    final e = AppMotion.inOut.transform(t);
    const keys = [(0.0, 1.0), (.3, 1.2), (.55, 1.0), (.78, 1.12), (1.0, 1.0)];
    for (var i = 1; i < keys.length; i++) {
      final (at, value) = keys[i];
      if (e <= at) {
        final (from, start) = keys[i - 1];
        return start + (value - start) * (e - from) / (at - from);
      }
    }
    return 1;
  }

  String _label() {
    final level = scene.home.level;
    if (scene.kids) return 'home_map_named'.tr(args: [level.label]);
    if (scene.home.enrollment.levelLabel == HomeLevelLabel.grade) {
      return 'home_map_named'.tr(args: [level.name]);
    }
    return 'home_map_level'.tr(args: [level.label]);
  }

  double _rise(int j) {
    final rise = overrides.isleRise;
    if (j >= rise.length) return 1;
    return rise[j].clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final map = scene.map;
    final frame = scene.frame;
    final width = frame.width;
    final home = scene.home;
    final horizonOpen =
        overrides.horizonOpen ?? (home.level.completed ? 1.0 : 0.0);
    final next = home.level.next;
    final children = <Widget>[
      Positioned.fill(
        child: SeaLayer(
          tone: scene.tone,
          cefr: home.level.cefr,
          height: map.height,
          horizonY: map.horizonY,
          horizonOpen: horizonOpen,
          nextCefr: next?.cefr,
          // Under the horizon band, which hides them (map §13).
          waves: WavesLayer(
            height: map.height,
            scroll: scroll,
            running: loops.isOn(HomeLoop.waves),
          ),
        ),
      ),
      Positioned.fill(
        child: BridgesLayer(layout: map, fills: overrides.bridges),
      ),
      for (final (j, slot) in map.islands.indexed)
        if (slot.index != map.currentIndex)
          _compact(context, slot, _rise(j))
        else if (scene.island != null)
          _current(context, slot, _rise(j)),
      ..._reviewBox(context),
      ..._horizon(context, horizonOpen),
      ?_bridgeGuide(),
      ?_toast(),
    ];
    final closeCard = card == null ? null : actions.onCloseCard;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _label(),
      child: GestureDetector(
        onTap: closeCard,
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        child: SizedBox(
          width: width,
          height: map.height,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context, IslandSlot slot, double rise) {
    final unit = scene.home.units[slot.index];
    final done = unit.status == UnitLessonStatus.done;
    final pulse = overrides.pulse;
    final scale = pulse != null && pulse.island && pulse.index == slot.index
        ? pulseScale(pulse.t)
        : 1.0;
    final rect = Offset(slot.rect.left, slot.rect.top) & CompactIsland.size;
    return PositionedDirectional(
      start: scene.frame.startOf(rect),
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Semantics(
        sortKey: OrdinalSortKey((done ? _doneOrder : _aheadOrder) + slot.index),
        child: _Rise(
          t: rise,
          child: RepaintBoundary(
            child: Transform.scale(
              scale: scale,
              child: CompactIsland(
                unit: unit,
                slot: slot,
                tone: scene.tone,
                kids: scene.kids,
                shake: overrides.shakeIsland == slot.index
                    ? overrides.shakeT
                    : 0,
                clear: overrides.cloudsIsland == slot.index
                    ? overrides.clouds
                    : 0,
                flagWave: done && loops.isOn(HomeLoop.flags),
                fogRunning: loops.isOn(HomeLoop.clouds),
                onPressed: () => actions.onIsland(slot.index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _current(BuildContext context, IslandSlot slot, double rise) {
    final island = scene.island!;
    final unit = scene.unit!;
    final frame = scene.frame;
    final grow = overrides.islandGrow;
    Widget group = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IslandArt.current(
            layout: island,
            tone: scene.tone,
            unitIndex: slot.index,
            saturation:
                overrides.saturation ??
                HomeRules.saturation(unit, doneOverride: overrides.doneN),
            doneN: scene.doneN,
            segments: overrides.segments,
            last: scene.lastStone,
            lit: scene.doneN >= island.n - 1,
            flagUp: overrides.flagUp ?? 1,
            complete: scene.doneN >= island.n,
            frame: frame,
            flagWave: loops.isOn(HomeLoop.flags),
          ),
        ),
        _banner(island, unit),
        ..._labels(context, island, unit),
        ..._stones(island, unit),
        ?_parkedGuide(island),
        ?_bubble(island),
        ?_card(island, unit),
        if (kidSaying && scene.kids)
          PositionedDirectional(
            end: frame.scaled(kidSayEnd),
            top: kidSayTop,
            child: Semantics(
              sortKey: const OrdinalSortKey(_statusOrder),
              child: KidSayBubble(unit: unit),
            ),
          ),
      ],
    );
    if (grow != null) {
      group = Opacity(
        opacity: grow.opacity.clamp(0.0, 1.0),
        child: Transform.scale(scale: grow.scale, child: group),
      );
    }
    return PositionedDirectional(
      start: 0,
      top: slot.rect.top,
      width: frame.width,
      height: island.height,
      child: _Rise(
        t: rise,
        child: RepaintBoundary(child: group),
      ),
    );
  }

  Widget _banner(IslandLayout island, HomeUnit unit) {
    final rect = island.banner;
    return PositionedDirectional(
      end: rect.left,
      top: rect.top,
      child: Semantics(
        sortKey: const OrdinalSortKey(_bannerOrder),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: rect.width),
          child: scene.kids
              ? IslandBanner.kid(
                  unit: unit,
                  speaking: kidSaying,
                  onListen: actions.onKidListen,
                  onOpen: actions.onBanner,
                )
              : IslandBanner(
                  unit: unit,
                  emar: scene.emar,
                  onOpen: actions.onBanner,
                ),
        ),
      ),
    );
  }

  bool _landmark(int k, IslandLayout island) =>
      k == island.n - 1 && scene.lastStone != LastStone.none;

  /// The labels sit under the stones (map §5.5, §13), their chips kept
  /// [_labelMargin] inside the frame.
  List<Widget> _labels(
    BuildContext context,
    IslandLayout island,
    HomeUnit unit,
  ) {
    final frame = scene.frame;
    final station = island.station;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    ({double min, double max}) within(Rect rect) {
      final left = ltr ? frame.width - rect.right : rect.left;
      return (
        min: frame.left + _labelMargin - left,
        max: frame.left + frame.frame - _labelMargin - left,
      );
    }

    return [
      if (scene.reviewFirst && station != null)
        () {
          final rect = Rect.fromLTWH(
            station.dx - StoneLabel.width / 2,
            station.dy + StoneLabel.stationTop,
            StoneLabel.width,
            0,
          );
          return PositionedDirectional(
            start: frame.startOf(rect),
            top: rect.top,
            width: rect.width,
            child: const IgnorePointer(
              child: ExcludeSemantics(child: StoneLabel.station()),
            ),
          );
        }(),
      for (final (k, point) in island.stones.indexed)
        if (k < unit.lessons.length)
          () {
            final state = scene.stoneState(k, overrides);
            final landmark = _landmark(k, island);
            final top =
                point.dy +
                (landmark
                    ? StoneLabel.lastTop
                    : StoneLabel.topFrom(
                        diameter: Stone.diameterOf(state, kids: scene.kids),
                      ));
            final rect = Rect.fromLTWH(
              point.dx - StoneLabel.width / 2,
              top,
              StoneLabel.width,
              0,
            );
            return PositionedDirectional(
              start: frame.startOf(rect),
              top: top,
              width: rect.width,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: StoneLabel(
                    lesson: unit.lessons[k],
                    current: state == StoneState.current,
                    hit: overrides.hit == k,
                    emar: scene.emar,
                    last: landmark,
                    locked: state == StoneState.locked,
                    kids: scene.kids,
                    within: within(rect),
                  ),
                ),
              ),
            );
          }(),
    ];
  }

  static const _labelMargin = 4.0;

  Widget _centred(Offset point, Widget child) {
    final rect = Rect.fromCenter(
      center: point,
      width: stoneBox,
      height: stoneBox,
    );
    return PositionedDirectional(
      start: scene.frame.startOf(rect),
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Center(child: child),
    );
  }

  List<Widget> _stones(IslandLayout island, HomeUnit unit) {
    final pulsing = loops.isOn(HomeLoop.stonePulse);
    final pulse = overrides.pulse;
    final pop = overrides.stonePop;
    final station = island.station;
    return [
      if (scene.reviewFirst && station != null)
        _centred(
          Offset(math.max(_stationLeast, station.dx), station.dy),
          Semantics(
            sortKey: const OrdinalSortKey(_stoneOrder - 1),
            child: Stone.station(
              review: scene.home.review ?? const HomeReview(wordsDue: 0),
              pulse: pulsing,
              onPressed: actions.onStation,
            ),
          ),
        ),
      for (final (k, point) in island.stones.indexed)
        if (k < unit.lessons.length)
          () {
            final lesson = unit.lessons[k];
            final state = scene.stoneState(k, overrides);
            final landmark = _landmark(k, island);
            final scale = pulse != null && !pulse.island && pulse.index == k
                ? pulseScale(pulse.t)
                : 1.0;
            final Widget stone;
            if (scene.kids) {
              stone = Stone.kid(
                lesson: lesson,
                state: state,
                onPressed: () => actions.onStone(k),
              );
            } else if (landmark) {
              stone = Stone.last(
                lesson: lesson,
                state: state,
                emar: scene.emar,
                onPressed: () => actions.onStone(k),
              );
            } else {
              stone = Stone.lesson(
                lesson: lesson,
                index: k,
                state: state,
                emar: scene.emar,
                offline: offline,
                pulse:
                    pulsing &&
                    state == StoneState.current &&
                    !scene.reviewFirst &&
                    scene.bubbleFrame != null,
                hit: overrides.hit == k,
                pop: pop != null && pop.index == k ? pop.t : 1,
                onPressed: () => actions.onStone(k),
              );
            }
            return _centred(
              landmark ? point.translate(0, -landmarkLift) : point,
              Semantics(
                sortKey: OrdinalSortKey(
                  landmark ? _landmarkOrder : _stoneOrder + k,
                ),
                child: Transform.scale(scale: scale, child: stone),
              ),
            );
          }(),
    ];
  }

  Widget _guideAt(Offset centre, {double lean = 0}) {
    final rect = Rect.fromCenter(
      center: centre,
      width: guideSize,
      height: guideSize,
    );
    Widget guide = Mascot(
      expression: guideExpression,
      size: guideSize,
      sparkles: false,
      animate: loops.isOn(HomeLoop.guideBreath),
    );
    if (lean != 0) {
      guide = Transform.rotate(angle: lean * math.pi / 180, child: guide);
    }
    return PositionedDirectional(
      start: scene.frame.startOf(rect),
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(child: ExcludeSemantics(child: guide)),
    );
  }

  /// The guide parked on the current island: beside a stone, hopping between
  /// two, or by the kids' banner (motion §2, D28).
  Widget? _parkedGuide(IslandLayout island) => switch (guide) {
    GuideBesideStone(:final index) => _guideAt(island.spot(index)),
    GuideHop(:final from, :final to, :final t) => _guideAt(
      Offset.lerp(island.spot(from), island.spot(to), t)! +
          Offset(0, -math.sin(t * math.pi) * AppMotion.homeHopHeight),
    ),
    GuideOnBanner() => _guideAt(
      Offset(
        scene.frame.fromEnd(bannerGuide.dx) + guideSize / 2,
        bannerGuide.dy + guideSize / 2,
      ),
    ),
    _ => null,
  };

  /// The guide crossing a bridge, in the map's own space.
  Widget? _bridgeGuide() {
    final guide = this.guide;
    if (guide is! GuideOnBridge) return null;
    final bridges = scene.map.bridges;
    if (guide.bridge < 0 || guide.bridge >= bridges.length) return null;
    final bridge = bridges[guide.bridge];
    final at = Offset.lerp(bridge.p0, bridge.p3, guide.t)!;
    return _guideAt(
      at.translate(0, guideSize / 2 - bridgeLift),
      lean: bridgeLean,
    );
  }

  Widget? _bubble(IslandLayout island) {
    final frame = scene.bubbleFrame;
    if (frame == null || !overrides.bubbleVisible) return null;
    final rect = Rect.fromLTRB(frame.x0, 0, frame.x1, 0);
    return PositionedDirectional(
      start: scene.frame.startOf(rect),
      top: island.bubbleCenterY,
      width: frame.width,
      child: FractionalTranslation(
        translation: const Offset(0, -.5),
        child: Semantics(
          sortKey: const OrdinalSortKey(_bubbleOrder),
          child: KeyedSubtree(
            key: bubbleKey,
            child: LessonBubble(
              mode: scene.bubbleMode,
              home: scene.home,
              lesson: scene.bubbleLesson,
              frame: frame,
              centerY: island.bubbleCenterY,
              overrides: overrides,
              opacity: island.bubbleOpacity.clamp(0.0, 1.0),
              onPressed: actions.onBubble,
            ),
          ),
        ),
      ),
    );
  }

  /// A stone's card, under it above the gap, over it below (map §12).
  Widget? _card(IslandLayout island, HomeUnit unit) {
    final k = card;
    if (k == null || k < 0 || k >= unit.lessons.length) return null;
    final state = scene.stoneState(k, overrides);
    final landmark = _landmark(k, island);
    final above = island.rowOf(k) > island.clear;
    final rect = StoneCard.place(
      stone: island.stones[k],
      last: landmark,
      above: above,
      frame: scene.frame,
    );
    final String? after;
    if (scene.reviewFirst && state == StoneState.current) {
      after = 'home_review_title'.tr();
    } else if (landmark || k == 0) {
      after = null;
    } else {
      after = unit.lessons[k - 1].title;
    }
    return PositionedDirectional(
      start: scene.frame.startOf(rect),
      width: rect.width,
      top: above ? null : rect.top,
      bottom: above ? island.height - rect.bottom : null,
      child: Semantics(
        sortKey: const OrdinalSortKey(_cardOrder),
        child: StoneCard(
          lesson: unit.lessons[k],
          index: k,
          state: state,
          lockedAfter: after,
          reviewFirst: scene.reviewFirst && state == StoneState.current,
          onReplay: () => actions.onReplay(k),
          onStart: () => actions.onStart(k),
        ),
      ),
    );
  }

  List<Widget> _reviewBox(BuildContext context) {
    final rect = scene.map.reviewBox;
    final review = scene.home.review;
    if (!scene.reviewBox || rect == null || review == null) return const [];
    final t = AppMotion.homeEmphasis.transform(overrides.boxIn.clamp(0, 1));
    return [
      PositionedDirectional(
        start: scene.frame.startOf(rect),
        top: rect.top,
        width: rect.width,
        child: Semantics(
          sortKey: const OrdinalSortKey(_boxOrder),
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, AppMotion.homeBoxRise * (1 - t)),
              child: AnimatedBuilder(
                animation: loops.boxFloat,
                child: ReviewBox(
                  review: review,
                  onPressed: actions.onReviewBox,
                ),
                builder: (context, box) => Transform.translate(
                  offset: Offset(
                    0,
                    -AppMotion.homeBoxFloatDistance * loops.boxFloat.value,
                  ),
                  child: box,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _horizon(BuildContext context, double open) {
    final home = scene.home;
    final next = home.level.next;
    final map = scene.map;
    final grade = home.enrollment.levelLabel == HomeLevelLabel.grade;
    return [
      if (!scene.kids && next != null && open < 1)
        PositionedDirectional(
          start: 0,
          end: 0,
          top: map.horizonY - HorizonFlag.rise,
          child: Semantics(
            sortKey: const OrdinalSortKey(_horizonOrder),
            child: Opacity(
              opacity: 1 - open.clamp(0.0, 1.0),
              child: Center(
                child: HorizonFlag(
                  text: grade
                      ? 'home_next_grade'.tr(args: [next.label])
                      : 'home_next_level'.tr(args: [next.label]),
                ),
              ),
            ),
          ),
        ),
      if (levelCard && !scene.kids && next != null)
        PositionedDirectional(
          start: scene.frame.fromEnd(levelCardSide),
          end: scene.frame.fromEnd(levelCardSide),
          top: map.horizonY + levelCardTop,
          child: Semantics(
            sortKey: const OrdinalSortKey(_levelCardOrder),
            child: _Rise(
              t: overrides.levelCardIn,
              distance: AppMotion.homeLevelCardRise,
              child: LevelCompleteCard(
                home: home,
                showGuide: guide is GuideOnCard,
                onStart: actions.onStartLevel,
              ),
            ),
          ),
        ),
    ];
  }

  Widget? _toast() {
    final i = toast;
    if (i == null || i < 0 || i >= scene.map.islands.length) return null;
    final slot = scene.map.islands[i];
    final unit = scene.home.units[i];
    final before = unit.lockedBy?.number ?? math.max(1, unit.number - 1);
    return PositionedDirectional(
      end: slot.rect.left + LockedToast.inset,
      top: slot.rect.top - LockedToast.lift,
      child: Semantics(
        sortKey: const OrdinalSortKey(_statusOrder),
        child: IgnorePointer(
          child: LockedToast(
            text: 'home_opens_after_unit'.tr(args: ['$before']),
          ),
        ),
      ),
    );
  }
}

/// An island, or a card, rising into place: [t] of the way, from
/// [distance] below, fading in (M1, M7).
class _Rise extends StatelessWidget {
  const _Rise({
    required this.t,
    required this.child,
    this.distance = AppMotion.homeRiseDistance,
  });

  final double t;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t >= 1) return child;
    final e = AppMotion.homeEmphasis.transform(t.clamp(0, 1));
    return Opacity(
      opacity: e.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, distance * (1 - e)),
        child: child,
      ),
    );
  }
}
