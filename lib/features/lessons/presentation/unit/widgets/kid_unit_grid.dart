import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A kids' unit (S §13.5): a picture card for each lesson with its stars,
/// two to a row, the current one ringed and breathing.
class KidUnitGrid extends StatelessWidget {
  const KidUnitGrid({
    required this.plan,
    required this.status,
    required this.available,
    required this.onPressed,
    this.currentKey,
    super.key,
  });

  final UnitPlan plan;
  final UnitLessonStatus Function(int index) status;
  final bool Function(UnitLesson lesson) available;
  final ValueChanged<UnitLesson> onPressed;
  final GlobalKey? currentKey;

  static const _gap = AppSpacing.md + 2;

  @override
  Widget build(BuildContext context) {
    final lessons = plan.lessons;
    return Column(
      children: [
        for (var row = 0; row < lessons.length; row += 2) ...[
          if (row > 0) const SizedBox(height: _gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = row; index < row + 2; index++) ...[
                  if (index > row) const SizedBox(width: _gap),
                  Expanded(
                    child: index < lessons.length
                        ? _KidCard(
                            key: status(index) == UnitLessonStatus.current
                                ? currentKey
                                : null,
                            lesson: lessons[index],
                            status: status(index),
                            open: available(lessons[index]),
                            onPressed: () => onPressed(lessons[index]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _KidCard extends StatelessWidget {
  const _KidCard({
    required this.lesson,
    required this.status,
    required this.open,
    required this.onPressed,
    super.key,
  });

  final UnitLesson lesson;
  final UnitLessonStatus status;
  final bool open;
  final VoidCallback onPressed;

  static const _picture = 108.0;
  static const _star = 15.0;
  static const _lock = 36.0;
  static const _dimmed = .5;
  static const _breath = 1.03;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = status == UnitLessonStatus.current;
    final locked = status == UnitLessonStatus.locked || !open;
    final state = switch (status) {
      UnitLessonStatus.locked => 'unit_status_locked'.tr(),
      UnitLessonStatus.current => 'unit_status_current'.tr(),
      _ when !open => 'unit_status_offline'.tr(),
      _ => 'unit_kid_stars'.plural(lesson.stars),
    };
    final image = lesson.imageUrl;
    Widget card = Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kidRadius),
        side: BorderSide(
          color: current ? colors.primaryStrong : colors.border,
          width: current ? 4 : 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: AppSpacing.sm + 2,
              ),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ColoredBox(
                      color: colors.primary.surface,
                      child: Center(
                        child: image == null
                            ? null
                            : FittedBox(
                                child: KidPicture(url: image, size: _picture),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    lesson.title,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: context.texts.kidsCard.copyWith(
                      color: colors.textPrimary,
                      fontSize: 20,
                      height: 28 / 20,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var star = 0; star < 5; star++) ...[
                        if (star > 0) const SizedBox(width: AppSpacing.xxs),
                        KidStar(size: _star, filled: star < lesson.stars),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (locked)
              PositionedDirectional(
                top: AppSpacing.sm,
                end: AppSpacing.sm,
                child: Container(
                  width: _lock,
                  height: _lock,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: AppIconView(
                    AppIcon.lock,
                    size: AppSizes.iconMd - 4,
                    color: colors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    card = Semantics(
      button: true,
      label: 'unit_kid_semantics'.tr(
        namedArgs: {'name': lesson.title, 'status': state},
      ),
      excludeSemantics: true,
      child: Opacity(opacity: locked ? _dimmed : 1, child: card),
    );
    if (current && !AppMotion.reduceMotion(context)) {
      card = card
          .animate(onPlay: (breath) => breath.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: _breath,
            duration: AppMotion.kidCurrentPulse * .5,
            curve: AppMotion.inOut,
          );
    }
    return card;
  }
}
