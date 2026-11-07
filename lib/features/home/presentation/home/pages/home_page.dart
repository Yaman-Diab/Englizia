import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_banner.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/motion/choreographer.dart';
import 'package:englizia/features/home/presentation/home/motion/flight_layer.dart';
import 'package:englizia/features/home/presentation/home/motion/loop_budget.dart';
import 'package:englizia/features/home/presentation/home/motion/pull_guide.dart';
import 'package:englizia/features/home/presentation/home/motion/skip_layer.dart';
import 'package:englizia/features/home/presentation/home/paint/island_art.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/day_header.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/goal_ring.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/say_bubble.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/top_bar.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/back_to_lesson_button.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/lesson_bubble.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/stone.dart';
import 'package:englizia/features/home/presentation/home/widgets/sheets/locked_unit_sheet.dart';
import 'package:englizia/features/home/presentation/home/widgets/sheets/page_search_sheet.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/home_map.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/home_stage.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/level_header.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/map_scroll_view.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/stage_controller.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/connection_strip.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/home_no_data.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/home_skeleton.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/switch_strip.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/me/widgets/me_sheets.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where home's taps lead; the router gives them.
final class HomeActions {
  const HomeActions({
    required this.openLesson,
    required this.openUnit,
    required this.openReview,
    required this.openPlacement,
    required this.openMe,
    required this.joinTrack,
    this.openDev,
  });

  /// As a unit's screen opens a lesson.
  final void Function(UnitLesson lesson, {required bool kids}) openLesson;

  /// A unit's screen, by its id: done, open, current or a locked preview.
  final ValueChanged<String> openUnit;

  /// The word review (kids: their own).
  final VoidCallback openReview;
  final VoidCallback openPlacement;

  /// «أنا», for «هذا الأسبوع في «أنا»».
  final VoidCallback openMe;

  /// The tracks sheet's «أضف مسارًا», as on «أنا».
  final ValueChanged<LearningTrack> joinTrack;

  /// Mock mode only: the dev page, from a long press on the top bar.
  final VoidCallback? openDev;
}

/// The «تعلّم» tab (S §6.1, design "Home Archipelago"): the level as an
/// archipelago, one island per unit, today's island open with its stones and
/// the next lesson's bubble, under a day header that folds as the map
/// scrolls. It opens pinned on today's island with the header open, plays
/// the day's opening once, and on coming back from a lesson celebrates what
/// changed.
///
/// Reads the [VerifyEmailCubit] for the email reminder and the [MeCubit]
/// for the tracks sheet when the route provides them.
class HomePage extends StatefulWidget {
  const HomePage({required this.actions, required this.pages, super.key});

  final HomeActions actions;

  /// The navigator's page routes: a page that covers home and closes again
  /// is a return (a lesson, a unit); a sheet or a dialog isn't one.
  final RouteObserver<PageRoute<dynamic>> pages;

