import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/streak_flame.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/header_styles.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/read_order.dart';
import 'package:flutter/material.dart';

/// The 56 top bar (design "Home Archipelago"): the track capsule
/// at the start; at the end, from the edge, the folded ring's spot, the
/// streak flame and Emar's page search; for kids, their stars instead.
/// With [skeleton] (no data yet, or none to show) only the capsule.
class TopBar extends StatelessWidget {
  const TopBar({
    required this.trackTitle,
    required this.kids,
    required this.v01,
    required this.emar,
    required this.skeleton,
    required this.streak,
    required this.atRisk,
    required this.stars,
    required this.dividerOn,
    required this.overrides,
    required this.wobble,
    required this.onTracks,
    required this.onStreak,
    required this.onPageSearch,
    this.onLongPress,
    this.freezes = 0,
    this.maxFreezes = 0,
    super.key,
  });

  final String? trackTitle;
  final bool kids;
  final bool v01;
  final bool emar;
  final bool skeleton;
  final int streak;
  final bool atRisk;
  final int? stars;
  final bool dividerOn;

  /// The goal's flame flip and streak roll (M5/M10), the freeze glint.
  final HeaderOverrides overrides;

  /// The at-risk flame's tilt (M10): −1 … 1 of [AppMotion.homeFlameTilt]
  /// degrees, 0 upright. The choreographer drives it through
  /// [AppMotion.homeFlame] while the budget allows; it only tilts while
  /// [atRisk].
  final Animation<double> wobble;
  final VoidCallback onTracks;
  final VoidCallback onStreak;
  final VoidCallback onPageSearch;

  /// Mock mode only: opens the dev page.
  final VoidCallback? onLongPress;

  /// The streak's freezes, for the flame's label «رصيد التجميد 2 من 3».
  final int freezes;
  final int maxFreezes;

  static const _edge = 20.0;

  /// The flame's drawing sits 52 from the end edge: the folded ring's 28
  /// spot and a gap of 4, of which the flame's own tap margin takes 2.
  static const _ringSpot = StageMetrics.ringMin + 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = trackTitle;
    final stars = this.stars;
    final flame = !kids && !v01 && !skeleton;
    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        boxShadow: [
          if (dividerOn)
            BoxShadow(
              color: context.scheme.outlineVariant,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: SizedBox(
        height: StageMetrics.topBar,
        child: Row(
          children: [
            const SizedBox(width: _edge),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: !kids && title != null
                    ? Semantics(
                        sortKey: HomeReadOrder.capsule,
                        child: _Capsule(title: title, onPressed: onTracks),
                      )
                    : null,
              ),
            ),
            if (flame && emar)
              Semantics(
                sortKey: HomeReadOrder.search,
                child: _PageSearch(onPressed: onPageSearch),
              ),
            if (flame) ...[
              Semantics(
                sortKey: HomeReadOrder.flame,
                child: _Flame(
                  streak: streak,
                  freezes: freezes,
                  maxFreezes: maxFreezes,
                  atRisk: atRisk,
                  wobble: wobble,
                  overrides: overrides,
                  onPressed: onStreak,
                ),
              ),
              const SizedBox(width: _ringSpot),
            ],
            if (kids && !skeleton && stars != null)
              Semantics(
                sortKey: HomeReadOrder.flame,
                child: _Stars(count: stars),
              ),
            const SizedBox(width: _edge),
          ],
        ),
      ),
    );
    final longPress = onLongPress;
    if (longPress != null) {
      // A node of its own would hold the bar's buttons out of the stage's
      // reading order (HomeReadOrder); the dev page needs none.
      bar = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onLongPress: longPress,
        child: bar,
      );
    }
    return bar;
  }
}

