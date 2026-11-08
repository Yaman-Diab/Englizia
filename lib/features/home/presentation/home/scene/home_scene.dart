import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:equatable/equatable.dart';

/// Where the one guide (بلبل) stands on home: one place at a time (design
/// "Home Archipelago").
sealed class GuidePlacement extends Equatable {
  const GuidePlacement();

  @override
  List<Object?> get props => const [];
}

/// In the goal ring; for kids and on a v0.1 server, the 80 slot in its place.
final class GuideInRing extends GuidePlacement {
  const GuideInRing();
}

/// Parked beside stone [index]; -1 is the review station.
final class GuideBesideStone extends GuidePlacement {
  const GuideBesideStone(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// Hopping from stone [from] to stone [to], [t] of the way (its height is
/// `−sin(tπ)·AppMotion.homeHopHeight`).
final class GuideHop extends GuidePlacement {
  const GuideHop(this.from, this.to, this.t);

  final int from;
  final int to;
  final double t;

  @override
  List<Object?> get props => [from, to, t];
}

/// Flying over bridge [bridge], [t] of the way (eased): from beside its
/// island's last stone, where it was parked, to the next island.
final class GuideOnBridge extends GuidePlacement {
  const GuideOnBridge(this.bridge, this.t);

  final int bridge;
  final double t;

  @override
  List<Object?> get props => [bridge, t];
}

/// Kids: standing by the island's banner, saying the unit's name (M14).
final class GuideOnBanner extends GuidePlacement {
  const GuideOnBanner();
}

/// On a freeze, broke or level card.
final class GuideOnCard extends GuidePlacement {
  const GuideOnCard();
}

/// Hanging from the top bar while the map is pulled.
final class GuideHanging extends GuidePlacement {
  const GuideHanging();
}

/// In the back-to-lesson button.
final class GuideInBackButton extends GuidePlacement {
  const GuideInBackButton();
}

/// In flight: only the flight layer draws it.
final class GuideFlying extends GuidePlacement {
  const GuideFlying();
}

/// Where the guide is when nothing moves it ([forced] when something does).
GuidePlacement resolveGuide({
  required bool flying,
  required bool collapsed,
  required bool hasCurrentIsland,
  required bool backButton,
  required double pull,
  required bool levelCardShown,
  required HomeCardNotice card,
  required int current,
  GuidePlacement? forced,
}) {
  if (forced != null) return forced;
  if (flying) return const GuideFlying();
  if (collapsed && hasCurrentIsland) {
    return backButton ? const GuideInBackButton() : GuideBesideStone(current);
  }
  if (pull >= AppMotion.homePullGuideAt) return const GuideHanging();
  if (levelCardShown ||
      card == HomeCardNotice.freeze ||
      card == HomeCardNotice.broke ||
      card == HomeCardNotice.levelDone) {
    return const GuideOnCard();
  }
  return const GuideInRing();
}

/// The ring shows today's minutes inside once the guide has left it, while
/// the header is still mostly open.
bool ringShowsMinutes({
  required bool kids,
  required GuidePlacement guide,
  required StageMetrics m,
}) => !kids && guide is! GuideInRing && m.collapse < m.head / 2;

/// What a motion draws on the map instead of the data, for its frame. Null
/// (or the default) draws the data.
final class MapOverrides extends Equatable {
  const MapOverrides({
    this.done,
    this.cur,
    this.unitIndex,
    this.segments = const {},
    this.bridges = const {},
    this.saturation,
    this.flagUp,
    this.cloudsIsland,
    this.clouds = 0,
    this.lockOpen = 0,
    this.rowFrom,
    this.rowT = 1,
    this.tail,
    this.bubbleVisible = true,
    this.bubbleScale = 1,
    this.bubbleContent = 1,
    this.bubbleIn = 1,
    this.stonePop,
    this.pulse,
    this.hit,
    this.islandGrow,
    this.mapOpacity = 1,
    this.isleRise = const [],
    this.boxIn = 1,
    this.horizonOpen,
    this.levelCardIn = 1,
    this.shakeIsland,
    this.shakeT = 0,
    this.guideExpression,
    this.snapshot,
  });

  /// The current island as drawn: its lessons done (by index, in any order:
  /// Emar's may be done out of turn), the current one, its unit.
  final Set<int>? done;
  final int? cur;
  final int? unitIndex;

  /// Trail segment j, bridge k: how much is drawn, 0 to 1.
  final Map<int, double> segments;
  final Map<int, double> bridges;
  final double? saturation;
  final double? flagUp;

  /// M6: the island whose clouds clear (and lock opens), [clouds] of the way.
  final int? cloudsIsland;
  final double clouds;

  /// M6: how far that island's lock has opened (it lifts, turns and fades).
  final double lockOpen;

  /// 09ب: the rows move from the gap after [rowFrom], [rowT] of the way.
  final int? rowFrom;
  final double rowT;

  /// The bubble's tail between stones [a] and [b], [t] of the way.
  final ({int a, int b, double t})? tail;
  final bool bubbleVisible;
  final double bubbleScale;
  final double bubbleContent;
  final double bubbleIn;

  /// A stone popping: .7 → 1.12 at .6 → 1.
  final ({int index, double t})? stonePop;

  /// A double pulse (1 → 1.2 at .3 → 1 at .55 → 1.12 at .78 → 1), of a stone
  /// or, with [island], an island.
  final ({int index, double t, bool island})? pulse;

  /// Emar: the stone a page search found (highlighted 2.4 s).
  final int? hit;
  final ({double scale, double opacity})? islandGrow;
  final double mapOpacity;

  /// M1: each island's rise, from the top, 0 to 1.
  final List<double> isleRise;
  final double boxIn;
  final double? horizonOpen;
  final double levelCardIn;

  /// M9: the locked island shaking, [shakeT] of the way.
  final int? shakeIsland;
  final double shakeT;
  final MascotExpression? guideExpression;

  /// Drawn instead of the state's home (M6 draws the day before until the
  /// unit finishes).
  final HomeSnapshot? snapshot;

  static const none = MapOverrides();

  /// A field can't be cleared this way: build a new one for that.
  MapOverrides copyWith({
    Set<int>? done,
    int? cur,
    int? unitIndex,
    Map<int, double>? segments,
    Map<int, double>? bridges,
    double? saturation,
    double? flagUp,
    int? cloudsIsland,
    double? clouds,
    double? lockOpen,
    int? rowFrom,
    double? rowT,
    ({int a, int b, double t})? tail,
    bool? bubbleVisible,
    double? bubbleScale,
    double? bubbleContent,
    double? bubbleIn,
    ({int index, double t})? stonePop,
    ({int index, double t, bool island})? pulse,
    int? hit,
    ({double scale, double opacity})? islandGrow,
    double? mapOpacity,
    List<double>? isleRise,
    double? boxIn,
    double? horizonOpen,
    double? levelCardIn,
    int? shakeIsland,
    double? shakeT,
    MascotExpression? guideExpression,
    HomeSnapshot? snapshot,
  }) => MapOverrides(
    done: done ?? this.done,
    cur: cur ?? this.cur,
    unitIndex: unitIndex ?? this.unitIndex,
    segments: segments ?? this.segments,
    bridges: bridges ?? this.bridges,
    saturation: saturation ?? this.saturation,
    flagUp: flagUp ?? this.flagUp,
    cloudsIsland: cloudsIsland ?? this.cloudsIsland,
    clouds: clouds ?? this.clouds,
    lockOpen: lockOpen ?? this.lockOpen,
    rowFrom: rowFrom ?? this.rowFrom,
    rowT: rowT ?? this.rowT,
    tail: tail ?? this.tail,
    bubbleVisible: bubbleVisible ?? this.bubbleVisible,
    bubbleScale: bubbleScale ?? this.bubbleScale,
    bubbleContent: bubbleContent ?? this.bubbleContent,
    bubbleIn: bubbleIn ?? this.bubbleIn,
    stonePop: stonePop ?? this.stonePop,
    pulse: pulse ?? this.pulse,
    hit: hit ?? this.hit,
    islandGrow: islandGrow ?? this.islandGrow,
    mapOpacity: mapOpacity ?? this.mapOpacity,
    isleRise: isleRise ?? this.isleRise,
    boxIn: boxIn ?? this.boxIn,
    horizonOpen: horizonOpen ?? this.horizonOpen,
    levelCardIn: levelCardIn ?? this.levelCardIn,
    shakeIsland: shakeIsland ?? this.shakeIsland,
    shakeT: shakeT ?? this.shakeT,
    guideExpression: guideExpression ?? this.guideExpression,
    snapshot: snapshot ?? this.snapshot,
  );

  @override
  List<Object?> get props => [
    done,
    cur,
    unitIndex,
    segments,
    bridges,
    saturation,
    flagUp,
    cloudsIsland,
    clouds,
    lockOpen,
    rowFrom,
    rowT,
    tail,
    bubbleVisible,
    bubbleScale,
    bubbleContent,
    bubbleIn,
    stonePop,
    pulse,
    hit,
    islandGrow,
    mapOpacity,
    isleRise,
    boxIn,
    horizonOpen,
    levelCardIn,
    shakeIsland,
    shakeT,
    guideExpression,
    snapshot,
  ];
}

/// What a motion draws in the header instead of the data.
final class HeaderOverrides extends Equatable {
  const HeaderOverrides({
    this.ringFraction,
    this.minutes,
    this.ringSuccess,
    this.streak,
    this.streakRoll,
    this.flameFlip = 0,
    this.ringArcIn = 1,
    this.ringGuideIn = 1,
    this.guideJump = 0,
    this.guideHop = 0,
    this.ringSparks,
    this.freezeGlint,
    this.contentShift = 0,
  });

  final double? ringFraction;
  final int? minutes;
  final bool? ringSuccess;

  /// The streak rolling [from] → [to], [streakRoll] of the way.
  final ({int from, int to})? streak;
  final double? streakRoll;
  final double flameFlip;
  final double ringArcIn;
  final double ringGuideIn;
  final double guideJump;
  final double guideHop;
  final double? ringSparks;
  final double? freezeGlint;

  /// A card closing: the map and the level header move up from this far.
  final double contentShift;

  static const none = HeaderOverrides();

  /// A field can't be cleared this way: build a new one for that.
  HeaderOverrides copyWith({
    double? ringFraction,
    int? minutes,
    bool? ringSuccess,
    ({int from, int to})? streak,
    double? streakRoll,
    double? flameFlip,
    double? ringArcIn,
    double? ringGuideIn,
    double? guideJump,
    double? guideHop,
    double? ringSparks,
    double? freezeGlint,
    double? contentShift,
  }) => HeaderOverrides(
    ringFraction: ringFraction ?? this.ringFraction,
    minutes: minutes ?? this.minutes,
    ringSuccess: ringSuccess ?? this.ringSuccess,
    streak: streak ?? this.streak,
    streakRoll: streakRoll ?? this.streakRoll,
    flameFlip: flameFlip ?? this.flameFlip,
    ringArcIn: ringArcIn ?? this.ringArcIn,
    ringGuideIn: ringGuideIn ?? this.ringGuideIn,
    guideJump: guideJump ?? this.guideJump,
    guideHop: guideHop ?? this.guideHop,
    ringSparks: ringSparks ?? this.ringSparks,
    freezeGlint: freezeGlint ?? this.freezeGlint,
    contentShift: contentShift ?? this.contentShift,
  );

  @override
  List<Object?> get props => [
    ringFraction,
    minutes,
    ringSuccess,
    streak,
    streakRoll,
    flameFlip,
    ringArcIn,
    ringGuideIn,
    guideJump,
    guideHop,
    ringSparks,
    freezeGlint,
    contentShift,
  ];
}
