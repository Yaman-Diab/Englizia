import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:flutter/material.dart';

/// Kids: the guide saying the unit's name, in Arabic then English, above
/// the island's banner (bubble §10, M14); its small corner points down at
/// the guide by the banner. It comes in as it is built; how long it stays is
/// the motion's.
class KidSayBubble extends StatelessWidget {
  const KidSayBubble({required this.unit, super.key});

  final HomeUnit unit;

  /// The design's distance from the frame's end (left in right-to-left), to
  /// scale with the frame; it stands this far above the island's top.
  static const endInset = 46.0;
  static const rise = 50.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final en = unit.titleEn;
    final reduce = AppMotion.reduceMotion(context);
    final bubble = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.info.surface,
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(20),
          topEnd: Radius.circular(20),
          bottomStart: Radius.circular(20),
          bottomEnd: Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconView(AppIcon.volume, color: colors.info.fill, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Text(
            unit.title,
            maxLines: 1,
            softWrap: false,
            style: texts
                .sized(texts.bodyStrong, size: 18, line: 24, running: false)
                .copyWith(color: colors.textPrimary),
          ),
          if (en != null && en.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              en,
              maxLines: 1,
              softWrap: false,
              textDirection: TextDirection.ltr,
              style: texts
                  .sized(texts.kidsCard, size: 18, line: 24, running: false)
                  .copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: en == null || en.isEmpty
          ? unit.title
          : 'home_listen_unit'.tr(namedArgs: {'ar': unit.title, 'en': en}),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduce ? AppMotion.quick : AppMotion.bubbleIn,
          curve: AppMotion.out,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(
              scale: reduce ? 1 : lerpDouble(AppMotion.homeBubbleFrom, 1, t)!,
              alignment: AlignmentDirectional.bottomEnd.resolve(
                Directionality.of(context),
              ),
              child: child,
            ),
          ),
          child: bubble,
        ),
      ),
    );
  }
}
