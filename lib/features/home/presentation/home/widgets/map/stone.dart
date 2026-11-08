import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/color_mix.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/shake.dart';
import 'package:englizia/core/design_system/widgets/ai_spark.dart';
import 'package:englizia/core/design_system/widgets/goal_ring.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A stone's state on the trail.
enum StoneState { done, current, open, locked }

enum _Variant { lesson, last, kid, station }

/// A lesson's stone on the island: a circle, the last one, a kid's picture,
/// or the review station. Its box is its own size ([diameterOf],
/// [lastBox], [stationSize]) and it is placed by its centre: a stone that
/// grows (48 → 64 as it becomes current) grows about it. Badges reach
/// past the box; the box is the target.
///
/// A tap on a stone that doesn't open its lesson shakes it and ticks the
/// phone (M3); what the tap does is [onPressed]'s.
class Stone extends StatelessWidget {
  const Stone.lesson({
    required HomeLesson this.lesson,
    required this.index,
    required StoneState this.state,
    required this.emar,
    required this.offline,
    required this.pulse,
    required this.hit,
    required this.pop,
    required this.onPressed,
    super.key,
  }) : review = null,
       _variant = _Variant.lesson;

  /// The unit's last lesson, drawn as the lighthouse or the gate by the
  /// island's art: an empty target over it with its badge.
  const Stone.last({
    required HomeLesson this.lesson,
    required StoneState this.state,
    required this.emar,
    required this.onPressed,
    super.key,
  }) : index = -1,
       offline = false,
       pulse = null,
       hit = false,
       pop = 1,
       review = null,
       _variant = _Variant.last;

  const Stone.kid({
    required HomeLesson this.lesson,
    required StoneState this.state,
    required this.onPressed,
    super.key,
  }) : index = -1,
       emar = false,
       offline = false,
       pulse = null,
       hit = false,
       pop = 1,
       review = null,
       _variant = _Variant.kid;

  /// The review as the trail's first stop (back after a while, state 06).
  const Stone.station({
    required HomeReview this.review,
    required this.pulse,
    required this.onPressed,
    super.key,
  }) : lesson = null,
       index = -1,
       state = null,
       emar = false,
       offline = false,
       hit = false,
       pop = 1,
       _variant = _Variant.station;

  final HomeLesson? lesson;

  /// Its place in the unit, from 0.
  final int index;
  final StoneState? state;

  /// Every lesson is open and the current one is suggested; its page shows.
  final bool emar;

  /// No connection: a lesson not kept on the phone is dimmed with a cloud.
  final bool offline;

  /// The bubble's target breathes on this clock, 0 to 1 (M2, the loop
  /// budget's pulse); null keeps it still.
  final Animation<double>? pulse;

  /// Emar's page search found it: two rings.
  final bool hit;

  /// The M5 pop's progress, 0 → 1 (1 when it isn't popping): the stone goes
  /// .7 → 1.12 at .6 → 1, eased out.
  final double pop;
  final HomeReview? review;
  final VoidCallback onPressed;
  final _Variant _variant;

  /// The circle's diameter: 48, the current 64 (kids 64 and 80).
  static double diameterOf(StoneState state, {bool kids = false}) {
    final current = state == StoneState.current;
    if (kids) return current ? 80 : 64;
    return current ? 64 : 48;
  }

  /// The last lesson's target, standing on its point.
  static const lastBox = 52.0;

  static const stationSize = 54.0;

  @override
  Widget build(BuildContext context) => switch (_variant) {
    _Variant.lesson => _LessonStone(this),
    _Variant.last => _LastStone(this),
    _Variant.kid => _KidStone(this),
    _Variant.station => _StationStone(this),
  };
}

/// The chip under a stone: its kind, Emar's page, a kid's word.
/// It sits 120 wide, centred under the stone; it is drawing only.
class StoneLabel extends StatelessWidget {
  const StoneLabel({
    required HomeLesson this.lesson,
    required this.current,
    required this.hit,
    required this.emar,
    required this.last,
    required this.locked,
    required this.kids,
    this.within,
    this.reach,
    super.key,
  }) : station = false;

  /// «راجع» under the review station.
  const StoneLabel.station({super.key})
    : lesson = null,
      current = true,
      hit = false,
      emar = false,
      last = false,
      locked = false,
      kids = false,
      within = null,
      reach = null,
      station = true;

