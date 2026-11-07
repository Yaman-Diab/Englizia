import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/paint/fog_layer.dart';
import 'package:englizia/features/home/presentation/home/paint/island_art.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A done, open or locked island as one button (design "Home Archipelago"): its
/// drawing, the unit's cover in the medallion, clouds and a lock while locked,
/// and under it the unit's name with «أعد», its pages, or when it opens. 176 ×
/// 162, the drawing in its top 112.
class CompactIsland extends StatelessWidget {
  const CompactIsland({
    required this.unit,
    required this.slot,
    required this.tone,
    required this.kids,
    required this.onPressed,
    this.shake = 0,
    this.clear = 0,
    this.flagWave = false,
    this.fogRunning = false,
    this.labels = true,
    super.key,
  });

  final HomeUnit unit;
  final IslandSlot slot;
  final SeaTone tone;
  final bool kids;
  final VoidCallback onPressed;

  /// M9's shake, 0 to 1 of [AppMotion.homeShake]; 0 at rest.
  final double shake;

  /// M6: how far the clouds have parted and the lock has opened, 0 to 1.
  final double clear;

  /// The done flag's pennant waves; the clouds drift (the loop budget's).
  final bool flagWave;
  final bool fogRunning;

  /// Its labels under the drawing; false where the map draws them over every
  /// island instead ([CompactIslandLabels]).
  final bool labels;

  /// The whole button, and the drawing's box in its top.
  static const size = Size(176, 162);
  static const art = MapLayout.compactSize;

  /// The labels' top, under the drawing.
  static const labelsTop = 114.0;

  /// The medallion's centre in the drawing, and its cover's radius.
  static const medal = Offset(88, 42);
  static const coverRadius = 22.0;

  /// The lock badge, 36, centred on (88, 52).
  static const lockSize = 36.0;
  static const lockTop = 34.0;

  /// M6: the lock lifts and turns away as it opens.
  static const lockLift = 6.0;
  static const lockTurn = -12.0;

  /// A locked cover: saturation .1, opacity .7.
  static const _lockedSaturation = .1;
  static const _lockedOpacity = .7;

  bool get _locked => unit.status == UnitLessonStatus.locked;
  bool get _open => unit.status == UnitLessonStatus.open;
  bool get _done => unit.status == UnitLessonStatus.done;

  /// The unit before this one, which opens it.
  int get _before => _beforeOf(unit);

  static int _beforeOf(HomeUnit unit) =>
      unit.lockedBy?.number ?? math.max(1, unit.number - 1);

  /// The design's shake: offsets in equal legs, in the right-to-left layout's
  /// physical space.
  static double shakeOffset(double t) {
    const offsets = AppMotion.homeIslandShakeOffsets;
    if (t <= 0 || t >= 1) return 0;
    final at = AppMotion.inOut.transform(t) * (offsets.length - 1);
    final i = at.floor().clamp(0, offsets.length - 2);
    return lerpDouble(offsets[i], offsets[i + 1], at - i)!;
  }