/// «الإنجليزية العامة ⌄»: opens the tracks sheet.
class _Capsule extends StatelessWidget {
  const _Capsule({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  static const _height = 36.0;
  static const _chevron = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return HeaderTap(
      label: 'home_capsule_semantics'.tr(args: [title]),
      onTap: onPressed,
      margin: const EdgeInsetsDirectional.symmetric(vertical: 6),
      pressScale: AppMotion.scaleMedium,
      builder: (context, _) => Container(
        height: _height,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(_height / 2),
          border: Border.all(color: context.scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: context.texts.captionStrong.copyWith(
                  height: 1,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AppIconView(
              AppIcon.chevronDown,
              size: _chevron,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The streak's days beside its flame: opens the streak sheet.
class _Flame extends StatelessWidget {
  const _Flame({
    required this.streak,
    required this.freezes,
    required this.maxFreezes,
    required this.atRisk,
    required this.wobble,
    required this.overrides,
    required this.onPressed,
  });

  final int streak;
  final int freezes;
  final int maxFreezes;
  final bool atRisk;
  final Animation<double> wobble;
  final HeaderOverrides overrides;
  final VoidCallback onPressed;

  static const _height = 44.0;
  static const _icon = 22.0;
  static const _number = 22.0;

  /// The flame turns about 50% across, 80% down (the design's origin).
  static const _pivot = Alignment(0, .6);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    final style = context.texts.bodyStrong.copyWith(
      fontSize: 16,
      height: _number / 16,
      color: colors.streak.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget icon = const StreakFlame(size: _icon);
    final glint = overrides.freezeGlint;
    if (glint != null && glint > 0 && glint < 1) {
      icon = _Glint(t: glint, child: icon);
    }
    final flip = overrides.flameFlip;
    if (flip > 0 && flip < 1) {
      icon = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(
          2 * math.pi * AppMotion.homeFlip.transform(flip),
        ),
        child: icon,
      );
    }
    final tilted = AnimatedBuilder(
      animation: wobble,
      child: icon,
      builder: (context, child) => Transform.rotate(
        angle: atRisk
            ? wobble.value.clamp(-1.0, 1.0) *
                  AppMotion.homeFlameTilt *
                  math.pi /
                  180
            : 0,
        alignment: _pivot,
        child: child,
      ),
    );
    return HeaderTap(
      label: 'home_flame_semantics'.tr(
        namedArgs: {
          'days': 'me_streak_count'.plural(streak),
          'have': '$freezes',
          'max': '$maxFreezes',
        },
      ),
      onTap: onPressed,
      margin: const EdgeInsets.all(2),
      builder: (context, pressed) => Container(
        height: _height,
        constraints: const BoxConstraints(minWidth: _height),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: pressed ? scheme.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            tilted,
            const SizedBox(width: 4),
            ClipRect(
              child: SizedBox(
                height: _number,
                child: _StreakNumber(
                  streak: streak,
                  overrides: overrides,
                  style: style,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The streak's number; during the goal's roll the new one comes up from
/// below (M5/M10).
class _StreakNumber extends StatelessWidget {
  const _StreakNumber({
    required this.streak,
    required this.overrides,
    required this.style,
  });

  final int streak;
  final HeaderOverrides overrides;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final rolling = overrides.streak;
    final roll = overrides.streakRoll;
    if (rolling == null) return Text('$streak', style: style);
    if (roll == null) return Text('${rolling.from}', style: style);
    final k = AppMotion.homeRoll.transform(roll.clamp(0.0, 1.0));
    return Opacity(
      opacity: k.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - k) * _Flame._number),
        child: Text('${rolling.to}', style: style),
      ),
    );
  }
}

/// ASSUMPTION(design): the snow glint after a freeze (M10) has no frames in
/// the design: one info-tinted sheen crosses the flame, [t] of the way.
class _Glint extends StatelessWidget {
  const _Glint({required this.t, required this.child});

  final double t;
  final Widget child;

  static const _band = .25;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = Color.lerp(colors.surface, colors.info.fill, .35)!;
    final centre = -_band + (1 + 2 * _band) * t;
    double at(double x) => x.clamp(0.0, 1.0);
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: const Alignment(-1, -.5),
        end: const Alignment(1, .5),
        colors: [
          tint.withValues(alpha: 0),
          tint.withValues(alpha: .9),
          tint.withValues(alpha: 0),
        ],
        stops: [at(centre - _band), at(centre), at(centre + _band)],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Emar: «ابحث برقم الصفحة».
class _PageSearch extends StatelessWidget {
  const _PageSearch({required this.onPressed});

  final VoidCallback onPressed;

  static const _size = 44.0;
  static const _icon = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    return HeaderTap(
      label: 'home_page_search'.tr(),
      onTap: onPressed,
      margin: const EdgeInsets.all(2),
      builder: (context, pressed) => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pressed ? scheme.surfaceContainerHigh : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: AppIconView(
          AppIcon.pageSearch,
          size: _icon,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

/// Kids: the stars earned, a picture to a screen reader («14 نجمة»).
class _Stars extends StatelessWidget {
  const _Stars({required this.count});

  final int count;

  static const _height = 44.0;
  static const _star = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      image: true,
      label: 'unit_kid_stars'.plural(count),
      excludeSemantics: true,
      child: Container(
        height: _height,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.reward.surface,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KidStar(size: _star),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: context.texts
                  .sized(
                    context.texts.bodyStrong,
                    size: 18,
                    line: 18,
                    running: false,
                  )
                  .copyWith(
                    color: colors.reward.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