  /// The kids' shell and bar.
  static bool isKids(HomeState state) => state.kids;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, RouteAware {
  final _scroll = ScrollController();
  late final _stage = StageController(
    vsync: this,
    reduceMotion: () => _reduceMotion,
  );
  late final _flights = FlightLayerController(vsync: this);
  late final HomeChoreographer _choreo;
  final _guideTap = GuideTapController();
  late final AppLifecycleListener _lifecycle;
  final _mainKey = GlobalKey();
  final _bubbleKey = GlobalKey();
  final _cardGuideKey = GlobalKey();
  late final HomeCubit _cubit;

  bool _reduceMotion = false;
  bool _onTop = true;

  /// The route [HomePage.pages] reports on.
  PageRoute<dynamic>? _route;

  /// The map as last built: the day before when a moment arrives.
  HomeMapScene? _scene;

  /// The header: the design's height as last used, and how much taller it
  /// was measured.
  double _formula = 0;
  double _extra = 0;
  double? _topSlot;

  /// The enrollment and level the scroll was last anchored for.
  String? _anchoredFor;
  bool _anchoring = false;
  bool _openingStarted = false;

  int _momentId = 0;
  int _switches = 0;
  String? _switchTitle;
  Timer? _switchTimer;
  Timer? _failedTimer;

  int? _card;
  int? _toast;
  Timer? _toastTimer;

  BackDirection? _backDir;
  bool _backEver = false;
  bool _arrived = false;
  bool _backShowing = false;
  bool _returning = false;

  bool _collapsed = false;
  bool _hanging = false;
  String? _glinted;

  /// The map's motions, the loops that run and the guide's tap; a flight
  /// starting or landing comes through the choreographer.
  Listenable get _motion =>
      Listenable.merge([_choreo, _choreo.loops, _guideTap]);

  @override
  void initState() {
    super.initState();
    _cubit = context.read<HomeCubit>();
    _choreo = HomeChoreographer(
      vsync: this,
      reduceMotion: () => _reduceMotion,
      stage: _stage,
      cubit: _cubit,
      flights: _flights,
    );
    _stage
      ..attach(_scroll)
      ..collapsedChanged = _onCollapsed
      ..holdSnap = (() => _choreo.busy)
      ..onIdle = _onIdle
      ..addListener(_onStage);
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(_cubit.refresh()),
    );
    _momentId = _cubit.state.momentId;
    _switches = _cubit.state.switches;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduceMotion(context);
    _onTop = ModalRoute.isCurrentOf(context) ?? true;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      widget.pages.unsubscribe(this);
      widget.pages.subscribe(this, _route = route);
    }
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final route = _route;
    if (oldWidget.pages == widget.pages || route == null) return;
    oldWidget.pages.unsubscribe(this);
    widget.pages.subscribe(this, route);
  }

  // A lesson or a unit over home, and back: what it changed shows.

  @override
  void didPushNext() => _cubit.left();

  @override
  void didPopNext() => unawaited(_cubit.returned());

  @override
  void dispose() {
    widget.pages.unsubscribe(this);
    _switchTimer?.cancel();
    _failedTimer?.cancel();
    _toastTimer?.cancel();
    _lifecycle.dispose();
    _choreo.dispose();
    _flights.dispose();
    _stage.dispose();
    _scroll.dispose();
    _guideTap.dispose();
    super.dispose();
  }

  // The state's reactions.

  void _onState(BuildContext context, HomeState state) {
    if (state.refreshFailed) {
      _failedTimer ??= Timer(AppMotion.homeFailedHold, () {
        _failedTimer = null;
        if (mounted) _cubit.dismissRefreshFailure();
      });
    } else {
      _failedTimer?.cancel();
      _failedTimer = null;
    }
    if (state.switches != _switches) {
      _switches = state.switches;
      _switchTimer?.cancel();
      setState(() => _switchTitle = state.switchedTo);
      _switchTimer = Timer(AppMotion.toastHold, () {
        if (mounted) setState(() => _switchTitle = null);
      });
    }
    if (state.momentId != _momentId) {
      _momentId = state.momentId;
      final moment = state.moment;
      if (moment != null) _play(moment);
    }
    _budget();
    _checkBack();
  }

  /// A return's moment, played on the map as it was drawn the day before.
  void _play(HomeMoment moment) {
    final scene = _scene;
    final island = scene?.island;
    if (scene == null || island == null) {
      _cubit.momentPlayed();
      return;
    }
    _closeCard();
    unawaited(
      _choreo.playMoment(
        moment,
        layout: island,
        map: scene.map,
        after: () => _scene?.map ?? scene.map,
      ),
    );
  }

  // The stage's reactions.

  void _onStage() {
    final metrics = _stage.metrics;
    final collapsed = metrics.collapsed;
    final hanging = metrics.pull >= AppMotion.homePullGuideAt;
    if (collapsed == _collapsed && hanging == _hanging) return;
    if (collapsed && !_collapsed) _guideTap.clear();
    _collapsed = collapsed;
    _hanging = hanging;
    if (mounted) setState(() {});
  }

  void _onCollapsed(bool collapsed) {
    if (_scene?.island == null || _backDir != null || _backShowing) return;
    unawaited(_choreo.modeFlip(collapsed: collapsed));
  }

  void _onIdle() {
    if (!mounted) return;
    _checkBack();
    _budget();
  }

  /// What shows of the map now, in its own coordinates.
  ({double top, double bottom}) _shown() {
    final metrics = _stage.metrics;
    final top = metrics.scroll - metrics.pt;
    return (top: top, bottom: top + metrics.view);
  }

  /// The ambient loops that may run, of those on screen (M2).
  void _budget() {
    final scene = _scene;
    final home = _cubit.state.home;
    if (scene == null || home == null || !mounted) return;
    final shown = _shown();
    bool shows(Rect rect) => rect.bottom > shown.top && rect.top < shown.bottom;
    var clouds = 0;
    var flags = 0;
    for (final slot in scene.map.islands) {
      if (slot.index == scene.map.currentIndex || !shows(slot.rect)) continue;
      switch (slot.status) {
        case UnitLessonStatus.locked:
          clouds += _cloudsPerIsland;
        case UnitLessonStatus.done:
          flags++;
        case UnitLessonStatus.open || UnitLessonStatus.current:
          break;
      }
    }
    final target = scene.target;
    final stone =
        target != null &&
        shows(
          Rect.fromCircle(
            center: target.translate(0, scene.islandTop),
            radius: _stoneReach,
          ),
        );
    final box = scene.map.reviewBox;
    _choreo.budget(
      {
        HomeLoop.flame: _cubit.state.atRisk,
        HomeLoop.stonePulse: stone && scene.bubbleFrame != null,
        HomeLoop.guideBreath: true,
        HomeLoop.reviewBox: scene.reviewBox && box != null && shows(box),
        HomeLoop.waves: true,
        HomeLoop.clouds: clouds > 0,
        HomeLoop.flags: flags > 0,
      },
      counts: {HomeLoop.clouds: clouds, HomeLoop.flags: flags},
    );
  }

  static const _cloudsPerIsland = 3;
  static const _stoneReach = 40.0;

  /// The back-to-lesson button: the current stone above the
  /// level header's edge or under the view's bottom.
  void _checkBack() {
    final scene = _scene;
    // Pressed: it stays until the map arrives.
    if (scene == null || _returning) return;
    BackDirection? direction;
    final target = scene.target;
    if (target != null && _onTop && !_choreo.busy && !_stage.pulling) {
      final metrics = _stage.metrics;
      final y = metrics.pt + scene.islandTop + target.dy - metrics.scroll;
      final top = metrics.pt - metrics.collapse;
      if (y < top - _backAbove) {
        direction = BackDirection.up;
      } else if (y > metrics.view - _backBelow) {
        direction = BackDirection.down;
      }
    }
    unawaited(_setBack(direction));
  }

  static const _backAbove = 8.0;
  static const _backBelow = 24.0;

  Future<void> _setBack(BackDirection? direction) async {
    if (_backShowing) return;
    if (direction == _backDir) return;
    if (direction == null) {
      setState(() {
        _backDir = null;
        _arrived = false;
      });
      _choreo.backButtonHidden();
      return;
    }
    if (_backDir != null) {
      setState(() => _backDir = direction);
      return;
    }
    // The guide flies into the button first, then it pops.
    _backShowing = true;
    try {
      await _choreo.backButtonShown();
    } finally {
      _backShowing = false;
    }
    if (!mounted) return;
    setState(() {
      _backDir = direction;
      _backEver = true;
      _arrived = !_reduceMotion;
    });
    _checkBack();
  }

  /// The back button: to today's island with the header kept folded, then
  /// the guide flies back beside the stone. Pressed again on
  /// the way, it's already going.
  Future<void> _back() async {
    final scene = _scene;
    final slot = scene?.map.current;
    if (scene == null || slot == null || _returning) return;
    _closeCard();
    _returning = true;
    try {
      await _stage.scrollTo(
        _islandOffset(scene, slot),
        AppMotion.homeBackScroll,
      );
      if (!mounted) return;
      setState(() {
        _backDir = null;
        _arrived = false;
      });
      await _choreo.backButtonLanded();
    } finally {
      _returning = false;
    }
  }

  /// Today's island just under the folded header.
  double _islandOffset(HomeMapScene scene, IslandSlot slot) =>
      _stage.head +
      slot.rect.top -
      (scene.map.anchor.box == BoxPlace.top ? _boxAbove : _plainAbove);

  static const _boxAbove = 62.0;
  static const _plainAbove = 10.0;

  // Header sizes.

  /// The header measured taller than the design's: untouched, the map
  /// opens on its anchor for the measured height; once moved, it shifts by
  /// the difference so nothing under the finger jumps.
  void _onHead(double measured) {
    if (!mounted) return;
    final extra = math.max(0.0, measured - _formula);
    final delta = extra - _extra;
    if (delta.abs() < .5) return;
    setState(() => _extra = extra);
    if (_anchoredFor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_stage.moved) {
        _stage.shiftScroll(delta);
      } else {
        _toAnchor();
      }
    });
  }

  void _onTopSlot(double measured) {
    if (!mounted || ((_topSlot ?? -1) - measured).abs() < .5) return;
    setState(() => _topSlot = measured);
  }

  /// Once per enrollment and level, after the first layout: the map opens on
  /// today's island with the header open, then the day's opening plays.
  void _scheduleAnchor(HomeSnapshot home) {
    final key = '${home.enrollment.id}|${home.level.id}';
    if (_anchoredFor == key || _anchoring) return;
    _anchoring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchoring = false;
      if (!mounted) return;
      final scene = _scene;
      if (scene == null || !_scroll.hasClients) {
        setState(() {});
        return;
      }
      _toAnchor();
      _anchoredFor = key;
      _checkBack();
      _budget();
      final state = _cubit.state;
      final now = state.home;
      if (state.openingDue && !_openingStarted && now != null) {
        _openingStarted = true;
        unawaited(_choreo.playOpening(now));
      }
    });
  }

  /// Today's island where the design opens it, the header open.
  void _toAnchor() {
    final scene = _scene;
    if (scene == null) return;
    final metrics = _stage.metrics;
    _stage.jumpTo(scene.map.initialScroll(pt: metrics.pt, view: metrics.view));
  }

  // Taps.

  void _closeCard() {
    if (_card != null && mounted) setState(() => _card = null);
  }

  Rect? _globalRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// [key]'s box in the stage's right-to-left frame.
  Rect? _stageRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final main = _mainKey.currentContext?.findRenderObject();
    if (box is! RenderBox || main is! RenderBox || !box.hasSize) return null;
    final rect = box.localToGlobal(Offset.zero, ancestor: main) & box.size;
    if (Directionality.of(context) == TextDirection.rtl) return rect;
    return Rect.fromLTWH(
      main.size.width - rect.right,
      rect.top,
      rect.width,
      rect.height,
    );
  }

  void _openLesson(HomeLesson lesson, {bool grow = false}) {
    final home = _cubit.state.home;
    if (home == null) return;
    _closeCard();
    void push() => widget.actions.openLesson(lesson.base, kids: home.kids);
    final rect = grow ? _globalRect(_bubbleKey) : null;
    if (rect == null) {
      push();
    } else {
      unawaited(_choreo.openLesson(rect, push));
    }
  }

  void _onBubble() {
    final scene = _scene;
    if (scene == null) return;
    if (scene.reviewFirst) {
      _closeCard();
      widget.actions.openReview();
      return;
    }
    final lesson = scene.bubbleLesson;
    if (lesson != null) _openLesson(lesson, grow: true);
  }

  void _onStone(int k) {
    final scene = _scene;
    final unit = scene?.unit;
    if (scene == null || unit == null || k >= unit.lessons.length) return;
    final state = scene.stoneState(k);
    if (state == StoneState.current &&
        scene.bubbleFrame != null &&
        !scene.reviewFirst) {
      _onBubble();
      return;
    }
    if (scene.kids) {
      // No cards for kids; a done stone replays its lesson.
      if (state == StoneState.done) _openLesson(unit.lessons[k]);
      return;
    }
    setState(() => _card = _card == k ? null : k);
  }

  void _onCardLesson(int k) {
    final unit = _scene?.unit;
    if (unit == null || k >= unit.lessons.length) return;
    _openLesson(unit.lessons[k]);
  }

  void _onIsland(int index) {
    final home = _cubit.state.home;
    final unit = _scene?.home.units[index];
    if (home == null || unit == null) return;
    _closeCard();
    if (unit.status == UnitLessonStatus.locked) {
      _locked(index);
    } else {
      widget.actions.openUnit(unit.id);
    }
  }

  /// M9: the island shakes, says when it opens, then shows its preview.
  void _locked(int index) {
    unawaited(_choreo.lockedTap(index));
    setState(() => _toast = index);
    _toastTimer?.cancel();
    _toastTimer = Timer(
      _reduceMotion ? Duration.zero : AppMotion.homeToastHold,
      () => unawaited(_preview(index)),
    );
  }

  Future<void> _preview(int index) async {
    if (!mounted) return;
    setState(() => _toast = null);
    final home = _cubit.state.home;
    final current = home?.currentUnit;
    if (home == null || current == null || index >= home.units.length) return;
    final unit = home.units[index];
    final action = await showLockedUnitSheet(
      context,
      unit: unit,
      current: current,
    );
    if (!mounted) return;
    switch (action) {
      case LockedSheetAction.goToCurrent:
        await Future<void>.delayed(AppMotion.homeGoDelay);
        if (mounted) await _goToCurrent();
      case LockedSheetAction.openUnit:
        widget.actions.openUnit(unit.id);
      case null:
        break;
    }
  }

  /// «اذهب إلى الوحدة 3»: today's island, folding the header, then the
  /// current stone's double pulse.
  Future<void> _goToCurrent() async {
    final scene = _scene;
    final slot = scene?.map.current;
    if (scene == null || slot == null) return;
    await _stage.scrollTo(_islandOffset(scene, slot), AppMotion.homeGoScroll);
    if (!mounted) return;
    _checkBack();
    unawaited(_choreo.pulseStone(scene.current));
  }

  Future<void> _openPageSearch() async {
    final home = _cubit.state.home;
    if (home == null) return;
    final hit = await showPageSearchSheet(context, home: home);
    if (hit == null || !mounted) return;
    await Future<void>.delayed(AppMotion.homeSearchDelay);
    final scene = _scene;
    if (!mounted || scene == null) return;
    final island = scene.island;
    final head = _stage.head;
    if (hit is PageLessonHit &&
        island != null &&
        hit.unitIndex == scene.unitIndex &&
        hit.lessonIndex < island.n) {
      final stone = island.stones[hit.lessonIndex];
      await _stage.scrollTo(
        head + scene.islandTop + stone.dy - _pageAbove,
        AppMotion.homeGoScroll,
      );
      if (mounted) {
        unawaited(_choreo.pulseStone(hit.lessonIndex, hit: true));
      }
      return;
    }
    if (hit.unitIndex >= scene.map.islands.length) return;
    final slot = scene.map.islands[hit.unitIndex];
    await _stage.scrollTo(
      head + slot.rect.top - _unitAbove,
      AppMotion.homeGoScroll,
    );
    if (mounted) {
      unawaited(_choreo.pulseStone(hit.unitIndex, island: true));
    }
  }

  static const _pageAbove = 300.0;
  static const _unitAbove = 160.0;

  Future<void> _openTracks() async {
    final me = context.read<MeCubit?>();
    if (me == null) return;
    await me.openTracks();
    if (!mounted) return;
    final track = await showTracksSheet(
      context,
      onJoin: widget.actions.joinTrack,
    );
    final home = _cubit.state.home;
    if (track == null ||
        !mounted ||
        track.enrollmentId == home?.enrollment.id) {
      return;
    }
    Failure? failure;
    await _choreo.switchTrack(() async {
      failure = await _cubit.switchTrack(track);
    });
    final failed = failure;
    if (failed != null && mounted) showFailureSnackBar(context, failed);
  }

  Future<void> _openStreak() async {
    final home = _cubit.state.home;
    final streak = home?.streak;
    if (home == null || streak == null) return;
    await showStreakSheetOf(
      context,
      streak: streak,
      week: home.week,
      onWeekInMe: widget.actions.openMe,
    );
  }

  void _closeEvent(HomeNotices notices, HomeCardNotice slot) {
    final event = notices.event;
    if (event == null) return;
    final guide = _stageRect(_cardGuideKey);
    if (guide != null) {
      unawaited(
        _choreo.cardClosed(cardGuide: guide, dh: DayHeader.cardSlotOf(slot)),
      );
    }
    unawaited(_cubit.closeEvent(event.id));
  }

  void _levelCheck() {
    final home = _cubit.state.home;
    final id = home?.cards.levelCheckLessonId;
    if (home == null) return;
    for (final unit in home.units) {
      for (final lesson in unit.lessons) {
        if (lesson.id == id) {
          widget.actions.openLesson(lesson.base, kids: home.kids);
          return;
        }
      }
    }
    final unit = home.currentUnit;
    if (unit != null) widget.actions.openUnit(unit.id);
  }

  Future<void> _startLevel() async {
    final failure = await _cubit.startNextLevel();
    if (failure != null && mounted) showFailureSnackBar(context, failure);
  }

  void _retry() {
    _failedTimer?.cancel();
    _failedTimer = null;
    unawaited(_cubit.refresh(byUser: true));
  }

  void _guideTapped() {
    final home = _cubit.state.home;
    if (home == null) return;
    _guideTap.tap(
      guideSayText(today: home.todayMinutes, goal: home.goalMinutes),
    );
  }

  /// The freeze card's one glint of snow on the flame.
  void _glintFor(HomeNotices notices, HomeCardNotice slot) {
    final event = notices.event;
    if (slot != HomeCardNotice.freeze || event == null) return;
    if (_glinted == event.id) return;
    _glinted = event.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_choreo.freezeGlint());
    });
  }

  // The scene.

  HomeMapScene _sceneFor(
    BuildContext context,
    HomeState state,
    HomeSnapshot drawn,
    MapOverrides overrides,
    StageMetrics metrics,
  ) {
    final frame = MapFrame(metrics.width);
    final units = drawn.units;
    final unitIndex = overrides.unitIndex ?? drawn.currentUnitIndex;
    final unit = unitIndex >= 0 && unitIndex < units.length
        ? units[unitIndex]
        : null;
    final kids = drawn.kids;
    final reviewFirst = HomeRules.reviewFirst(drawn);
    final reviewBox = HomeRules.reviewBox(drawn);
    final mode = bubbleModeOf(state);
    IslandLayout? island;
    var current = 0;
    var done = const <int>{};
    HomeLesson? lesson;
    BubbleFrame? bubbleFrame;
    var bubbleHeight = 0.0;
    if (unit != null && unit.lessons.isNotEmpty) {
      final n = unit.lessons.length;
      current = overrides.cur ?? unit.currentLesson;
      done =
          overrides.done ??
          {
            for (final (k, lesson) in unit.lessons.indexed)
              if (lesson.done) k,
          };
      lesson = current < n ? unit.lessons[current] : null;
      IslandLayout layout(double extra) => IslandLayout.compute(
        lessons: n,
        current: current,
        kids: kids,
        frame: frame,
        rowFrom: overrides.rowFrom,
        rowT: overrides.rowT,
        reviewStation: reviewFirst,
        gapExtra: extra,
      );
      BubbleFrame frameOf(IslandLayout layout) {
        final target = math.min(n - 1, current);
        final tail = overrides.tail;
        if (tail == null) {
          return layout.bubbleFrame(
            reviewFirst: reviewFirst,
            targetX: layout.stones[target].dx,
            targetRow: layout.rowOf(target),
          );
        }
        final a = layout.stones[tail.a.clamp(0, n - 1)].dx;
        final b = layout.stones[tail.b.clamp(0, n - 1)].dx;
        return layout.bubbleFrame(
          reviewFirst: reviewFirst,
          targetX: lerpDouble(a, b, tail.t)!,
          targetRow: layout.rowOf(tail.b.clamp(0, n - 1)),
        );
      }

      island = layout(0);
      if (current < n || reviewFirst) {
        bubbleHeight = LessonBubble.measure(
          context,
          mode: mode,
          lesson: lesson,
          home: drawn,
          width: frameOf(island).width,
        );
        final reserved = kids
            ? LessonBubble.reserved.kids
            : mode == BubbleMode.resume
            ? LessonBubble.reserved.partial
            : LessonBubble.reserved.normal;
        final extra = bubbleHeight - reserved;
        if (extra > 0) island = layout(extra);
        bubbleFrame = frameOf(island);
      }
    }
    final anchor = island == null
        ? const MapAnchor(box: null, rel: 0)
        : MapAnchor.compute(
            island: island,
            current: current,
            kids: kids,
            reviewBox: reviewBox,
            reviewStation: reviewFirst,
            partial: mode == BubbleMode.resume,
            pt: metrics.pt,
            view: metrics.view,
            bubbleHeight: bubbleHeight,
            lastLandmark: lastStoneOf(unit!, kids: kids) != LastStone.none,
          );
    final map = MapLayout.compute(
      units: [for (final u in units) u.status],
      currentUnit: unitIndex < 0 ? units.length : unitIndex,
      ordered: drawn.enrollment.ordered,
      current: island,
      anchor: anchor,
      reviewBox: reviewBox,
      frame: frame,
    );
    return HomeMapScene(
      home: drawn,
      frame: frame,
      map: map,
      island: island,
      unitIndex: island == null ? -1 : unitIndex,
      current: current,
      done: done,
      reviewFirst: reviewFirst && island != null,
      reviewBox: reviewBox,
      bubbleMode: mode,
      bubbleLesson: lesson,
      bubbleFrame: bubbleFrame,
      bubbleHeight: bubbleHeight,
    );
  }

  GuidePlacement _guideFor(
    StageMetrics metrics,
    HomeMapScene scene,
    HomeCardNotice slot,
    bool levelCard,
  ) => resolveGuide(
    forced: _choreo.forcedGuide,
    flying: _flights.flying,
    collapsed: metrics.collapsed,
    hasCurrentIsland: scene.island != null,
    backButton: _backDir != null,
    pull: metrics.pull,
    levelCardShown: levelCard,
    card: slot,
    current: scene.reviewFirst ? -1 : scene.current,
  );

  @override
  Widget build(BuildContext context) {
    final verify = context.read<VerifyEmailCubit?>();
    Widget page({required bool emailReminder}) =>
        BlocConsumer<HomeCubit, HomeState>(
          listener: _onState,
          builder: (context, state) => LayoutBuilder(
            builder: (context, box) {
              final home = state.home;
              if (home == null) return _empty(state);
              return ListenableBuilder(
                listenable: _motion,
                builder: (context, _) => _stageOf(
                  context,
                  state,
                  home,
                  box.biggest,
                  emailReminder: emailReminder,
                  verify: verify,
                ),
              );
            },
          ),
        );
    return ColoredBox(
      color: context.colors.background,
      child: SafeArea(
        bottom: false,
        child: verify == null
            ? page(emailReminder: false)
            : BlocSelector<VerifyEmailCubit, VerifyEmailState, bool>(
                bloc: verify,
                selector: (state) => state.showsReminder,
                builder: (_, reminder) => page(emailReminder: reminder),
              ),
      ),
    );
  }

  /// Nothing to show yet: the skeleton, or no data and a retry; the top bar
  /// keeps only its capsule.
  Widget _empty(HomeState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: StageMetrics.topBar,
        child: TopBar(
          trackTitle: state.trackTitle,
          kids: state.kids,
          v01: false,
          emar: false,
          skeleton: true,
          streak: 0,
          atRisk: false,
          stars: null,
          dividerOn: false,
          overrides: HeaderOverrides.none,
          wobble: const AlwaysStoppedAnimation(0),
          onTracks: () => unawaited(_openTracks()),
          onStreak: () {},
          onPageSearch: () {},
          onLongPress: widget.actions.openDev,
        ),
      ),
      Expanded(
        child: switch ((state.load, state.failure)) {
          (LoadStatus.failure, final failure?) => HomeNoData(
            failure: failure,
            onRetry: () => unawaited(_cubit.refresh()),
          ),
          _ => const HomeSkeleton(),
        },
      ),
    ],
  );

  Widget _stageOf(
    BuildContext context,
    HomeState state,
    HomeSnapshot home,
    Size size, {
    required bool emailReminder,
    required VerifyEmailCubit? verify,
  }) {
    final notices = state.notices(emailReminder: emailReminder);
    final slot = DayHeader.slotCard(state, notices);
    _formula = DayHeader.formula(kids: home.kids, top: notices.top, card: slot);
    _stage
      ..width = size.width
      ..height = size.height
      ..kids = home.kids
      ..head = _formula + _extra
      ..topSlot = _topSlot ?? DayHeader.topSlotOf(notices.top);
    if (_stage.collapse > _stage.head) _stage.collapse = _stage.head;
    final metrics = _stage.metrics;
    final overrides = _choreo.map;
    final drawn = overrides.snapshot ?? home;
    final scene = _sceneFor(context, state, drawn, overrides, metrics);
    _scene = scene;
    _choreo
      ..island = scene.island
      ..mapLayout = scene.map;
    _scheduleAnchor(home);
    _glintFor(notices, slot);

    final levelCard = state.levelJustDone && drawn.level.completed;
    final guide = _guideFor(metrics, scene, slot, levelCard);
    final fraction = home.goalMinutes <= 0
        ? 0.0
        : math.min(1.0, home.todayMinutes / home.goalMinutes);
    final goalReached = home.goalMinutes > 0 && fraction >= 1;
    final ringFace =
        _choreo.guideExpression ??
        (home.kids || fraction <= 0
            ? MascotExpression.welcome
            : goalReached
            ? MascotExpression.happy
            : MascotExpression.encourage);
    final parkedFace =
        _choreo.guideExpression ??
        overrides.guideExpression ??
        (goalReached ? MascotExpression.happy : MascotExpression.encourage);

    final map = HomeMap(
      scene: scene,
      overrides: overrides,
      guide: guide,
      guideExpression: parkedFace,
      offline: state.offline,
      loops: _choreo.loops,
      scroll: _stage.scrollListenable,
      card: _card,
      toast: _toast,
      levelCard: levelCard,
      kidSaying: _choreo.kidSaying,
      bubbleKey: _bubbleKey,
      actions: HomeMapActions(
        onBubble: _onBubble,
        onStone: _onStone,
        onStation: () {
          _closeCard();
          widget.actions.openReview();
        },
        onBanner: () {
          final unit = scene.unit;
          if (unit != null) widget.actions.openUnit(unit.id);
        },
        onKidListen: _choreo.sayUnit,
        onReviewBox: widget.actions.openReview,
        onIsland: _onIsland,
        onStartLevel: () => unawaited(_startLevel()),
        onCloseCard: _closeCard,
        onReplay: _onCardLesson,
        onStart: _onCardLesson,
      ),
    );
    final streak = home.streak;
    return KeyedSubtree(
      key: _mainKey,
      child: HomeStage(
        stage: _stage,
        scrollController: _scroll,
        mapOpacity: overrides.mapOpacity,
        contentShift: _choreo.header.contentShift,
        scrollView: MapScrollView(
          controller: _scroll,
          stage: _stage,
          top: metrics.pt,
          canPull: !_choreo.busy,
          onPull: _choreo.pullMoved,
          onRelease: (pull) =>
              _choreo.pullReleased(pull, onPull: _stage.setPull),
          onScrolled: _closeCard,
          child: map,
        ),
        dayHeader: (context, m) => DayHeader(
          state: state,
          notices: notices,
          greetingOpacity: m.greetingOpacity,
          onHeight: _onHead,
          onTopSlot: _onTopSlot,
          topStrip: switch (notices.top) {
            HomeTopNotice.refreshFailed => ConnectionStrip.failed(
              onRetry: _retry,
            ),
            HomeTopNotice.offline => const ConnectionStrip.offline(),
            HomeTopNotice.email when verify != null =>
              const VerifyEmailBanner(),
            _ => null,
          },
          onCloseEvent: () => _closeEvent(notices, slot),
          onLevelCheck: _levelCheck,
          onPlacement: widget.actions.openPlacement,
          onStartLevel: () => unawaited(_startLevel()),
          onListen: () => unawaited(_cubit.sayGreeting()),
          minutesInRing: ringShowsMinutes(
            kids: home.kids,
            guide: _guideFor(m, scene, slot, levelCard),
            m: m,
          ),
          overrides: _choreo.header,
          cardGuide: _guideFor(m, scene, slot, levelCard) is GuideOnCard,
          cardGuideKey: _cardGuideKey,
        ),
        levelHeader: (context, m) =>
            LevelHeader(home: drawn, progress: m.progress),
        // Mounted only while it shows: one guide, from the ring's threshold.
        pullGuide: (context, m) => PullGuide.shows(m.pull)
            ? PullGuide(pull: m.pull, spinning: _choreo.pullSpinning)
            : const SizedBox.shrink(),
        topBar: (context, m) => TopBar(
          trackTitle: home.enrollment.title,
          kids: home.kids,
          v01: home.v01,
          emar: scene.emar,
          skeleton: false,
          streak: streak?.current ?? 0,
          atRisk: state.atRisk,
          stars: home.learner.stars,
          dividerOn: m.dividerOn,
          overrides: _choreo.header,
          wobble: _choreo.flameWobble,
          onTracks: () => unawaited(_openTracks()),
          onStreak: () => unawaited(_openStreak()),
          onPageSearch: () => unawaited(_openPageSearch()),
          onLongPress: widget.actions.openDev,
          freezes: streak?.freezes ?? 0,
          maxFreezes: streak?.maxFreezes ?? 0,
        ),
        ring: (context, m) {
          final placed = _guideFor(m, scene, slot, levelCard);
          return GoalRingOverlay(
            metrics: m,
            fraction: fraction,
            success: goalReached,
            minutes: home.todayMinutes,
            goal: home.goalMinutes,
            minutesInside: ringShowsMinutes(
              kids: home.kids,
              guide: placed,
              m: m,
            ),
            guide: placed,
            expression: ringFace,
            waving: _guideTap.waving || fraction <= 0,
            overrides: _choreo.header,
            kids: home.kids,
            v01: home.v01,
            onGuideTap: _guideTapped,
          );
        },
        say: (context, m) => SayBubble(text: _guideTap.say, metrics: m),
        switchStrip: SwitchStrip(title: _switchTitle),
        // Mounted from its first showing on, so it can hide itself.
        backButton: scene.island == null || !_backEver
            ? null
            : BackToLessonButton(
                direction: _backDir,
                kids: home.kids,
                lessonTitle: scene.bubbleLesson?.title ?? '',
                reviewFirst: scene.reviewFirst,
                arrivedByFlight: _arrived,
                onPressed: () => unawaited(_back()),
              ),
        flights: FlightLayer(controller: _flights),
        skip: SkipLayer(active: _choreo.skippable, onSkip: _choreo.skip),
      ),
    );
  }
}
