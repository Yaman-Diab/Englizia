import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_sentence.dart';
import 'package:flutter/material.dart';

/// Shown once ever: a light dimming with the first sentence left clear, and a card
/// saying what to press. Pressing anywhere closes it, and it doesn't come back.
class ReaderTip extends StatefulWidget {
  const ReaderTip({
    required this.keys,
    required this.areaKey,
    required this.content,
    required this.onClose,
    super.key,
  });

  final ReaderKeys keys;
  final GlobalKey areaKey;
  final ReaderContent content;
  final VoidCallback onClose;

  @override
  State<ReaderTip> createState() => _ReaderTipState();
}

class _ReaderTipState extends State<ReaderTip> {
  static const _dim = .32;
  static const _gap = AppSpacing.md;
  static const _arrow = 12.0;

  Rect? _hole;
  double? _pointAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final area = widget.areaKey.currentContext?.findRenderObject();
    final box = widget.keys.sentence(0).currentContext?.findRenderObject();
    if (area is! RenderBox || box is! RenderBox || !box.hasSize) return;
    setState(() {
      _hole = box.localToGlobal(Offset.zero, ancestor: area) & box.size;
      _pointAt = _firstDotted(area);
    });
  }

  /// Across the screen, the middle of the first word that can be pressed.
  double? _firstDotted(RenderBox area) {
    final first = widget.content.sentences.first;
    for (final (i, word) in first.words.indexed) {
      if (widget.content.spanOf(first, word) == null) continue;
      final box = widget.keys.word(0, i).currentContext?.findRenderObject();
      if (box is! RenderBox) return null;
      return box.localToGlobal(box.size.center(Offset.zero), ancestor: area).dx;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final hole = _hole;
    final pointAt = _pointAt;
    if (hole == null) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: ExcludeSemantics(
            child: CustomPaint(
              painter: _DimWithHole(
                hole: hole,
                color: context.scheme.scrim.withValues(alpha: _dim),
              ),
            ),
          ),
        ),
        if (pointAt != null)
          Directionality(
            textDirection: TextDirection.ltr,
            child: PositionedDirectional(
              start: pointAt - _arrow / 2,
              top: hole.bottom + _gap - _arrow / 2,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: SizedBox.square(
                  dimension: _arrow,
                  child: ColoredBox(color: colors.surface),
                ),
              ),
            ),
          ),
        PositionedDirectional(
          start: AppSpacing.lg + AppSpacing.xs,
          end: AppSpacing.lg + AppSpacing.xs,
          top: hole.bottom + _gap,
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Container(
              padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIconView(
                        AppIcon.lightbulb,
                        size: AppSizes.iconMd,
                        color: colors.info.fill,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'reader_tip'.tr(),
                          style: texts.body.copyWith(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'reader_tip_ok'.tr(),
                    expand: false,
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DimWithHole extends CustomPainter {
  const _DimWithHole({required this.hole, required this.color});

  final Rect hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(
          RRect.fromRectAndRadius(hole, const Radius.circular(AppRadius.lg)),
        ),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DimWithHole oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.color != color;
}
