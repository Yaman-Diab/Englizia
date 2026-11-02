import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/lessons/domain/services/concept_stations.dart';
import 'package:flutter/material.dart';

/// «يوم»، «3 أيام»، «14 يومًا».
String daysText(int days) => 'concept_days'.plural(days);

/// A concept's mark: a lightbulb on a soft square.
class ConceptIcon extends StatelessWidget {
  const ConceptIcon({this.size = 36, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final info = context.colors.info;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: info.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
        child: Center(
          child: AppIconView(
            AppIcon.lightbulb,
            size: size * .55,
            color: info.fill,
          ),
        ),
      ),
    );
  }
}

/// Five small dots, the stations passed filled, left to right in any language.
class StationDots extends StatelessWidget {
  const StationDots({required this.passed, super.key});

  final int passed;

  static const _dot = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'concept_stations_said'.tr(namedArgs: {'n': '$passed'}),
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < stationCount; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: i < passed ? colors.success.fill : null,
                  shape: BoxShape.circle,
                  border: i < passed
                      ? null
                      : Border.all(color: colors.border, width: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The five stations, each with its wait, the passed ones filled with a check
/// and the line between them growing; the current one ringed (S §11.2).
class StationTrack extends StatelessWidget {
  const StationTrack({required this.passed, super.key});

  /// 0 to 5.
  final int passed;

  static const _circle = 28.0;
  static const _line = 2.0;
  static const _rest = .6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final appDirection = Directionality.of(context);
    return Semantics(
      label: 'concept_stations_said'.tr(
        namedArgs: {'n': '${passed.clamp(0, stationCount)}'},
      ),
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, box) {
            final step = box.maxWidth / stationCount;
            final share =
                passed.clamp(0, stationCount - 1) / (stationCount - 1);
            return Stack(
              children: [
                PositionedDirectional(
                  start: step / 2,
                  end: step / 2,
                  top: _circle / 2 - _line / 2,
                  height: _line,
                  child: ColoredBox(
                    color: colors.border.withValues(alpha: _rest),
                  ),
                ),
                PositionedDirectional(
                  start: step / 2,
                  top: _circle / 2 - _line / 2,
                  height: _line,
                  width: box.maxWidth - step,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AnimatedFractionallySizedBox(
                      duration: AppMotion.resolve(context, AppMotion.sheetIn),
                      curve: AppMotion.out,
                      widthFactor: share,
                      heightFactor: 1,
                      child: ColoredBox(color: colors.success.fill),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < stationCount; i++)
                      Expanded(
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: AppMotion.resolve(
                                context,
                                AppMotion.sheetIn,
                              ),
                              width: _circle,
                              height: _circle,
                              decoration: BoxDecoration(
                                color: i < passed
                                    ? colors.success.fill
                                    : colors.surface,
                                shape: BoxShape.circle,
                                border: i < passed
                                    ? null
                                    : Border.all(
                                        color: i == passed
                                            ? colors.primaryStrong
                                            : colors.border,
                                        width: i == passed ? 2 : 1.5,
                                      ),
                              ),
                              child: Center(
                                child: i < passed
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: AppSizes.iconSm,
                                        color: colors.surface,
                                      )
                                    : Text(
                                        '${i + 1}',
                                        style: texts.captionStrong.copyWith(
                                          color: i == passed
                                              ? colors.primary.text
                                              : colors.textSecondary,
                                          height: 1,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              daysText(stationDays[i]),
                              maxLines: 1,
                              textDirection: appDirection,
                              style: texts.caption.copyWith(
                                color: colors.textSecondary,
                                fontSize: texts.caption.fontSize! * .85,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The concept's name over a question.
class ConceptChip extends StatelessWidget {
  const ConceptChip({required this.name, super.key});

  final String name;

  static const _height = 28.0;

  @override
  Widget build(BuildContext context) {
    final info = context.colors.info;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: _height,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: info.surface,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconView(
              AppIcon.lightbulb,
              size: AppSizes.iconSm,
              color: info.fill,
            ),
            const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.captionStrong.copyWith(color: info.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
