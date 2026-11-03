import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/picture_back_button.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The unit's cover: it moves slower than the page as it scrolls away, with
/// the way back on it. [extra] rides its other corner (the kids' guide).
class UnitCover extends StatelessWidget {
  const UnitCover({
    required this.url,
    required this.scroll,
    required this.onBack,
    this.extra,
    super.key,
  });

  final String? url;
  final ScrollController scroll;
  final VoidCallback onBack;
  final Widget? extra;

  static const height = 200.0;

  /// How much taller the picture is than its frame, above and below, so it
  /// has room to move.
  static const _bleed = 24.0;
  static const _drift = .45;

  @override
  Widget build(BuildContext context) {
    final still = AppMotion.reduceMotion(context);
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: context.colors.primary.surface,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              top: -_bleed,
              bottom: -_bleed,
              child: AnimatedBuilder(
                animation: scroll,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    0,
                    still || !scroll.hasClients
                        ? 0
                        : (scroll.offset * _drift).clamp(0, _bleed * 4),
                  ),
                  child: child,
                ),
                child: ExcludeSemantics(child: _picture()),
              ),
            ),
            PositionedDirectional(
              top: AppSpacing.md,
              start: AppSpacing.lg,
              child: PictureBackButton(onPressed: onBack),
            ),
            if (extra case final extra?)
              PositionedDirectional(
                top: AppSpacing.sm,
                end: AppSpacing.md - 2,
                child: extra,
              ),
          ],
        ),
      ),
    );
  }

  Widget _picture() {
    final url = this.url;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return SvgPicture.asset(url, fit: BoxFit.cover);
  }
}

/// The bar that takes over from the cover once it has scrolled away.
class UnitTopBar extends StatelessWidget {
  const UnitTopBar({
    required this.title,
    required this.scroll,
    required this.onBack,
    super.key,
  });

  final String title;
  final ScrollController scroll;
  final VoidCallback onBack;

  static const height = 56.0;
  static const _from = 130.0;
  static const _over = 40.0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scroll,
    builder: (context, child) {
      final offset = scroll.hasClients ? scroll.offset : 0.0;
      final shown = ((offset - _from) / _over).clamp(0.0, 1.0);
      return IgnorePointer(
        ignoring: shown < 1,
        child: ExcludeSemantics(
          excluding: shown < 1,
          child: Opacity(opacity: shown, child: child),
        ),
      );
    },
    child: Container(
      height: height,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.xs,
        end: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(
          bottom: BorderSide(color: context.scheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'common_back'.tr(),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyStrong,
            ),
          ),
        ],
      ),
    ),
  );
}

/// What the unit is: its number and level, its title, its pages in the book,
/// how far it has come, and (outside kids mode) its goals and grammar.
class UnitSummary extends StatelessWidget {
  const UnitSummary({
    required this.plan,
    required this.goalsOpen,
    required this.onGoals,
    super.key,
  });

  final UnitPlan plan;
  final bool goalsOpen;
  final VoidCallback onGoals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final pages = plan.bookPages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'unit_number'.tr(args: ['${plan.number}']),
              style: texts.caption.copyWith(color: colors.textSecondary),
            ),
            if (plan.levelLabel.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              _LevelChip(label: plan.levelLabel),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Semantics(header: true, child: Text(plan.title, style: texts.display)),
        if (pages != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _BookPages(from: pages.from, to: pages.to),
          ),
        ],
        const SizedBox(height: AppSpacing.md + 2),
        UnitProgressBar(
          done: plan.doneCount,
          total: plan.lessons.length,
          complete: plan.complete,
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ExcludeSemantics(
          child: Text(
            'unit_progress'.plural(
              plan.lessons.length,
              namedArgs: {'done': '${plan.doneCount}'},
            ),
            style: texts.caption.copyWith(color: colors.textSecondary),
          ),
        ),
        if (!plan.kids && plan.goals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Goals(goals: plan.goals, open: goalsOpen, onToggle: onGoals),
        ],
        if (!plan.kids && plan.concepts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'unit_concepts'.tr(),
            style: texts.captionStrong.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final name in plan.concepts) _ConceptChip(name)],
          ),
        ],
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label});

  final String label;

  static const _height = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: _height,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: Text(
        label,
        style: context.texts.captionStrong.copyWith(
          color: colors.textSecondary,
          fontSize: 12,
          height: 1,
        ),
      ),
    );
  }
}