  final HomeLesson? lesson;
  final bool current;
  final bool hit;
  final bool emar;
  final bool last;
  final bool locked;
  final bool kids;
  final bool station;

  /// Where the chips may reach, in x from the label's left edge: a stone
  /// near the frame's edge keeps its chip on screen, shifted no further
  /// than it must.
  final ({double min, double max})? within;

  /// The widest its chip may grow: the room to the nearest stone on its
  /// row, so two chips never meet at large text. Null: nothing beside it.
  final double? reach;

  /// A chip squeezed by its neighbours still shows a few letters.
  static const _leastReach = 48.0;

  static const width = 120.0;
  static const _subWidth = 96.0;

  /// From the stone's centre: a circle's `d/2 + 6`, the last one's 26, the
  /// station's 34.
  static double topFrom({required double diameter}) => diameter / 2 + 6;
  static const lastTop = 26.0;
  static const stationTop = 34.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final strong = current || hit;
    final lesson = this.lesson;
    final String text;
    final TextStyle style;
    if (lesson == null) {
      text = 'home_review_action'.tr();
      style = texts.captionStrong;
    } else if (kids) {
      text = lesson.title;
      style = strong ? texts.kidsWord : texts.kidsCard;
    } else {
      final short = kindShort(lesson);
      final page = lesson.page;
      text = emar && !last && page != null
          ? 'home_chip_page'.tr(args: [short], namedArgs: {'page': '$page'})
          : short;
      style = strong ? texts.captionStrong : texts.caption;
    }
    final chipStyle = kids
        ? texts
              .sized(style, size: 15, line: 20, running: false)
              .copyWith(
                color: strong ? colors.primary.text : colors.textPrimary,
              )
        : texts
              .sized(style, size: 11, line: 15, running: false)
              .copyWith(
                color: strong ? colors.primary.text : colors.textSecondary,
              );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Chip(
                text: text,
                style: chipStyle,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                radius: 8,
                english: kids,
                maxWidth: switch (reach) {
                  final reach? => math.min(
                    _Chip._oneLine,
                    math.max(_leastReach, reach),
                  ),
                  null => _Chip._oneLine,
                },
                within: within,
              ),
              if (last && locked && !kids) ...[
                const SizedBox(height: 2),
                // ASSUMPTION(design): it wraps, centred, as one line would
                // run off the frame beside a lighthouse at the edge.
                _Chip(
                  text: 'unit_review_after'.tr(),
                  style: texts
                      .sized(texts.caption, size: 10, line: 14)
                      .copyWith(color: colors.textSecondary),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  radius: 7,
                  english: false,
                  maxWidth: _subWidth,
                  lines: 3,
                  within: within,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One line on a surface chip; it may reach past the label's 120 a little,
/// centred, as the design's unwrapped chips do.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.style,
    required this.padding,
    required this.radius,
    required this.english,
    this.maxWidth = _oneLine,
    this.lines = 1,
    this.within,
  });

  final String text;
  final TextStyle style;
  final EdgeInsets padding;
  final double radius;
  final bool english;
  final double maxWidth;
  final int lines;
  final ({double min, double max})? within;

  static const _oneLine = 168.0;

  @override
  Widget build(BuildContext context) => _CentredWithin(
    maxWidth: maxWidth,
    within: within,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: Text(
          text,
          style: style,
          maxLines: lines,
          softWrap: lines > 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textDirection: english ? TextDirection.ltr : null,
        ),
      ),
    ),
  );
}

/// Centres its child across the label, which it may overflow up to
/// [maxWidth], then shifts it inside [within].
class _CentredWithin extends SingleChildRenderObjectWidget {
  const _CentredWithin({
    required this.maxWidth,
    required this.within,
    super.child,
  });

  final double maxWidth;
  final ({double min, double max})? within;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCentredWithin(maxWidth, within);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCentredWithin renderObject,
  ) => renderObject
    ..maxWidth = maxWidth
    ..within = within;
}

class _RenderCentredWithin extends RenderShiftedBox {
  _RenderCentredWithin(this._maxWidth, this._within) : super(null);

  double _maxWidth;
  set maxWidth(double value) {
    if (value == _maxWidth) return;
    _maxWidth = value;
    markNeedsLayout();
  }

