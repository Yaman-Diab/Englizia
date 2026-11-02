import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_sentence.dart';
import 'package:englizia/features/lessons/presentation/widgets/save_star.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A tapped word's card, pointing at it: above when there is room, and never past
/// the screen's edges. A span has its form, kind, meaning and note, its sound and
/// the star; a word with only a meaning has a small one.
class ReaderCard extends StatelessWidget {
  const ReaderCard({
    required this.span,
    required this.word,
    required this.gloss,
    required this.anchor,
    required this.area,
    required this.saved,
    required this.onSay,
    required this.onSave,
    super.key,
  });

  final ReaderSpan? span;
  final String word;
  final String? gloss;

  /// The word's place in [area].
  final Rect anchor;
  final Size area;
  final bool saved;
  final VoidCallback onSay;
  final VoidCallback onSave;

  static const _fullWidth = 296.0;
  static const _smallWidth = 220.0;
  static const _margin = AppSpacing.md;
  static const _gap = AppSpacing.md;
  static const _arrow = 12.0;
  static const _fullHeight = 210.0;
  static const _smallHeight = 110.0;
  static const _growFrom = .95;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final span = this.span;
    final width = math.min(
      span == null ? _smallWidth : _fullWidth,
      area.width - _margin * 2,
    );
    final left = (anchor.center.dx - width / 2).clamp(
      _margin,
      area.width - width - _margin,
    );
    final above =
        anchor.top > (span == null ? _smallHeight : _fullHeight) + _gap * 2;
    final pointAt = (anchor.center.dx - left - _arrow / 2).clamp(
      _margin,
      width - _margin - _arrow,
    );
    final side = BorderSide(color: context.scheme.outline);
    final appDirection = Directionality.of(context);
    final card = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.fromBorderSide(side),
            boxShadow: [
              BoxShadow(
                color: context.scheme.shadow.withValues(alpha: .16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Directionality(
            textDirection: appDirection,
            child: span == null ? _small(context) : _full(context, span),
          ),
        ),
        PositionedDirectional(
          start: pointAt,
          top: above ? null : -_arrow / 2,
          bottom: above ? -_arrow / 2 : null,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: _arrow,
              height: _arrow,
              decoration: BoxDecoration(
                color: colors.surface,
                border: above
                    ? Border(right: side, bottom: side)
                    : Border(left: side, top: side),
              ),
            ),
          ),
        ),
      ],
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: PositionedDirectional(
        start: left,
        top: above ? null : anchor.bottom + _gap,
        bottom: above
            ? (area.height - anchor.top + _gap).clamp(_margin, area.height)
            : null,
        child: AppMotion.reduceMotion(context)
            ? card
            : card
                  .animate()
                  .fadeIn(duration: AppMotion.quick, curve: AppMotion.out)
                  .scaleXY(begin: _growFrom, end: 1, curve: AppMotion.out),
      ),
    );
  }

  Widget _small(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                word,
                locale: const Locale('en'),
                style: texts.bodyStrong.copyWith(color: colors.textPrimary),
              ),
              Text(
                gloss ?? '',
                textDirection: TextDirection.rtl,
                style: texts.body.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _SayButton(label: word, onTap: onSay),
      ],
    );
  }

  Widget _full(BuildContext context, ReaderSpan span) {
    final colors = context.colors;
    final texts = context.texts;
    final note = span.note;
    return Semantics(
      container: true,
      label: 'reader_span_card_said'.tr(
        namedArgs: {
          'base': span.base,
          'kind': spanKindName(span.kind),
          'meaning': span.arabic,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  span.base,
                  locale: const Locale('en'),
                  style: texts.title.copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _KindBadge(kind: span.kind),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            span.arabic,
            textDirection: TextDirection.rtl,
            style: texts.title.copyWith(color: colors.textPrimary),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    note,
                    textDirection: TextDirection.rtl,
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                  if (span.noteExample.isNotEmpty)
                    Text.rich(
                      locale: const Locale('en'),
                      textDirection: TextDirection.ltr,
                      TextSpan(
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        children: [
                          for (final part in span.noteExample)
                            TextSpan(
                              text: part.text,
                              style: part.strong
                                  ? TextStyle(
                                      fontFamily: texts.bodyStrong.fontFamily,
                                      color: colors.textPrimary,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SayButton(label: span.base, onTap: onSay),
              SaveStar(saved: saved, onTap: onSave),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final SpanKind kind;

  static const _height = 26.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color fill, Color ink, Color edge) = switch (kind) {
      SpanKind.phrasalVerb => (
        colors.primary.surface,
        colors.primary.text,
        Colors.transparent,
      ),
      SpanKind.word => (
        colors.background,
        colors.textSecondary,
        context.scheme.outline,
      ),
      SpanKind.idiom => (
        colors.info.surface,
        colors.info.text,
        Colors.transparent,
      ),
    };
    return Container(
      height: _height,
      alignment: Alignment.center,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: edge),
      ),
      child: Text(
        spanKindName(kind),
        textDirection: TextDirection.rtl,
        style: context.texts.captionStrong.copyWith(color: ink),
      ),
    );
  }
}

class _SayButton extends StatelessWidget {
  const _SayButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const _circle = 40.0;

  @override
  Widget build(BuildContext context) {
    final ToneColors info = context.colors.info;
    return IconButton(
      onPressed: onTap,
      tooltip: 'reader_listen_to'.tr(namedArgs: {'text': label}),
      style: IconButton.styleFrom(
        padding: EdgeInsetsDirectional.zero,
        fixedSize: const Size.square(AppSizes.minTapTarget),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Container(
        width: _circle,
        height: _circle,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: info.fill, shape: BoxShape.circle),
        child: AppIconView(
          AppIcon.volume,
          size: AppSizes.iconSm + AppSpacing.xxs,
          color: context.colors.surface,
        ),
      ),
    );
  }
}
