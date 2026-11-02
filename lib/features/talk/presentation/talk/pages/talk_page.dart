import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/ai_spark.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/presentation/talk/cubit/talk_cubit.dart';
import 'package:englizia/features/talk/presentation/widgets/talk_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «تحدّث» (requirements v3.0 §8.6, design "Talk"): the scenarios by unit, with
/// what the learner did in each. A conversation changes them and today's
/// count, so the page reads them again on return.
class TalkPage extends StatelessWidget {
  const TalkPage({required this.onOpen, super.key});

  final Future<void> Function(ScenarioCard scenario) onOpen;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TalkCubit>();
    return SafeArea(
      bottom: false,
      child: BlocBuilder<TalkCubit, TalkState>(
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
              _Heading(home: state.home!),
              if (!state.online) ...[
                const SizedBox(height: AppSpacing.md),
                const _Offline(),
              ],
              for (final unit in state.home!.units) ...[
                const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                _Unit(
                  unit: unit,
                  state: state,
                  onOpen: (scenario) async {
                    await onOpen(scenario);
                    await cubit.refresh();
                  },
                ),
              ],
            ],
          ),
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.home});

  final TalkHome home;

  static const _quotaHeight = 30.0;

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
              'tab_talk'.tr(),
              style: texts.display.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'talk_subtitle'.tr(),
            style: texts.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: _quotaHeight,
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm + AppSpacing.xxs,
              0,
              AppSpacing.md,
              0,
            ),
            decoration: BoxDecoration(
              color: colors.ai.surface,
              borderRadius: BorderRadius.circular(_quotaHeight / 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AiSpark(size: 14),
                const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                Flexible(
                  child: Text(
                    'talk_quota'.tr(
                      namedArgs: {
                        'left': '${home.quotaLeft}',
                        'total': '${home.quotaTotal}',
                      },
                    ),
                    style: texts.captionStrong.copyWith(
                      color: colors.ai.text,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Offline, nothing starts: a conversation needs the internet (S §8.6).
class _Offline extends StatelessWidget {
  const _Offline();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md + AppSpacing.xxs,
          vertical: AppSpacing.sm + AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            AppIconView(
              AppIcon.wifiOff,
              size: AppSizes.iconMd - AppSpacing.xs,
              color: colors.info.fill,
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            Expanded(
              child: Text(
                'talk_offline'.tr(),
                style: context.texts.caption.copyWith(color: colors.info.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit({required this.unit, required this.state, required this.onOpen});

  final TalkUnit unit;
  final TalkState state;
  final ValueChanged<ScenarioCard> onOpen;

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              unit.title,
              style: texts.captionStrong.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ),
        for (final scenario in unit.scenarios) ...[
          const SizedBox(height: AppSpacing.sm),
          _ScenarioRow(
            scenario: scenario,
            enabled: state.canOpen(scenario),
            quotaOut: state.quotaOut,
            onTap: () => onOpen(scenario),
          ),
        ],
      ],
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({
    required this.scenario,
    required this.enabled,
    required this.quotaOut,
    required this.onTap,
  });

  final ScenarioCard scenario;
  final bool enabled;
  final bool quotaOut;
  final VoidCallback onTap;

  static const _avatar = 56.0;
  static const _lock = 22.0;
  static const _faded = .5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final unlock = scenario.unlockUnit;
    final waitsForTomorrow =
        quotaOut && scenario.kind == TalkKind.ai && unlock == null;
    final subtitle = unlock != null
        ? 'talk_unlocks'.tr(namedArgs: {'unit': '$unlock'})
        : 'talk_with'.tr(
            namedArgs: {
              'name': scenario.character.name,
              'tasks': 'talk_tasks'.plural(scenario.taskCount),
            },
          );
    return Opacity(
      opacity: unlock != null || waitsForTomorrow ? _faded : 1,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: unlock != null
            ? 'talk_locked'.tr(
                namedArgs: {'title': scenario.title, 'unit': '$unlock'},
              )
            : null,
        child: PressScale(
          enabled: enabled,
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: _avatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CharacterAvatar(
                            character: scenario.character,
                            size: _avatar,
                            kind: scenario.kind,
                          ),
                          if (unlock != null)
                            PositionedDirectional(
                              end: -AppSpacing.xxs,
                              bottom: -AppSpacing.xxs,
                              child: Container(
                                width: _lock,
                                height: _lock,
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.border),
                                ),
                                alignment: Alignment.center,
                                child: AppIconView(
                                  AppIcon.lock,
                                  size: AppSizes.iconSm * .75,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scenario.title,
                            style: texts.bodyStrong.copyWith(
                              color: colors.textPrimary,
                              fontSize: texts.body.fontSize! * .94,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                              fontSize: texts.caption.fontSize! * .92,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TalkKindBadge(kind: scenario.kind),
                          if (waitsForTomorrow) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _Tomorrow(),
                          ],
                        ],
                      ),
                    ),
                    if (unlock == null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _Status(scenario: scenario),
                    ],
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

class _Tomorrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Row(
      children: [
        AppIconView(
          AppIcon.clock,
          size: AppSizes.iconSm * .8,
          color: colors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'talk_quota_tomorrow'.tr(),
            style: texts.caption.copyWith(
              color: colors.textSecondary,
              fontSize: texts.caption.fontSize! * .92,
            ),
          ),
        ),
      ],
    );
  }
}

/// «جديد», what the learner did at best, or ✓ when every task was done. Never
/// by color alone: the words say it.
class _Status extends StatelessWidget {
  const _Status({required this.scenario});

  final ScenarioCard scenario;

  static const _height = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final style = texts.captionStrong.copyWith(
      fontSize: texts.caption.fontSize! * .92,
      height: 1,
    );
    final best = scenario.bestDone;
    if (best == null) {
      return Container(
        height: _height,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary.surface,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Text(
          'talk_new'.tr(),
          style: style.copyWith(color: colors.primary.text),
        ),
      );
    }
    final all = best >= scenario.taskCount;
    final ink = all ? colors.success.text : colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (all) ...[
          Icon(Icons.check_rounded, size: AppSizes.iconSm * .8, color: ink),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          'talk_done_of'.tr(
            namedArgs: {'done': '$best', 'total': '${scenario.taskCount}'},
          ),
          style: style.copyWith(color: ink),
        ),
      ],
    );
  }
}
