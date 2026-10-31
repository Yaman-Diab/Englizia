import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:flutter/material.dart';

/// The rule in short: Arabic words, an English table with the very letters marked,
/// and examples with their sound. It stays usable if the video fails.
class RuleSummaryCard extends StatelessWidget {
  const RuleSummaryCard({
    required this.summary,
    required this.saying,
    required this.onSay,
    this.bookPage,
    super.key,
  });

  final RuleSummary summary;
  final int? saying;
  final ValueChanged<int> onSay;

  /// A lesson with no video points at the book instead.
  final int? bookPage;

  static const _iconBox = 36.0;
  static const _chipHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final page = bookPage;
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg + AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: _iconBox,
                height: _iconBox,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: AppIconView(
                  AppIcon.lightbulb,
                  size: AppSizes.iconSm + AppSpacing.xxs,
                  color: colors.primary.fill,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'lesson_gv_summary'.tr(),
                    style: texts.title.copyWith(color: colors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
          if (page != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                height: _chipHeight,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_chipHeight / 2),
                  border: Border.all(color: context.scheme.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconView(
                      AppIcon.book,
                      size: AppSizes.iconSm,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'lesson_gv_book_page'.tr(namedArgs: {'page': '$page'}),
                      style: texts.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            summary.text,
            textDirection: TextDirection.rtl,
            style: texts.body.copyWith(color: colors.textPrimary),
          ),
          if (summary.rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _RuleTable(rows: summary.rows),
          ],
          if (summary.examples.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final (i, example) in summary.examples.indexed)
              _Example(
                example: example,
                first: i == 0,
                saying: saying == i,
                onSay: () => onSay(i),
              ),
          ],
        ],
      ),
    );
  }
}

class _RuleTable extends StatelessWidget {
  const _RuleTable({required this.rows});

  final List<RuleRow> rows;

  static const _rowHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  endIndent: AppSpacing.lg,
                  color: colors.border,
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _rowHeight),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.left,
                          locale: const Locale('en'),
                          style: texts.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '→',
                        style: texts.body.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _Parts(parts: row.right, strong: true),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// English with its strong and marked parts.
class _Parts extends StatelessWidget {
  const _Parts({required this.parts, this.strong = false});

  final List<RulePart> parts;

  /// All of it heavier, not only its strong parts.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Text.rich(
      locale: const Locale('en'),
      TextSpan(
        style: (strong ? texts.bodyStrong : texts.body).copyWith(
          color: colors.textPrimary,
        ),
        children: [
          for (final part in parts)
            TextSpan(
              text: part.text,
              style: part.marked
                  ? TextStyle(
                      fontFamily: texts.bodyStrong.fontFamily,
                      color: colors.primary.text,
                      decoration: TextDecoration.underline,
                      decorationColor: colors.primary.text,
                      decorationThickness: 2,
                    )
                  : part.strong
                  ? TextStyle(fontFamily: texts.bodyStrong.fontFamily)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Example extends StatelessWidget {
  const _Example({
    required this.example,
    required this.first,
    required this.saying,
    required this.onSay,
  });

  final RuleExample example;
  final bool first;
  final bool saying;
  final VoidCallback onSay;

  static const _circle = 40.0;
  static const _ring = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: colors.border)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Parts(parts: example.parts),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      example.arabic,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.start,
                      style: texts.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (example.audioUrl != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: onSay,
                  tooltip: 'lesson_gv_listen_example'.tr(
                    namedArgs: {'text': example.english},
                  ),
                  style: IconButton.styleFrom(
                    padding: EdgeInsetsDirectional.zero,
                    fixedSize: const Size.square(AppSizes.minTapTarget),
                  ),
                  icon: AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.quick),
                    width: _circle,
                    height: _circle,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.info.fill,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: saying
                              ? colors.info.surface
                              : Colors.transparent,
                          spreadRadius: _ring,
                        ),
                      ],
                    ),
                    child: AppIconView(
                      AppIcon.volume,
                      size: AppSizes.iconSm + AppSpacing.xxs,
                      color: colors.surface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