class _BookPages extends StatelessWidget {
  const _BookPages({required this.from, required this.to});

  final int from;
  final int to;

  static const _height = 30.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _height),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sm + 2,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconView(
            AppIcon.book,
            size: AppSizes.iconSm,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Flexible(
            child: Text(
              'unit_book_pages'.tr(namedArgs: {'from': '$from', 'to': '$to'}),
              style: context.texts.caption.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// How many lessons are done: green once all are.
class UnitProgressBar extends StatelessWidget {
  const UnitProgressBar({
    required this.done,
    required this.total,
    required this.complete,
    super.key,
  });

  final int done;
  final int total;
  final bool complete;

  static const _height = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final share = total == 0 ? 0.0 : done / total;
    return Semantics(
      label: 'unit_progress_label'.tr(),
      value: '$done / $total',
      child: ExcludeSemantics(
        child: Container(
          height: _height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.primary.surface,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: share),
            duration: AppMotion.resolve(context, AppMotion.countUp),
            curve: AppMotion.smoothOut,
            builder: (context, value, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: complete ? colors.success.fill : colors.primary.fill,
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «ستتعلّم أن…», open on the first visit and folded after.
class _Goals extends StatelessWidget {
  const _Goals({
    required this.goals,
    required this.open,
    required this.onToggle,
  });

  final List<String> goals;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final turn = AppMotion.resolve(context, AppMotion.closeUp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTapTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('unit_goals'.tr(), style: texts.bodyStrong),
                  ),
                  AnimatedRotation(
                    turns: open ? .5 : 0,
                    duration: turn,
                    curve: AppMotion.out,
                    child: AppIconView(
                      AppIcon.chevronDown,
                      size: AppSizes.iconMd - 4,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SmoothSize(
          duration: AppMotion.closeUp,
          child: open
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, goal) in goals.indexed) ...[
                        if (index > 0) const SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                top: AppSpacing.xxs,
                              ),
                              child: AppIconView(
                                AppIcon.check,
                                size: AppSizes.iconMd - 4,
                                color: colors.success.fill,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm + 2),
                            Expanded(child: Text(goal, style: texts.body)),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ConceptChip extends StatelessWidget {
  const _ConceptChip(this.name);

  final String name;

  static const _height = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: _height,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.info.surface,
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          name,
          style: context.texts.captionStrong.copyWith(color: colors.info.text),
        ),
      ),
    );
  }
}

/// Above the lessons: the unit is done and the next one waits, or the unit
/// is still locked behind another.
class UnitBanner extends StatelessWidget {
  const UnitBanner.done({
    required this.message,
    required this.action,
    required this.onAction,
    super.key,
  }) : _done = true;

  const UnitBanner.locked({
    required this.message,
    required this.action,
    required this.onAction,
    super.key,
  }) : _done = false;

  final String message;
  final String? action;
  final VoidCallback? onAction;
  final bool _done;

  static const _mark = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = _done ? colors.success : colors.info;
    final action = this.action;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_done)
                  Container(
                    width: _mark,
                    height: _mark,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone.fill,
                      shape: BoxShape.circle,
                    ),
                    child: AppIconView(
                      AppIcon.check,
                      size: AppSizes.iconMd - 4,
                      color: colors.surface,
                    ),
                  )
                else
                  AppIconView(
                    AppIcon.lock,
                    size: AppSizes.iconMd - 2,
                    color: tone.fill,
                  ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    message,
                    style: context.texts.bodyStrong.copyWith(color: tone.text),
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md + 2),
              AppButton(label: action, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
