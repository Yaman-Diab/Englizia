import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The current island's flag on its top edge (bubble §6): the unit's cover,
/// its title and progress, «افتح الوحدة». Kids get both names, the unit's
/// stars and the speaker that says its name.
///
/// It is placed by its end edge ([endInset] from the frame's end, scaled)
/// and grows toward the start up to [maxWidth].
///
/// ASSUMPTION(design): the 6 / 4 padding sits on the medal's and the
/// speaker's side, concentric in the pill (map AMBIG-8); the board's
/// physical values put it at the text's end.
class IslandBanner extends StatelessWidget {
  const IslandBanner({
    required this.unit,
    required this.emar,
    required this.onOpen,
    this.maxWidth,
    super.key,
  }) : kids = false,
       speaking = false,
       onListen = null;

  const IslandBanner.kid({
    required this.unit,
    required this.speaking,
    required VoidCallback this.onListen,
    required this.onOpen,
    this.maxWidth,
    super.key,
  }) : kids = true,
       emar = false;

  final HomeUnit unit;
  final bool kids;

  /// The sub line is the unit's book pages instead of its lessons done.
  final bool emar;

  /// The guide is saying the unit's name: the speaker wears its ring.
  final bool speaking;
  final VoidCallback? onListen;

  /// Opens the unit's screen.
  final VoidCallback onOpen;

  /// The widest it grows; by default what the screen's frame leaves (236 at
  /// 360, kids 276).
  final double? maxWidth;

  /// The design's distance from the frame's end (left in right-to-left),
  /// to scale with the frame.
  static double endInset({required bool kids}) => kids ? 64 : 104;

  /// Below the island's top edge.
  static const fromTop = 2.0;

  static const height = 48.0;
  static const kidHeight = 64.0;

  /// The room it keeps from the frame's start edge at its widest.
  static const _startInset = 20.0;

  double _maxWidth(BuildContext context) {
    final frame = MapFrame(MediaQuery.sizeOf(context).width);
    final room =
        frame.fromStart(_startInset) - frame.scaled(endInset(kids: kids));
    return maxWidth ?? (kids ? room : math.min(236, room));
  }

  @override
  Widget build(BuildContext context) =>
      kids ? _kid(context) : _general(context);

  Widget _general(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final n = unit.lessons.length;
    final progress = 'unit_progress'.plural(
      n,
      namedArgs: {'done': '${math.min(unit.doneCount, n)}'},
    );
    final pages = unit.bookPages;
    final pagesText = pages == null
        ? null
        : 'unit_book_pages'.tr(
            namedArgs: {'from': '${pages.from}', 'to': '${pages.to}'},
          );
    // Emar: the book's line, or only its pages where the whole line would
    // be cut (the app's font runs wider than the design's).
    final shortPages = pages == null
        ? null
        : 'home_pages'.tr(
            namedArgs: {'from': '${pages.from}', 'to': '${pages.to}'},
          );
    final subStyle = texts.caption.copyWith(
      fontSize: 12,
      height: 16 / 12,
      color: colors.textSecondary,
    );
    final label = emar && pagesText != null
        ? 'home_banner_semantics_pages'.tr(
            namedArgs: {
              'number': '${unit.number}',
              'name': unit.title,
              'progress': progress,
              'pages': pagesText,
            },
          )
        : 'home_banner_semantics'.tr(
            namedArgs: {
              'number': '${unit.number}',
              'name': unit.title,
              'progress': progress,
            },
          );
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: ExcludeSemantics(
          child: PressScale(
            scale: AppMotion.scaleSmall,
            child: Container(
              height: height,
              constraints: BoxConstraints(maxWidth: _maxWidth(context)),
              padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 12, 0),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: context.scheme.outline),
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UnitMedal(url: unit.coverUrl, size: 36),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, box) => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unitTitle(unit),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: texts.captionStrong.copyWith(
                              fontSize: 12,
                              height: 17 / 12,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            switch ((emar, pagesText, shortPages)) {
                              (true, final long?, final short?) =>
                                _fits(context, long, subStyle, box.maxWidth)
                                    ? long
                                    : short,
                              _ => progress,
                            },
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: subStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static bool _fits(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final fits = painter.width <= width;
    painter.dispose();
    return fits;
  }

  Widget _kid(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final en = unit.titleEn ?? '';
    final stars = unit.stars ?? 0;
    return Container(
      height: kidHeight,
      constraints: BoxConstraints(maxWidth: _maxWidth(context)),
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 16, 0),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: context.scheme.outline),
        borderRadius: BorderRadius.circular(kidHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'home_listen_unit'.tr(
              namedArgs: {'ar': unit.title, 'en': en},
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onListen,
              child: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.bubbleIn),
                curve: AppMotion.out,
                width: AppSizes.kidsMinTapTarget,
                height: AppSizes.kidsMinTapTarget,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.info.fill,
                  boxShadow: [
                    BoxShadow(
                      color: speaking
                          ? colors.info.surface
                          : colors.info.surface.withValues(alpha: 0),
                      spreadRadius: speaking ? 4 : 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AppIconView(
                  AppIcon.volume,
                  color: colors.surface,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Semantics(
              button: true,
              label: 'home_kid_banner_semantics'.tr(
                namedArgs: {
                  'ar': unit.title,
                  'en': en,
                  'stars': 'home_stars_of_five'.plural(stars),
                },
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpen,
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.kidsMinTapTarget,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                unit.title,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: texts.bodyStrong.copyWith(
                                  height: 22 / 16,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            if (en.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  en,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.ltr,
                                  style: texts.kidsCard.copyWith(
                                    fontSize: 16,
                                    height: 22 / 16,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        UnitStars(stars: stars, size: AppSizes.iconSm),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A unit's cover in a circle, centre-cropped; the unit flag on the
/// illustration ground when it has none.
class UnitMedal extends StatelessWidget {
  const UnitMedal({required this.url, required this.size, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = this.url;
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: ColoredBox(
            color: colors.primary.surface,
            child: url == null || url.isEmpty
                ? Center(
                    child: AppIconView(
                      AppIcon.unitFlag,
                      color: colors.primary.fill,
                      size: size / 2,
                    ),
                  )
                : url.startsWith('http')
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )
                : SvgPicture.asset(url, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// A unit's five stars: [stars] filled, the rest empty. Decorative.
class UnitStars extends StatelessWidget {
  const UnitStars({required this.stars, required this.size, super.key});

  final int stars;
  final double size;

  static const count = 5;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xxs),
          KidStar(size: size, filled: i < stars),
        ],
      ],
    ),
  );
}
