import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:flutter/material.dart';

/// The kids' week (design "Home Archipelago"): a square for
/// each day with a star on the days learned, and the day's letter under it,
/// today's in the strong colour. Seven equal columns; the squares shrink
/// below 28 when the row is narrower than the design's. Decorative: the
/// header's label says the streak.
class KidWeek extends StatelessWidget {
  const KidWeek({required this.week, super.key});

  final StudyWeek week;

  static const square = 28.0;
  static const _gap = 4.0;
  static const _radius = 9.0;
  static const _star = 16.0;

  /// A day counts as learned once it has a minute in it.
  static bool learned(StudyDay day) => (day.minutes ?? 0) > 0;

  /// The day's letter, the week starting on Saturday: «س ح ن ث ر خ ج».
  static String letterOf(DateTime day) => switch (day.weekday) {
    DateTime.saturday => 'home_wd_sat'.tr(),
    DateTime.sunday => 'home_wd_sun'.tr(),
    DateTime.monday => 'home_wd_mon'.tr(),
    DateTime.tuesday => 'home_wd_tue'.tr(),
    DateTime.wednesday => 'home_wd_wed'.tr(),
    DateTime.thursday => 'home_wd_thu'.tr(),
    _ => 'home_wd_fri'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    final texts = context.texts;
    final days = week.days;
    if (days.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final room =
              (constraints.maxWidth - _gap * (days.length - 1)) / days.length;
          final side = math.max(0.0, math.min(square, room));
          final ratio = side / square;
          return Row(
            children: [
              for (final (index, day) in days.indexed) ...[
                if (index > 0) const SizedBox(width: _gap),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: side,
                        height: side,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: learned(day)
                              ? colors.reward.surface
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(_radius * ratio),
                        ),
                        child: learned(day)
                            ? KidStar(size: _star * ratio)
                            : null,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        letterOf(day.date),
                        maxLines: 1,
                        style: texts
                            .sized(
                              index == week.today
                                  ? texts.captionStrong
                                  : texts.caption,
                              size: 12,
                              line: 16,
                              running: false,
                            )
                            .copyWith(
                              color: index == week.today
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