  ({double min, double max})? _within;
  set within(({double min, double max})? value) {
    if (value == _within) return;
    _within = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: _maxWidth,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      ),
      parentUsesSize: true,
    );
    // As wide as the label, so [within] reads from the label's left edge.
    size = constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : child.size.width,
        child.size.height,
      ),
    );
    var dx = (size.width - child.size.width) / 2;
    final within = _within;
    if (within != null && child.size.width <= within.max - within.min) {
      dx = dx.clamp(within.min, within.max - child.size.width);
    }
    (child.parentData! as BoxParentData).offset = Offset(
      dx,
      (size.height - child.size.height) / 2,
    );
  }
}

/// The flat bottom edge of a filled stone: its colour darkened, no blur
/// (`lip(c)`).
Color stoneLip(BuildContext context, Color fill) =>
    mixOklch(fill, context.scheme.shadow, .72);

/// A stone's tap: it shrinks while pressed, and [shakes] (with a tick) when
/// the tap doesn't open its lesson.
class _Tap extends StatefulWidget {
  const _Tap({
    required this.label,
    required this.shakes,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final bool shakes;
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  var _shakes = 0;

  void _tap() {
    if (widget.shakes) {
      setState(() => _shakes++);
      AppHaptics.lightImpact();
    }
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: ExcludeSemantics(
        child: PressScale(
          scale: AppMotion.homeStonePress,
          child: Shake(
            trigger: _shakes,
            offsets: AppMotion.homeStoneShakeOffsets,
            duration: AppMotion.homeStoneShake,
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

/// The M5 pop: .7 → 1.12 at .6 → 1, eased out over the whole (keyframes are
/// linear in the eased time).
double _popScale(double t) {
  if (t >= 1) return 1;
  final e = AppMotion.out.transform(t.clamp(0.0, 1.0));
  const peakAt = .6;
  if (e <= peakAt) {
    return lerpDouble(
      AppMotion.homeStonePopFrom,
      AppMotion.homeStonePopPeak,
      e / peakAt,
    )!;
  }
  return lerpDouble(
    AppMotion.homeStonePopPeak,
    1,
    (e - peakAt) / (1 - peakAt),
  )!;
}

/// The breathing of the bubble's target (M2): 1 ↔ 1.06 on [pulse]. Always
/// the same widget, so starting or stopping it keeps the tap's state.
Widget _breathing({required Animation<double>? pulse, required Widget child}) =>
    ScaleTransition(
      scale: (pulse ?? kAlwaysDismissedAnimation).drive(
        Tween(begin: 1, end: AppMotion.homePulseScale),
      ),
      child: child,
    );

/// A circle that grows or shrinks about its centre to [diameter] with its
/// colours, inside a box of the final size.
class _Disk extends StatelessWidget {
  const _Disk({
    required this.diameter,
    required this.decoration,
    required this.children,
  });

  final double diameter;
  final BoxDecoration decoration;

  /// Laid over the circle, in a stack of its size.
  final List<Widget> children;

  static const _room = 96.0;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.resolve(context, AppMotion.homeStoneColor);
    return SizedBox.square(
      dimension: diameter,
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        maxWidth: _room,
        maxHeight: _room,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: diameter),
          duration: duration,
          curve: AppMotion.out,
          builder: (context, size, _) => SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: AppMotion.out,
                    decoration: decoration,
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round badge on a stone's edge.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.size,
    required this.fill,
    required this.child,
    this.bordered = false,
  });

  final double size;
  final Color fill;
  final Widget child;

  /// A 1.5 border (lock, offline); otherwise a 2 ring of the surface.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: bordered
            ? Border.all(color: context.scheme.outline, width: 1.5)
            : null,
        boxShadow: bordered
            ? null
            : [BoxShadow(color: colors.surface, spreadRadius: 2)],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _LessonStone extends StatelessWidget {
  const _LessonStone(this.stone);

  final Stone stone;

  /// The ring round a lesson left half done: stroke 6, its middle 6 out
  /// from the disk.
  static const _partialOut = 9.0;
  static const _partialStroke = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    final lesson = stone.lesson!;
    final state = stone.state!;
    final done = state == StoneState.done;
    final current = state == StoneState.current;
    final resume = lesson.resume;
    final partial = current && resume != null;
    final d = Stone.diameterOf(state);
    final fill = done
        ? colors.success.fill
        : current
        ? colors.primaryStrong
        : colors.surface;
    final shadows = <BoxShadow>[
      if (current && !partial)
        BoxShadow(color: colors.primary.surface, spreadRadius: 7),
      if (done || current)
        BoxShadow(color: stoneLip(context, fill), offset: const Offset(0, 4))
      else
        BoxShadow(
          color: scheme.outline.withValues(alpha: .5),
          offset: const Offset(0, 3),
        ),
      if (stone.hit) ...[
        BoxShadow(color: colors.primary.fill, spreadRadius: 9),
        BoxShadow(color: colors.primary.surface, spreadRadius: 6),
      ],
    ];
    final icon = done
        ? AppIconView(AppIcon.check, color: colors.surface, size: 22, stroke: 3)
        : kindIcon(
            lesson,
            color: current ? colors.onPrimaryStrong : colors.textSecondary,
            size: current ? 28 : 22,
          );
    final dimmed = stone.offline && !lesson.kept && !current;
    final questions = lesson.questions;
    final share = resume == null
        ? 0.0
        : questions != null && questions > 0
        ? resume.question / questions
        : resume.share;
    final disk = _Disk(
      diameter: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: done || current
            ? null
            : Border.all(color: scheme.outline, width: 2),
        boxShadow: shadows,
      ),
      children: [
        if (partial)
          Positioned.fill(
            left: -_partialOut,
            top: -_partialOut,
            right: -_partialOut,
            bottom: -_partialOut,
            child: GoalRing(
              share: share,
              color: colors.primary.fill,
              track: colors.primary.surface,
              stroke: _partialStroke,
              size: d + 2 * _partialOut,
            ),
          ),
        Center(child: icon),
        if (lesson.ai)
          PositionedDirectional(
            top: -4,
            end: -4,
            child: _Badge(
              size: 22,
              fill: colors.ai.surface,
              child: AiSpark(size: 12, color: colors.ai.fill),
            ),
          ),
        if (dimmed)
          PositionedDirectional(
            bottom: -4,
            start: -4,
            child: _Badge(
              size: 20,
              fill: colors.surface,
              bordered: true,
              child: AppIconView(
                AppIcon.cloudOff,
                color: colors.textSecondary,
                size: 12,
                stroke: 2.4,
              ),
            ),
          ),
        if (state == StoneState.locked)
          PositionedDirectional(
            bottom: -4,
            end: -4,
            child: _Badge(
              size: 20,
              fill: colors.surface,
              bordered: true,
              child: AppIconView(
                AppIcon.lock,
                color: colors.textSecondary,
                size: 11,
                stroke: 2.6,
              ),
            ),
          ),
      ],
    );
    return Transform.scale(
      scale: _popScale(stone.pop),
      child: Opacity(
        opacity: dimmed ? .45 : 1,
        child: _breathing(
          pulse: stone.pulse,
          child: _Tap(
            label: _lessonLabel(
              lesson,
              stone.index,
              state,
              emar: stone.emar,
              offline: dimmed,
            ),
            shakes: !current,
            onPressed: stone.onPressed,
            child: disk,
          ),
        ),
      ),
    );
  }
}

String _lessonLabel(
  HomeLesson lesson,
  int index,
  StoneState state, {
  required bool emar,
  required bool offline,
}) {
  // Like the unit screen: a lesson it can't open now says why, not its state.
  final status = offline
      ? 'unit_status_offline'.tr()
      : switch (state) {
          StoneState.done => 'unit_status_done'.tr(),
          StoneState.current =>
            emar ? 'home_bubble_suggested'.tr() : 'unit_status_current'.tr(),
          StoneState.open => 'unit_status_open'.tr(),
          StoneState.locked => 'unit_status_locked'.tr(),
        };
  final page = lesson.page;
  if (emar && page != null) {
    return 'home_stone_semantics_page'.tr(
      namedArgs: {
        'number': '${index + 1}',
        'title': lesson.title,
        'meta': lessonMeta(lesson),
        'page': '$page',
        'status': status,
      },
    );
  }
  return 'unit_lesson_semantics'.tr(
    namedArgs: {
      'number': '${index + 1}',
      'title': lesson.title,
      'meta': lessonMeta(lesson),
      'status': status,
    },
  );
}

class _LastStone extends StatelessWidget {
  const _LastStone(this.stone);

  final Stone stone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lesson = stone.lesson!;
    final state = stone.state!;
    final page = lesson.page;
    final status = switch (state) {
      StoneState.done => 'home_last_done'.tr(),
      StoneState.current => 'home_last_current'.tr(),
      StoneState.open =>
        page == null
            ? 'unit_status_open'.tr()
            : 'home_last_open'.tr(args: ['$page']),
      StoneState.locked => 'home_last_locked'.tr(),
    };
    final badge = switch (state) {
      StoneState.done => _Badge(
        size: 22,
        fill: colors.success.fill,
        child: AppIconView(
          AppIcon.check,
          color: colors.surface,
          size: 12,
          stroke: 3,
        ),
      ),
      StoneState.locked => _Badge(
        size: 22,
        fill: colors.surface,
        bordered: true,
        child: AppIconView(
          AppIcon.lock,
          color: colors.textSecondary,
          size: 12,
          stroke: 2.6,
        ),
      ),
      StoneState.current || StoneState.open => null,
    };
    return _Tap(
      label: 'home_last_semantics'.tr(
        namedArgs: {
          'title': lesson.title,
          'meta': lessonMeta(lesson),
          'status': status,
        },
      ),
      shakes: state != StoneState.current,
      onPressed: stone.onPressed,
      child: SizedBox.square(
        dimension: Stone.lastBox,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (badge != null)
              PositionedDirectional(bottom: 2, end: -2, child: badge),
          ],
        ),
      ),
    );
  }
}

class _KidStone extends StatelessWidget {
  const _KidStone(this.stone);