  /// [shakeOffset] as drawn, the right-to-left layout's offset mirrored.
  static Offset shakeOf(BuildContext context, double shake) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Offset(shakeOffset(shake) * (rtl ? 1 : -1), 0);
  }

  String _label() {
    final number = '${unit.number}';
    if (_done) {
      return kids
          ? 'home_isle_done_kid_semantics'.tr(
              namedArgs: {
                'number': number,
                'name': unit.title,
                'stars': 'home_stars_of_five'.plural(unit.stars ?? 0),
              },
            )
          : 'home_isle_done_semantics'.tr(
              namedArgs: {'number': number, 'name': unit.title},
            );
    }
    final pages = unit.bookPages;
    if (_open && pages != null) {
      return 'home_isle_open_semantics'.tr(
        namedArgs: {
          'number': number,
          'name': unit.title,
          'from': '${pages.from}',
          'to': '${pages.to}',
        },
      );
    }
    return 'home_isle_locked_semantics'.tr(
      namedArgs: {'number': number, 'name': unit.title, 'before': '$_before'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockOpacity = _open ? 0.0 : 1 - clear;
    return Transform.translate(
      offset: shakeOf(context, shake),
      child: Semantics(
        button: true,
        label: _label(),
        child: PressScale(
          scale: AppMotion.scaleSmall,
          child: GestureDetector(
            onTap: onPressed,
            behavior: HitTestBehavior.opaque,
            child: ExcludeSemantics(
              child: SizedBox.fromSize(
                size: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      width: art.width,
                      height: art.height,
                      child: IslandArt.compact(
                        status: unit.status,
                        tone: tone,
                        unitIndex: slot.index,
                        flagWave: flagWave,
                      ),
                    ),
                    if (unit.coverUrl case final cover?)
                      PositionedDirectional(
                        start: medal.dx - coverRadius,
                        top: medal.dy - coverRadius,
                        width: coverRadius * 2,
                        height: coverRadius * 2,
                        child: _Cover(url: cover, faded: _locked),
                      ),
                    if (_locked)
                      PositionedDirectional(
                        start: 0,
                        top: 0,
                        width: art.width,
                        height: art.height,
                        child: FogLayer(clear: clear, running: fogRunning),
                      ),
                    if (!_done && lockOpacity > 0)
                      PositionedDirectional(
                        start: medal.dx - lockSize / 2,
                        top: lockTop,
                        width: lockSize,
                        height: lockSize,
                        child: _LockBadge(opening: clear, opacity: lockOpacity),
                      ),
                    if (labels)
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        top: labelsTop,
                        child: _Labels(unit: unit, kids: kids, before: _before),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact island's labels alone, in its box and shaking with it. The map
/// draws them after every island's drawing: where the columns overlap (320
/// wide) the next island's drawing and clouds reach over the labels of the
/// one before, and the design draws the labels over all the islands.
/// Decorative: the island's button says them.
class CompactIslandLabels extends StatelessWidget {
  const CompactIslandLabels({
    required this.unit,
    required this.kids,
    this.shake = 0,
    super.key,
  });

  final HomeUnit unit;
  final bool kids;

  /// The island's shake ([CompactIsland.shake]).
  final double shake;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Transform.translate(
        offset: CompactIsland.shakeOf(context, shake),
        child: SizedBox.fromSize(
          size: CompactIsland.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PositionedDirectional(
                start: 0,
                end: 0,
                top: CompactIsland.labelsTop,
                child: _Labels(
                  unit: unit,
                  kids: kids,
                  before: CompactIsland._beforeOf(unit),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The unit's cover in the medallion, a centre crop; faded while locked.
class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.faded});

  final String url;
  final bool faded;

  /// CSS `saturate(s)` with the alpha scaled by `a`.
  static List<double> _matrix(double s, double a) => [
    .213 + .787 * s, .715 - .715 * s, .072 - .072 * s, 0, 0, //
    .213 - .213 * s, .715 + .285 * s, .072 - .072 * s, 0, 0, //
    .213 - .213 * s, .715 - .715 * s, .072 + .928 * s, 0, 0, //
    0, 0, 0, a, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final Widget image = url.startsWith('http')
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : SvgPicture.asset(url, fit: BoxFit.cover);
    return ClipOval(
      child: faded
          ? ColorFiltered(
              colorFilter: ColorFilter.matrix(
                _matrix(
                  CompactIsland._lockedSaturation,
                  CompactIsland._lockedOpacity,
                ),
              ),
              child: image,
            )
          : image,
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.opening, required this.opacity});

  final double opening;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, -CompactIsland.lockLift * opening),
        child: Transform.rotate(
          angle: CompactIsland.lockTurn * opening * math.pi / 180,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: context.scheme.outline, width: 1.5),
            ),
            child: Center(
              child: AppIconView(
                AppIcon.lock,
                color: colors.textSecondary,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Under the drawing: the name, then «أعد», the pages, or when it opens;
/// kids, the English name and the stars.
class _Labels extends StatelessWidget {
  const _Labels({required this.unit, required this.kids, required this.before});

  final HomeUnit unit;
  final bool kids;
  final int before;

  static const _gap = 4.0;
  static const _star = 14.0;
  static const _starGap = 2.0;
  static const _stars = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final done = unit.status == UnitLessonStatus.done;
    final pages = unit.bookPages;
    final sub = texts
        .sized(texts.caption, size: 12, line: 16, running: false)
        .copyWith(color: colors.textSecondary);
    final english = unit.titleEn;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kids ? unit.title : unitTitle(unit),
          style: texts
              .sized(texts.captionStrong, size: 13, line: 18, running: false)
              .copyWith(color: colors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (kids && english != null) ...[
          const SizedBox(height: _gap),
          Text(
            english,
            style: texts
                .sized(texts.kidsCard, size: 15, line: 20, running: false)
                .copyWith(color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
          ),
        ],
        if (kids && done) ...[
          const SizedBox(height: _gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _stars; i++) ...[
                if (i > 0) const SizedBox(width: _starGap),
                KidStar(size: _star, filled: i < (unit.stars ?? 0)),
              ],
            ],
          ),
        ],
        if (!kids && done) ...[const SizedBox(height: _gap), const _RedoChip()],
        if (!kids && !done) ...[
          const SizedBox(height: _gap),
          Text(
            unit.status == UnitLessonStatus.open && pages != null
                ? 'home_pages'.tr(
                    namedArgs: {'from': '${pages.from}', 'to': '${pages.to}'},
                  )
                : 'home_opens_after_unit'.tr(args: ['$before']),
            style: sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// «أعد», a chip: the whole island is the button.
class _RedoChip extends StatelessWidget {
  const _RedoChip();

  static const _height = 26.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: context.scheme.outline, width: 1.5),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          'unit_redo'.tr(),
          style: context.texts
              .sized(
                context.texts.captionStrong,
                size: 12,
                line: 12,
                running: false,
              )
              .copyWith(color: colors.primary.text),
        ),
      ),
    );
  }
}
