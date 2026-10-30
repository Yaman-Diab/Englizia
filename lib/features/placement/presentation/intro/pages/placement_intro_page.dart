import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/design_system/widgets/notice_card.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/presentation/intro/cubit/placement_intro_cubit.dart';
import 'package:englizia/features/placement/presentation/intro/widgets/listening_motion.dart';
import 'package:englizia/features/placement/presentation/widgets/guide_circle.dart';
import 'package:englizia/features/placement/presentation/widgets/scroll_edge_column.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The placement test's intro (requirements v3.0 §12.2, design "Placement
/// Intro"): what the test takes, a sound check that needs no connection, and
/// where the learner stands: a first test, one left unfinished, a retake open
/// or not yet. Offline is not the learner's mistake, so it uses no error
/// colors, and the button comes back by itself with the connection.
class PlacementIntroPage extends StatefulWidget {
  const PlacementIntroPage({
    required this.onBack,
    required this.onStart,
    required this.onSkip,
    required this.onLessons,
    super.key,
  });

  final VoidCallback onBack;

  /// Opens the questions, and completes when the learner comes back.
  final Future<void> Function() onStart;

  /// The test was put off: on to the lessons, from the first level.
  final VoidCallback onSkip;

  /// A learner with a result already goes back to the lessons.
  final VoidCallback onLessons;

  @override
  State<PlacementIntroPage> createState() => _PlacementIntroPageState();
}

class _PlacementIntroPageState extends State<PlacementIntroPage> {
  static const _topBarHeight = 56.0;
  static const _subtitleMaxWidth = 300.0;

  /// Opens the questions; what they changed shows on the way back.
  Future<void> _start() async {
    final cubit = context.read<PlacementIntroCubit>();
    await widget.onStart();
    if (mounted) await cubit.load();
  }

  Future<void> _onDone(PlacementAction action) async {
    switch (action) {
      case PlacementAction.skip:
        widget.onSkip();
      case PlacementAction.restart:
        final cubit = context.read<PlacementIntroCubit>();
        await widget.onStart();
        if (mounted) await cubit.reopened();
    }
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<PlacementIntroCubit, PlacementIntroState>(
        listenWhen: (before, now) =>
            now.done != null && now.done != before.done,
        listener: (_, state) => _onDone(state.done!),
      ),
      BlocListener<PlacementIntroCubit, PlacementIntroState>(
        listenWhen: (before, now) =>
            now.actionFailure != null &&
            now.actionFailure != before.actionFailure,
        listener: (context, state) => showFailureSnackBar(
          context,
          state.actionFailure!,
          onRetry: context.read<PlacementIntroCubit>().retryAction,
        ),
      ),
    ],
    child: BlocBuilder<PlacementIntroCubit, PlacementIntroState>(
      builder: _build,
    ),
  );

  Widget _build(BuildContext context, PlacementIntroState state) {
    final cubit = context.read<PlacementIntroCubit>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.busy) widget.onBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: _topBarHeight,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      onPressed: state.busy ? null : widget.onBack,
                      tooltip: 'common_back'.tr(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: switch (state.load) {
                  LoadStatus.loading => const AppStateView.loading(),
                  LoadStatus.failure => AppStateView.error(
                    message: state.failure!.localizedMessage,
                    onRetry: cubit.load,
                  ),
                  _ => ScrollEdgeColumn(
                    body: _body(context, state),
                    footer: _footer(context, state),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PlacementIntroState state) {
    final colors = context.colors;
    final texts = context.texts;
    final status = state.status;
    final summary = state.summary;
    final again =
        status is PlacementRetakeOpen || status is PlacementRetakeLocked;
    final facts = [
      if (summary != null) ...[
        (AppIcon.clock, _minutes(summary)),
        (AppIcon.steps, _stages(summary)),
      ],
      (AppIcon.questionCircle, 'placement_dont_guess'.tr()),
      (AppIcon.pauseCircle, 'placement_can_pause'.tr()),
    ];
    final notice = switch (status) {
      PlacementInProgress(:final stage, :final question) => NoticeCard(
        icon: AppIcon.bookmark,
        primary: true,
        title: _unfinished(stage, question),
      ),
      PlacementRetakeOpen(:final level, :final daysAgo) => NoticeCard(
        icon: AppIcon.steps,
        primary: true,
        emphasis: '${Unicode.LRI}$level${Unicode.PDI}',
        title: 'placement_last_result'.plural(
          daysAgo,
          namedArgs: {'level': '${Unicode.LRI}$level${Unicode.PDI}'},
        ),
      ),
      PlacementRetakeLocked(:final daysLeft) => NoticeCard(
        icon: AppIcon.calendar,
        title: 'placement_retake_after'.plural(daysLeft),
      ),
      _ => null,
    };
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Entrance(
            motion: EntranceMotion.pop,
            delay: FormEntrance.header,
            child: GuideCircle(
              child: ListeningNod(
                active: state.trying,
                child: const Mascot(
                  expression: MascotExpression.listen,
                  prop: MascotProp.headphones,
                  size: GuideCircle.guideSize,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Entrance(
            motion: EntranceMotion.up,
            delay: FormEntrance.header,
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'placement_intro_title'.tr(),
                    textAlign: TextAlign.center,
                    style: texts.title.copyWith(color: colors.textPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _subtitleMaxWidth,
                  ),
                  child: Text(
                    again
                        ? 'placement_intro_subtitle_again'.tr()
                        : 'placement_intro_subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: texts.body.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          if (notice != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              motion: EntranceMotion.up,
              delay: FormEntrance.field(0),
              child: notice,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (final (i, (icon, text)) in facts.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg - AppSpacing.xxs),
            Entrance(
              motion: EntranceMotion.up,
              delay: FormEntrance.field(i),
              child: _Fact(icon: icon, text: text),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Entrance(
            motion: EntranceMotion.up,
            delay: FormEntrance.action,
            child: _SoundCheck(trying: state.trying),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, PlacementIntroState state) {
    final status = state.status;
    final levelName = state.firstLevel?.name.of(context.locale.languageCode);
    final start = switch (status) {
      PlacementInProgress() => 'placement_continue'.tr(),
      PlacementRetakeOpen() ||
      PlacementRetakeLocked() => 'placement_retake'.tr(),
      _ => 'preparing_start_test'.tr(),
    };
    final cubit = context.read<PlacementIntroCubit>();
    final (other, onOther) = switch (status) {
      PlacementInProgress() => (
        'placement_restart'.tr(),
        state.canRestart ? cubit.restart : null,
      ),
      PlacementRetakeOpen() || PlacementRetakeLocked() => (
        'placement_back_to_lessons'.tr(),
        state.busy ? null : widget.onLessons,
      ),
      PlacementNotTaken() => (
        levelName == null
            ? 'placement_skip_plain'.tr()
            : 'placement_skip'.tr(
                namedArgs: {'level': '${Unicode.LRI}$levelName${Unicode.PDI}'},
              ),
        state.busy ? null : cubit.skip,
      ),
      // Nothing to offer a learner who may already have a result.
      null => (null, null),
    };
    final band = !state.online
        ? 'placement_offline'.tr()
        : state.testUnavailable
        ? 'onboarding_level_test_unavailable'.tr()
        : null;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: AnimatedSize(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.smoothOut,
        alignment: AlignmentDirectional.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (band != null) ...[
              NoticeCard(icon: AppIcon.wifiOff, title: band),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: start,
              size: AppButtonSize.large,
              onPressed: state.canStart ? _start : null,
            ),
            if (other != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              TextButton(
                onPressed: onOther,
                child: ButtonLoadingLabel(
                  isLoading: state.running != null,
                  spinnerSize: AppSpinner.compactSize,
                  child: Text(other),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _minutes(PlacementSummary summary) =>
      'placement_minutes'.plural(
        summary.maxMinutes,
        namedArgs: {
          'min': '${summary.minMinutes}',
          'max': '${summary.maxMinutes}',
        },
      );

  static String _stages(PlacementSummary summary) => summary.mayAddStage
      ? 'onboarding_level_stages_optional'.plural(summary.stages)
      : 'onboarding_level_stages'.plural(summary.stages);

  static String _unfinished(int stage, int question) {
    final args = {'question': '$question'};
    return switch (stage) {
      1 => 'placement_unfinished_stage_1'.tr(namedArgs: args),
      2 => 'placement_unfinished_stage_2'.tr(namedArgs: args),
      _ => 'placement_unfinished_stage_3'.tr(namedArgs: args),
    };
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final AppIcon icon;
  final String text;

  static const _badge = 40.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: _badge,
          height: _badge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.surface,
            shape: BoxShape.circle,
          ),
          child: AppIconView(icon, size: _iconSize, color: colors.primary.fill),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: context.texts.body.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Tries the sound with a sentence bundled in the app, so it works offline.
class _SoundCheck extends StatelessWidget {
  const _SoundCheck({required this.trying});

  final bool trying;

  static const _iconSize = 22.0;
  static const _button = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.info.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            AppIconView(
              AppIcon.headphones,
              size: _iconSize,
              color: colors.info.fill,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  trying
                      ? 'placement_sound_hear'.tr()
                      : 'placement_sound_try'.tr(),
                  style: context.texts.bodyStrong.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox.square(
              dimension: _button,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ListeningWaves(active: trying, size: _button),
                  IconButton(
                    onPressed: context.read<PlacementIntroCubit>().toggleTrial,
                    tooltip: trying
                        ? 'placement_sound_stop'.tr()
                        : 'placement_sound_play'.tr(),
                    isSelected: trying,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.info.fill,
                      foregroundColor: colors.surface,
                      fixedSize: const Size.square(_button),
                    ),
                    icon: Icon(
                      trying ? Icons.stop_rounded : Icons.play_arrow_rounded,
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
