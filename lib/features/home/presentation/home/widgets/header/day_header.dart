import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/play_sound.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/streak_flame.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/goal_ring.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/kid_week.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/level_complete_card.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/notice_cards.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/read_order.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The day header (design "Home Archipelago"): the top slot
/// ([topStrip]: a connection strip or the email reminder), the greeting with
/// today's status and the ring's column, or the kids' header, then the
/// notice slot's card. It folds away with the map's scroll; the page
/// translates it.
///
/// Its height is measured: [onHeight] gets the whole header's and
/// [onTopSlot] the top slot's, after each layout that changes them. At text
/// scale 1 the minimum is the design's ([formula]); larger text grows it.
///
/// The ring itself floats over the column ([GoalRingOverlay]); the minutes
/// under it are here, hidden while [minutesInRing]. [overrides] carries a
/// motion's minutes. The freeze, broke and level cards carry the guide while
/// [cardGuide]; [cardGuideKey] marks its box for the flight back to the ring.
class DayHeader extends StatelessWidget {
  const DayHeader({
    required this.state,
    required this.notices,
    required this.greetingOpacity,
    required this.onHeight,
    required this.onTopSlot,
    required this.topStrip,
    required this.onCloseEvent,
    required this.onLevelCheck,
    required this.onPlacement,
    required this.onStartLevel,
    required this.onListen,
    this.minutesInRing = false,
    this.overrides = HeaderOverrides.none,
    this.cardGuide = true,
    this.cardGuideKey,
    super.key,
  });

  final HomeState state;
  final HomeNotices notices;
  final double greetingOpacity;
  final ValueChanged<double> onHeight;
  final ValueChanged<double> onTopSlot;

  /// A connection strip, or the email reminder. The header gives it the
  /// slot's margins (4 above, 8 below, 16 from the screen's sides); the email
  /// reminder brings its own space below.
  final Widget? topStrip;
  final VoidCallback onCloseEvent;
  final VoidCallback onLevelCheck;
  final VoidCallback onPlacement;
  final VoidCallback onStartLevel;
  final VoidCallback onListen;
  final bool minutesInRing;
  final HeaderOverrides overrides;
  final bool cardGuide;
  final Key? cardGuideKey;

  /// The greeting row's height in the design, general and kids.
  static const base = 114.0;
  static const kidsBase = 136.0;
  static const side = 20.0;

  /// The notice card's gap under the greeting.
  static const cardGap = 6.0;

  static const _stripSide = 16.0;
  static const _stripTop = 4.0;
  static const _stripBottom = 8.0;

  /// The top slot in the design: a strip and its margins.
  static double topSlotOf(HomeTopNotice top) => switch (top) {
    HomeTopNotice.none => 0,
    HomeTopNotice.email => 68,
    HomeTopNotice.offline || HomeTopNotice.refreshFailed => 52,
  };

  /// The notice slot in the design: the card, its gap and 6 to spare.
  static double cardSlotOf(HomeCardNotice card) => switch (card) {
    HomeCardNotice.none => 0,
    HomeCardNotice.freeze => 120,
    HomeCardNotice.broke => 104,
    HomeCardNotice.levelCheck || HomeCardNotice.placement => 92,
    HomeCardNotice.levelDone => 140,
  };

  /// The header's height before it is measured: `(kids 136 : 114) + nt + nb`.
  static double formula({
    required bool kids,
    required HomeTopNotice top,
    required HomeCardNotice card,
  }) => (kids ? kidsBase : base) + topSlotOf(top) + cardSlotOf(card);

  /// The card the notice slot shows: none for a level just completed in this
  /// session (its card stands at the horizon), nor for a notice whose
  /// data is missing.
  static HomeCardNotice slotCard(HomeState state, HomeNotices notices) {
    final home = state.home;
    if (home == null) return HomeCardNotice.none;
    return switch (notices.card) {
      HomeCardNotice.levelDone when state.levelJustDone => HomeCardNotice.none,
      HomeCardNotice.freeze when notices.event == null || home.streak == null =>
        HomeCardNotice.none,
      HomeCardNotice.broke when notices.event == null => HomeCardNotice.none,
      HomeCardNotice.placement when home.cards.placementMinutes == null =>
        HomeCardNotice.none,
      final card => card,
    };
  }