  final Stone stone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    final lesson = stone.lesson!;
    final state = stone.state!;
    final done = state == StoneState.done;
    final current = state == StoneState.current;
    final locked = state == StoneState.locked;
    final d = Stone.diameterOf(state, kids: true);
    final status = switch (state) {
      StoneState.done => 'unit_status_done'.tr(),
      StoneState.current => 'unit_status_current'.tr(),
      StoneState.open => 'unit_status_open'.tr(),
      StoneState.locked => 'unit_status_locked'.tr(),
    };
    final disk = _Disk(
      diameter: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary.surface,
        border: Border.all(
          color: done
              ? colors.success.fill
              : current
              ? colors.primaryStrong
              : scheme.outline,
          width: done
              ? 3
              : current
              ? 4
              : 2,
        ),
        boxShadow: [
          if (current)
            BoxShadow(color: colors.primary.surface, spreadRadius: 7),
        ],
      ),
      children: [
        Center(
          child: ClipOval(
            child: KidPicture(url: lesson.base.imageUrl ?? '', size: d - 10),
          ),
        ),
        if (done)
          PositionedDirectional(
            top: -4,
            end: -4,
            child: _Badge(
              size: 26,
              fill: colors.reward.surface,
              child: const KidStar(size: 16),
            ),
          ),
        if (locked)
          PositionedDirectional(
            top: -4,
            end: -4,
            child: _Badge(
              size: 26,
              fill: colors.surface,
              bordered: true,
              child: AppIconView(
                AppIcon.lock,
                color: colors.textSecondary,
                size: 14,
                stroke: 2.4,
              ),
            ),
          ),
      ],
    );
    return Opacity(
      opacity: locked ? .55 : 1,
      child: _Tap(
        label: 'unit_kid_semantics'.tr(
          namedArgs: {'name': lesson.title, 'status': status},
        ),
        shakes: locked,
        onPressed: stone.onPressed,
        child: disk,
      ),
    );
  }
}

class _StationStone extends StatelessWidget {
  const _StationStone(this.stone);

  final Stone stone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _breathing(
      pulse: stone.pulse,
      child: _Tap(
        label: 'home_station_semantics'.tr(args: [reviewLine(stone.review!)]),
        shakes: false,
        onPressed: stone.onPressed,
        child: _Disk(
          diameter: Stone.stationSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.info.surface,
            border: Border.all(color: colors.info.fill, width: 2),
            boxShadow: [
              BoxShadow(color: colors.primary.surface, spreadRadius: 6),
            ],
          ),
          children: [
            Center(
              child: AppIconView(
                AppIcon.reviewCycle,
                color: colors.info.fill,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
