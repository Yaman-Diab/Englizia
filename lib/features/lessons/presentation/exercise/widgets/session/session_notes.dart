import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:flutter/material.dart';

/// A thin band, not an error: it isn't the learner's mistake, and «تحقق» works.
class OfflineBand extends StatelessWidget {
  const OfflineBand({super.key});

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        color: colors.info.surface,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm - AppSpacing.xxs,
          ),
          child: Row(
            children: [
              AppIconView(
                AppIcon.wifiOff,
                size: _iconSize,
                color: colors.info.fill,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'lesson_offline'.tr(),
                  style: context.texts.caption.copyWith(
                    color: colors.info.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the question sits in the student's book.
class BookBadge extends StatelessWidget {
  const BookBadge({required this.reference, super.key});

  final BookReference reference;

  static const _height = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: _height,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: colors.border),
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
          Flexible(
            child: Text(
              'lesson_book_ref'.tr(
                namedArgs: {
                  'page': '${reference.page}',
                  'exercise': '${reference.exercise}',
                },
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hint: opens under the instruction, pushing down what is under it. The
/// content has it in Arabic, so it reads right to left in any app language, and
/// the English it names stands out and keeps its own direction (S §22).
class HintCard extends StatelessWidget {
  const HintCard({required this.hint, required this.open, super.key});

  final String hint;
  final bool open;

  static const _iconSize = 20.0;
  static final _english = RegExp(r"[A-Za-z][A-Za-z' -]*[A-Za-z]|[A-Za-z]");

  List<InlineSpan> _spans(BuildContext context) {
    final strong = context.texts.bodyStrong.copyWith(
      color: context.colors.info.text,
    );
    final spans = <InlineSpan>[];
    var at = 0;
    for (final match in _english.allMatches(hint)) {
      spans
        ..add(TextSpan(text: hint.substring(at, match.start)))
        ..add(
          TextSpan(
            text: match.group(0),
            locale: const Locale('en'),
            style: strong,
          ),
        );
      at = match.end;
    }
    return spans..add(TextSpan(text: hint.substring(at)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SmoothSize(
      duration: AppMotion.fast,
      curve: AppMotion.out,
      alignment: AlignmentDirectional.topStart,
      child: !open
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
              child: Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.info.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppIconView(
                            AppIcon.lightbulb,
                            size: _iconSize,
                            color: colors.info.fill,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: context.texts.body.copyWith(
                                  color: colors.info.text,
                                ),
                                children: _spans(context),
                              ),
                            ),
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
