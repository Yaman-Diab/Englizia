import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/header_styles.dart';
import 'package:flutter/material.dart';

/// «أكملت مستوى A2» with «ابدأ B1» (design "Home Archipelago"):
/// at the horizon right after the level is done, then in the notice slot at
/// each opening until the next level starts, the same card measured. A
/// live region; it carries the guide while [showGuide] ([guideKey] marks its
/// 64 box for a flight). Without a next level it has no button.
class LevelCompleteCard extends StatelessWidget {
  const LevelCompleteCard({
    required this.home,
    required this.showGuide,
    required this.onStart,
    this.guideKey,
    super.key,
  });

  final HomeSnapshot home;
  final bool showGuide;
  final VoidCallback onStart;
  final Key? guideKey;

  static const _guide = 64.0;
  static const _button = 52.0;
  static const _radius = 24.0;
  static const _check = 14.0;

  /// «أكملت مستوى A2»; a grade by its name, «أكملت الصف السابع».
  static String titleOf(HomeSnapshot home) {
    final level = home.level;
    return home.enrollment.levelLabel == HomeLevelLabel.grade &&
            level.name.isNotEmpty
        ? 'home_grade_done'.tr(args: [level.name])
        : 'home_level_done'.tr(args: [level.label]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final next = home.level.next;
    final title = titleOf(home);
    final count = 'home_units_count'.plural(
      home.units.length,
      namedArgs: {'done': '${home.unitsDone}'},
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: next == null
          ? title
          : 'home_level_done_semantics'.tr(
              namedArgs: {'title': title, 'next': next.label},
            ),
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.success.surface,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  SizedBox.square(
                    key: guideKey,
                    dimension: _guide,
                    child: showGuide
                        ? const Mascot(
                            expression: MascotExpression.happy,
                            size: _guide,
                            sparkles: false,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppIconView(
                              AppIcon.check,
                              size: _check,
                              color: colors.success.text,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                count,
                                style: texts.captionStrong.copyWith(
                                  color: colors.success.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          title,
                          style: texts
                              .sized(
                                texts.title,
                                size: 20,
                                line: 28,
                                running: false,
                              )
                              .copyWith(color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (next != null)
              HeaderTap(
                label: 'home_start_level'.tr(args: [next.label]),
                onTap: onStart,
                pressScale: AppMotion.scaleSmall,
                builder: (context, _) => Container(
                  height: _button,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryStrong,
                    borderRadius: BorderRadius.circular(_button / 2),
                  ),
                  child: Text(
                    'home_start_level'.tr(args: [next.label]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texts.button.copyWith(color: colors.onPrimaryStrong),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