  @override
  Widget build(BuildContext context) {
    final home = state.home;
    final strip = topStrip;
    final slot = slotCard(state, notices);
    final email = notices.top == HomeTopNotice.email;
    return _Measured(
      onSize: onHeight,
      child: ColoredBox(
        color: context.colors.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Measured(
              onSize: onTopSlot,
              child: strip == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        _stripSide,
                        _stripTop,
                        _stripSide,
                        email ? 0 : _stripBottom,
                      ),
                      child: Semantics(
                        sortKey: HomeReadOrder.strip,
                        container: true,
                        explicitChildNodes: true,
                        child: strip,
                      ),
                    ),
            ),
            // The design's slack sits under the content, as its flex column
            // leaves it: the greeting row is 112 and the card follows it.
            if (home != null)
              Container(
                constraints: BoxConstraints(
                  minHeight: (home.kids ? kidsBase : base) + cardSlotOf(slot),
                ),
                alignment: AlignmentDirectional.topStart,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: side,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (home.kids)
                      _KidsHead(
                        home: home,
                        greetingOpacity: greetingOpacity,
                        onListen: onListen,
                      )
                    else
                      _Greeting(
                        state: state,
                        home: home,
                        greetingOpacity: greetingOpacity,
                        minutesInRing: minutesInRing,
                        overrides: overrides,
                      ),
                    if (slot != HomeCardNotice.none)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: cardGap),
                        child: Semantics(
                          sortKey: HomeReadOrder.card,
                          container: true,
                          explicitChildNodes: true,
                          child: _card(home, slot),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(HomeSnapshot home, HomeCardNotice slot) => switch (slot) {
    HomeCardNotice.freeze => SoundOnShow(
      sound: AppSound.freeze,
      child: NoticeCard.freeze(
        event: notices.event!,
        streak: home.streak!,
        perWeek: home.freezesPerWeek,
        showGuide: cardGuide,
        guideKey: cardGuideKey,
        onClose: onCloseEvent,
      ),
    ),
    HomeCardNotice.broke => NoticeCard.broke(
      event: notices.event!,
      showGuide: cardGuide,
      guideKey: cardGuideKey,
      onClose: onCloseEvent,
    ),
    HomeCardNotice.levelDone => LevelCompleteCard(
      home: home,
      showGuide: cardGuide,
      guideKey: cardGuideKey,
      onStart: onStartLevel,
    ),
    HomeCardNotice.levelCheck => NoticeCard.levelCheck(onStart: onLevelCheck),
    HomeCardNotice.placement => NoticeCard.placement(
      minutes: home.cards.placementMinutes!,
      onStart: onPlacement,
    ),
    HomeCardNotice.none => const SizedBox.shrink(),
  };
}

/// The general and Emar greeting, v0.1's too.
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.state,
    required this.home,
    required this.greetingOpacity,
    required this.minutesInRing,
    required this.overrides,
  });

  final HomeState state;
  final HomeSnapshot home;
  final double greetingOpacity;
  final bool minutesInRing;
  final HeaderOverrides overrides;

  /// The ring column: the 96 ring's place and the minutes' 16 line.
  static const _ringColumn = GoalRingOverlay.box;
  static const _minutesLine = 16.0;
  static const _gap = 16.0;
  static const _statusGap = 10.0;

  /// The most minutes the ring writes.
  static const _maxMinutes = 99;

  /// The label of the header's group: the greeting, today's
  /// minutes, the streak; on a v0.1 server the greeting alone.
  static String semanticsOf(HomeState state, HomeSnapshot home, int minutes) {
    final spoken = greetingText(
      state.greeting,
      home.learner.firstName,
      spoken: true,
    );
    final streak = home.streak;
    if (home.v01 || streak == null) return spoken;
    return 'home_head_semantics'.tr(
      namedArgs: {
        'greeting': spoken,
        'today': 'home_today_minutes'.plural(
          home.goalMinutes,
          namedArgs: {'min': '$minutes'},
        ),
        'streak': 'me_streak_count'.plural(streak.current),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final minutes = overrides.minutes ?? home.todayMinutes;
    final units = home.units.length;
    final current = home.currentUnitIndex;
    final risk = state.atRisk;
    final status = state.status;
    return Semantics(
      container: true,
      sortKey: HomeReadOrder.header,
      label: semanticsOf(state, home, minutes),
      explicitChildNodes: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Opacity(
              opacity: greetingOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetingText(state.greeting, home.learner.firstName),
                          style: texts.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'home_level_line'.tr(
                            namedArgs: {
                              'level': home.level.label,
                              'unit':
                                  '${current < 0 ? units : math.min(units, current + 1)}',
                              'units': '$units',
                            },
                          ),
                          style: texts.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: _statusGap),
                  Semantics(
                    container: true,
                    child: risk
                        ? _RiskLine(
                            text: riskText(
                              status.minutesLeft,
                              home.streak?.current ?? 0,
                            ),
                          )
                        : Text(
                            statusText(status),
                            style: texts.body.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: _gap),
          ExcludeSemantics(
            child: Opacity(
              opacity: greetingOpacity,
              child: home.v01
                  ? const SizedBox(
                      width: GoalRingOverlay.kidGuideSize,
                      height:
                          GoalRingOverlay.kidGuideSize +
                          GoalRingOverlay.v01GuideTop,
                    )
                  : SizedBox(
                      width: _ringColumn,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: _ringColumn),
                          AnimatedOpacity(
                            opacity: minutesInRing ? 0 : 1,
                            duration: AppMotion.quick,
                            curve: AppMotion.out,
                            child: Text(
                              'home_minutes_unit'.tr(
                                namedArgs: {
                                  'min': '${math.min(minutes, _maxMinutes)}',
                                  'goal': '${home.goalMinutes}',
                                },
                              ),
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.center,
                              style: texts.captionStrong.copyWith(
                                height: _minutesLine / 13,
                                color: colors.textSecondary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «5 دقائق تحافظ على أيامك السبعة», in the streak's colour, after its
/// flame.
class _RiskLine extends StatelessWidget {
  const _RiskLine({required this.text});

  final String text;

  static const _flame = 18.0;

  @override
  Widget build(BuildContext context) {
    final style = context.texts.body.copyWith(
      color: context.colors.streak.text,
    );
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 16) *
        (style.height ?? 1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            top: math.max(0, (line - _flame) / 2),
          ),
          child: const StreakFlame(size: _flame),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// The kids' header: «أهلًا ليان!» with the listen button and
/// the guide's 80 place, then the streak and the week.
class _KidsHead extends StatelessWidget {
  const _KidsHead({
    required this.home,
    required this.greetingOpacity,
    required this.onListen,
  });

  final HomeSnapshot home;
  final double greetingOpacity;
  final VoidCallback onListen;

  static const _listen = 56.0;
  static const _listenIcon = 26.0;
  static const _flame = 24.0;

  /// The 80 guide's place, the ring box's 8 inset with it.
  static const _guide = (width: 88.0, height: 80.0);

  static String semanticsOf(HomeSnapshot home) {
    final name = home.learner.firstName;
    final streak = home.streak;
    if (streak == null) return greetingText(HomeGreeting.kids, name);
    return 'home_kid_head_semantics'.tr(
      namedArgs: {
        'name': name,
        'days': 'me_streak_count'.plural(streak.current),
        'stars': 'unit_kid_stars'.plural(home.learner.stars ?? 0),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final streak = home.streak;
    final week = home.week;
    return Semantics(
      container: true,
      sortKey: HomeReadOrder.header,
      label: semanticsOf(home),
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            IgnorePointer(
              ignoring: greetingOpacity <= 0,
              child: Opacity(
                opacity: greetingOpacity,
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: ExcludeSemantics(
                              child: Text(
                                greetingText(
                                  HomeGreeting.kids,
                                  home.learner.firstName,
                                ),
                                style: texts
                                    .sized(
                                      texts.title,
                                      size: 26,
                                      line: 36,
                                      running: false,
                                    )
                                    .copyWith(color: colors.textPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          KidRoundButton(
                            icon: AppIconView(
                              AppIcon.volume,
                              size: _listenIcon,
                              color: colors.surface,
                            ),
                            label: 'home_listen'.tr(),
                            onPressed: onListen,
                            size: _listen,
                            iconSize: _listenIcon,
                            info: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: _guide.width, height: _guide.height),
                  ],
                ),
              ),
            ),
            if (streak != null && week != null)
              ExcludeSemantics(
                child: Opacity(
                  opacity: greetingOpacity,
                  child: Row(
                    children: [
                      const StreakFlame(size: _flame),
                      const SizedBox(width: 4),
                      Text(
                        daysText(streak.current),
                        maxLines: 1,
                        softWrap: false,
                        style: texts
                            .sized(
                              texts.bodyStrong,
                              size: 18,
                              line: 24,
                              running: false,
                            )
                            .copyWith(color: colors.streak.text),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: KidWeek(week: week)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Reports its child's height after each layout that changes it.
class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onSize, super.child});

  final ValueChanged<double> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onSize);

  ValueChanged<double> onSize;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(height);
    });
  }
}
