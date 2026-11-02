import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/services/review_schedule.dart';
import 'package:englizia/features/practice/presentation/practice/cubit/practice_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «تدرّب» (requirements v3.0 §10.1, design "Practice"): the word bank as the
/// biggest part, then concepts to strengthen and saved sentences to say. A
/// review or the list changes the bank, so the page reads it again on return.
class PracticePage extends StatelessWidget {
  const PracticePage({
    required this.onReview,
    required this.onWords,
    required this.onConcepts,
    required this.onSentences,
    super.key,
  });

  final Future<void> Function() onReview;
  final Future<void> Function() onWords;
  final Future<void> Function() onConcepts;
  final VoidCallback onSentences;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PracticeCubit>();
    Future<void> thenRefresh(Future<void> Function() open) async {
      await open();
      await cubit.refresh();
    }

    return SafeArea(
      bottom: false,
      child: BlocBuilder<PracticeCubit, PracticeState>(
        builder: (context, state) => switch (state.load) {
          LoadStatus.loading => const AppStateView.loading(),
          LoadStatus.failure => AppStateView.error(
            message: state.failure!.localizedMessage,
            onRetry: cubit.start,
          ),
          LoadStatus.ready => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              const _Heading(),
              const SizedBox(height: AppSpacing.lg),
              _BankCard(
                bank: state.bank!,
                due: state.due,
                onReview: () => thenRefresh(onReview),
                onWords: () => thenRefresh(onWords),
              ),
              const SizedBox(height: AppSpacing.lg),
              _MoreCard(
                bank: state.bank!,
                onConcepts: () => thenRefresh(onConcepts),
                onSentences: onSentences,
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'practice_title'.tr(),
              style: texts.display.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'practice_subtitle'.tr(),
            style: texts.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({
    required this.bank,
    required this.due,
    required this.onReview,
    required this.onWords,
  });

  final WordBank bank;
  final int due;
  final VoidCallback onReview;
  final VoidCallback onWords;

  static const _dot = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final count = bank.words.length;
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl - AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'practice_bank'.tr(),
                    style: texts.title.copyWith(color: colors.textPrimary),
                  ),
                ),
              ),
              Text(
                'practice_words_count'.plural(count),
                style: texts.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          if (count == 0)
            const _NewLearner()
          else ...[
            if (due > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Container(
                    width: _dot,
                    height: _dot,
                    decoration: BoxDecoration(
                      color: colors.primaryStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'practice_due'.plural(due),
                    style: texts.bodyStrong.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            StrengthChart(counts: boxCounts(bank)),
            const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
            if (due > 0)
              AppButton(
                label: 'practice_review'.tr(),
                size: AppButtonSize.large,
                onPressed: onReview,
              )
            else ...[
              _NothingDue(bank: bank),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'practice_review_anyway'.tr(),
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.large,
                onPressed: onReview,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: TextButton(
                onPressed: onWords,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('practice_all_words'.tr()),
                    const SizedBox(width: AppSpacing.xxs),
                    const _Chevron(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
    Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded,
    size: AppSizes.iconMd,
    color: color,
  );
}

/// The five boxes as columns, from a day's wait to a month's: the further right,
/// the firmer (S §10.1). Their heights move when a review changed them.
class StrengthChart extends StatelessWidget {
  const StrengthChart({required this.counts, super.key});

  final List<int> counts;

  static const _height = 96.0;
  static const _tallest = 64.0;
  static const _least = 6.0;

  /// From the lightest blue to the full one, box by box.
  static const _shades = [.18, .36, .56, .78, 1.0];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final small = texts.caption.copyWith(color: colors.textSecondary);
    final most = counts.fold<int>(1, (a, b) => a > b ? a : b);
    final appDirection = Directionality.of(context);
    final labels = [
      'practice_box_day'.tr(),
      'practice_box_days'.tr(),
      for (final days in boxDays.skip(2)) '$days',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('practice_strength'.tr(), style: small),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: 'practice_strength_said'.tr(
            namedArgs: {
              for (final (i, name) in const ['a', 'b', 'c', 'd', 'e'].indexed)
                name: '${counts[i]}',
            },
          ),
          excludeSemantics: true,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                SizedBox(
                  height: _height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (i, count) in counts.indexed) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '$count',
                                style: texts.captionStrong.copyWith(
                                  color: colors.textSecondary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              AnimatedContainer(
                                duration: AppMotion.resolve(
                                  context,
                                  AppMotion.slow,
                                ),
                                curve: AppMotion.smoothOut,
                                height: count == 0
                                    ? _least
                                    : (count / most * _tallest).clamp(
                                        _least,
                                        _tallest,
                                      ),
                                decoration: BoxDecoration(
                                  color: Color.lerp(
                                    colors.primary.surface,
                                    colors.primary.fill,
                                    _shades[i],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppSpacing.xs + 2),
                                    bottom: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (final (i, label) in labels.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          textDirection: appDirection,
                          maxLines: 1,
                          style: small,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              Icons.east_rounded,
              size: AppSizes.iconSm,
              color: colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
            Expanded(child: Text('practice_strength_hint'.tr(), style: small)),
          ],
        ),
      ],
    );
  }
}

/// Nothing due: the guide asleep, and when the next review comes.
class _NothingDue extends StatelessWidget {
  const _NothingDue({required this.bank});

  final WordBank bank;

  static const _guide = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final next = bank.words
        .map((word) => word.dueAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final now = DateTime.now();
    final days = DateTime(
      next.year,
      next.month,
      next.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Mascot(
            expression: MascotExpression.sleep,
            size: _guide,
            animate: false,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              days <= 1
                  ? 'practice_none_due'.tr()
                  : 'practice_none_due_in'.plural(days),
              style: context.texts.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// No words yet: the guide curious beside a star, and how words get here.
class _NewLearner extends StatelessWidget {
  const _NewLearner();

  static const _guide = 96.0;
  static const _star = 32.0;
  static const _textWidth = 260.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.md + AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Column(
        children: [
          SizedBox.square(
            dimension: _guide,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Mascot(
                  expression: MascotExpression.curious,
                  size: _guide,
                  animate: false,
                ),
                PositionedDirectional(
                  end: -AppSpacing.xs - 2,
                  top: AppSpacing.sm,
                  child: Container(
                    width: _star,
                    height: _star,
                    decoration: BoxDecoration(
                      color: colors.reward.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: AppSizes.iconSm + AppSpacing.xxs,
                      color: colors.reward.fill,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _textWidth),
            child: Text(
              'practice_new'.tr(),
              textAlign: TextAlign.center,
              style: context.texts.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Concepts to strengthen, while the panel has them on, and saved sentences.
class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.bank,
    required this.onConcepts,
    required this.onSentences,
  });

  final WordBank bank;
  final VoidCallback onConcepts;
  final VoidCallback onSentences;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final concepts = bank.conceptsDue;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          if (concepts != null) ...[
            _Row(
              icon: Icons.psychology_alt_outlined,
              tint: colors.background,
              ink: colors.textSecondary,
              title: 'practice_concepts'.plural(concepts),
              onTap: onConcepts,
            ),
            Divider(height: 1, color: context.scheme.outlineVariant),
          ],
          _Row(
            icon: Icons.record_voice_over_outlined,
            tint: colors.primary.surface,
            ink: colors.primary.fill,
            title: 'practice_sentences_title'.tr(),
            detail: 'practice_sentences'.plural(bank.savedSentences),
            onTap: onSentences,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String title;
  final String? detail;
  final VoidCallback onTap;

  static const _height = 68.0;
  static const _box = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final detail = this.detail;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _height),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: _box,
                height: _box,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: AppSizes.iconMd - 2, color: ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: texts.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              _Chevron(color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
