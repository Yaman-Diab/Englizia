import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/presentation/concepts/cubit/concepts_cubit.dart';
import 'package:englizia/features/lessons/presentation/concepts/widgets/concept_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «مفاهيم للتقوية» (requirements v3.0 §11.2, design "Mistake Bank"): how a
/// concept is mastered, today's concepts by priority, those coming later and
/// those mastered. No total of mistakes anywhere, and nothing red.
class ConceptsPage extends StatelessWidget {
  const ConceptsPage({required this.onBack, required this.onStart, super.key});

  final VoidCallback onBack;

  /// Returns the concepts mastered in the session.
  final Future<Set<String>> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConceptsCubit>();
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: AppSizes.minTapTarget + AppSpacing.sm,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.xs,
                  end: AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      tooltip: 'common_back'.tr(),
                      color: colors.textPrimary,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'concept_title'.tr(),
                          style: context.texts.bodyStrong.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<ConceptsCubit, ConceptsState>(
                builder: (context, state) => switch (state.load) {
                  LoadStatus.loading => const AppStateView.loading(),
                  LoadStatus.failure => AppStateView.error(
                    message: state.failure!.localizedMessage,
                    onRetry: cubit.start,
                  ),
                  LoadStatus.ready => _List(
                    state: state,
                    onStart: () async {
                      final mastered = await onStart();
                      await cubit.returned(mastered: mastered);
                    },
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state, required this.onStart});

  final ConceptsState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<ConceptsCubit>();
    final bank = state.bank!;
    final due = bank.due;
    final fresh = due.isEmpty && bank.later.isEmpty && bank.mastered.isEmpty;
    final showsDue = due.isNotEmpty || state.leaving.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                child: Text(
                  'concept_how'.tr(),
                  style: texts.body.copyWith(color: colors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (showsDue) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(
                    'concept_due_today'.tr(),
                    style: texts.captionStrong.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final concept in due) ...[
                  _ConceptRow(concept: concept),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final concept in state.leaving)
                  _Leaving(
                    key: ValueKey('leaving:${concept.id}'),
                    onGone: cubit.left,
                    child: _ConceptRow(concept: concept),
                  ),
              ] else
                _Empty(fresh: fresh),
              if (!fresh) ...[
                const SizedBox(height: AppSpacing.lg),
                _Later(
                  later: bank.later,
                  open: state.laterOpen,
                  onToggle: cubit.toggleLater,
                ),
              ],
              if (bank.mastered.isNotEmpty)
                _MasteredRow(mastered: bank.mastered),
            ],
          ),
        ),
        if (due.isNotEmpty && state.leaving.isEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.scheme.outlineVariant),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.md,
              ),
              child: AppButton(
                label: 'concept_start'.tr(namedArgs: {'n': '${due.length}'}),
                size: AppButtonSize.large,
                onPressed: onStart,
              ),
            ),
          ),
      ],
    );
  }
}

class _ConceptRow extends StatelessWidget {
  const _ConceptRow({required this.concept});

  final Concept concept;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ConceptIcon(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concept.arabic,
                  style: texts.bodyStrong.copyWith(color: colors.textPrimary),
                ),
                Text(
                  concept.english,
                  textDirection: TextDirection.ltr,
                  locale: const Locale('en'),
                  style: texts.caption.copyWith(color: colors.textSecondary),
                ),
                if (concept.repeats > 1) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: AppSizes.iconSm - 2,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'concept_repeats'.plural(concept.repeats),
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
            child: StationDots(passed: concept.stations),
          ),
        ],
      ),
    );
  }
}

/// A concept mastered just now: it fades and sinks, then its room closes.
class _Leaving extends StatelessWidget {
  const _Leaving({required this.child, required this.onGone, super.key});

  final Widget child;
  final VoidCallback onGone;

  static const _wait = Duration(milliseconds: 250);
  static const _length = Duration(milliseconds: 520);
  static const _fadeShare = .6;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onGone());
      return const SizedBox.shrink();
    }
    return TimedValue(
      delay: _wait,
      duration: _length,
      curve: AppMotion.inOut,
      builder: (context, value) {
        if (value >= 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onGone());
        }
        final fade = (value / _fadeShare).clamp(0.0, 1.0);
        final close = ((value - _fadeShare) / (1 - _fadeShare)).clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            heightFactor: 1 - close,
            child: Opacity(
              opacity: 1 - fade,
              child: Transform.translate(
                offset: Offset(0, AppSpacing.xl * fade),
                child: Transform.scale(
                  scale: 1 - .04 * fade,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.sm,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.fresh});

  /// No concept yet at all.
  final bool fresh;

  static const _guide = 88.0;
  static const _textWidth = 270.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Mascot(
            expression: fresh
                ? MascotExpression.curious
                : MascotExpression.sleep,
            size: _guide,
            animate: false,
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _textWidth),
            child: Text(
              fresh ? 'concept_none_yet'.tr() : 'concept_none_today'.tr(),
              textAlign: TextAlign.center,
              style: (fresh ? texts.body : texts.bodyStrong).copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «لاحقًا · 2», folded, each with when it comes back.
class _Later extends StatelessWidget {
  const _Later({
    required this.later,
    required this.open,
    required this.onToggle,
  });

  final List<ConceptName> later;
  final bool open;
  final VoidCallback onToggle;

  static const _rowHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            onTap: onToggle,
            child: SizedBox(
              height: AppSizes.minTapTarget,
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: open ? .5 : 0,
                    duration: AppMotion.resolve(context, AppMotion.closeUp),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: AppSizes.iconMd - 4,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'concept_later'.tr(namedArgs: {'n': '${later.length}'}),
                    style: texts.captionStrong.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SmoothSize(
          alignment: AlignmentDirectional.topStart,
          child: !open
              ? const SizedBox(width: double.infinity)
              : Column(
                  children: [
                    for (final name in later)
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: _rowHeight,
                        ),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: context.scheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name.arabic,
                                style: texts.body.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            if (name.dueAt case final due?)
                              Text(
                                'concept_in'.tr(
                                  namedArgs: {
                                    'days': daysText(
                                      DateUtils.dateOnly(
                                        due,
                                      ).difference(today).inDays.clamp(1, 365),
                                    ),
                                  },
                                ),
                                style: texts.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// «أتقنت 7 مفاهيم», which lists them.
class _MasteredRow extends StatelessWidget {
  const _MasteredRow({required this.mastered});

  final List<ConceptName> mastered;

  static const _badge = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        sheetAnimationStyle: sheetAnimation(context),
        builder: (_) => _MasteredSheet(mastered: mastered),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _badge + AppSpacing.xl),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: _badge,
                height: _badge,
                decoration: BoxDecoration(
                  color: colors.success.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: AppSizes.iconSm,
                  color: colors.success.fill,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Expanded(
                child: Text(
                  'concept_mastered'.plural(mastered.length),
                  style: texts.bodyStrong.copyWith(color: colors.textPrimary),
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasteredSheet extends StatelessWidget {
  const _MasteredSheet({required this.mastered});

  final List<ConceptName> mastered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                'concept_mastered'.plural(mastered.length),
                style: texts.title.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final name in mastered)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: AppSizes.iconSm + AppSpacing.xxs,
                      color: colors.success.fill,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.arabic,
                            style: texts.body.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          if (name.english case final english?)
                            Text(
                              english,
                              textDirection: TextDirection.ltr,
                              style: texts.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
