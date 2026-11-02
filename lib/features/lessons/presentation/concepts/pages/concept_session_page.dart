import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/hop_once.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/lesson_progress_bar.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/services/concept_stations.dart';
import 'package:englizia/features/lessons/presentation/concepts/cubit/concept_session_cubit.dart';
import 'package:englizia/features/lessons/presentation/concepts/widgets/concept_parts.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/exercise_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/feedback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Strengthening concepts (requirements v3.0 §11.2, design "Mistake Bank"): for
/// each, its card, a new question with the lessons' own feedback, and the
/// station it reached; then how the session went.
class ConceptSessionPage extends StatelessWidget {
  const ConceptSessionPage({
    required this.onExit,
    required this.onExplain,
    super.key,
  });

  /// Leaving, and «انتهيت»: with the concepts mastered.
  final ValueChanged<Set<String>> onExit;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConceptSessionCubit>();
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<ConceptSessionCubit, ConceptSessionState>(
          builder: (context, state) {
            final concept = state.concept;
            final total = state.concepts.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.stage != ConceptStage.done)
                  SizedBox(
                    height: AppSizes.minTapTarget + AppSpacing.sm,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.md,
                        end: AppSpacing.xl - AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => onExit(cubit.mastered),
                            tooltip: 'concept_end'.tr(),
                            color: colors.textSecondary,
                            icon: const Icon(Icons.close_rounded),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: LessonProgressBar(
                              position:
                                  state.index +
                                  (state.stage == ConceptStage.result ? 1 : 0),
                              total: total,
                              label: 'concept_progress'.tr(),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: AppSizes.minTapTarget - 4,
                            ),
                            child: Text(
                              'concept_counter'.tr(
                                namedArgs: {
                                  'at': '${state.index + 1}',
                                  'of': '$total',
                                },
                              ),
                              textAlign: TextAlign.end,
                              style: context.texts.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.resolve(context, AppMotion.fast),
                    switchInCurve: AppMotion.out,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: Offset(
                            Directionality.of(context) == TextDirection.rtl
                                ? .12
                                : -.12,
                            0,
                          ),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('${state.index}:${state.stage}'),
                      child: switch (state.stage) {
                        ConceptStage.card => _Card(
                          concept: concept!,
                          onTry: cubit.tryQuestion,
                        ),
                        ConceptStage.question => _Question(
                          state: state,
                          concept: concept!,
                          onExplain: onExplain,
                        ),
                        ConceptStage.result => _Result(
                          concept: concept!,
                          outcome: state.outcome!,
                          onNext: cubit.nextConcept,
                        ),
                        ConceptStage.done => _Done(
                          state: state,
                          onFinish: () => onExit(cubit.mastered),
                        ),
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The concept before its question: what it is, a right example, where the
/// learner went wrong, and the five stations.
class _Card extends StatelessWidget {
  const _Card({required this.concept, required this.onTry});

  final Concept concept;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final info = colors.info;
    final last = concept.lastRightAt;
    final wrong = concept.wrongAnswer;
    final from = concept.wrongFrom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (concept.stations > 0 && last != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: AppSizes.iconSm,
                        color: colors.success.fill,
                      ),
                      const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          'concept_right_before'.tr(
                            namedArgs: {
                              'days': daysText(
                                DateUtils.dateOnly(DateTime.now())
                                    .difference(DateUtils.dateOnly(last))
                                    .inDays
                                    .clamp(1, 365),
                              ),
                            },
                          ),
                          style: texts.caption.copyWith(
                            color: colors.success.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Container(
                  padding: const EdgeInsetsDirectional.all(
                    AppSpacing.xl - AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: info.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ConceptIcon(size: AppSizes.iconMd + 4),
                          const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    concept.arabic,
                                    style: texts.title.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  concept.english,
                                  textDirection: TextDirection.ltr,
                                  locale: const Locale('en'),
                                  style: texts.caption.copyWith(
                                    color: info.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        concept.why,
                        style: texts.body.copyWith(color: colors.textPrimary),
                      ),
                      if (concept.example.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.md + AppSpacing.xxs,
                            vertical: AppSpacing.sm + AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: AppSizes.iconSm + AppSpacing.xxs,
                                  color: colors.success.fill,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text.rich(
                                    locale: const Locale('en'),
                                    TextSpan(
                                      style: texts.body.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: texts.title.fontSize! - 4,
                                      ),
                                      children: [
                                        for (final part in concept.example)
                                          TextSpan(
                                            text: part.text,
                                            style: part.strong
                                                ? TextStyle(
                                                    fontFamily: texts
                                                        .bodyStrong
                                                        .fontFamily,
                                                  )
                                                : null,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (wrong != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'concept_where_wrong'.tr(),
                          style: texts.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Semantics(
                          label: 'concept_wrong_said'.tr(
                            namedArgs: {'answer': wrong},
                          ),
                          excludeSemantics: true,
                          child: Text(
                            wrong,
                            textDirection: TextDirection.ltr,
                            locale: const Locale('en'),
                            style: texts.body.copyWith(
                              color: colors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                              decorationThickness: 1.5,
                            ),
                          ),
                        ),
                        if (from != null)
                          Text(
                            'concept_from'.tr(namedArgs: {'title': from}),
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.sm + AppSpacing.xxs,
                    AppSpacing.md + AppSpacing.xxs,
                    AppSpacing.sm + AppSpacing.xxs,
                    AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.xs + 2,
                        ),
                        child: Text(
                          'concept_station_of'.tr(
                            namedArgs: {'n': '${concept.stations + 1}'},
                          ),
                          style: texts.captionStrong.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                      StationTrack(passed: concept.stations),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.md,
          ),
          child: AppButton(
            label: 'concept_try'.tr(),
            size: AppButtonSize.large,
            onPressed: onTry,
          ),
        ),
      ],
    );
  }
}

/// The new question, in the lessons' own body and feedback, the concept's chip
/// over its instruction.
class _Question extends StatelessWidget {
  const _Question({
    required this.state,
    required this.concept,
    required this.onExplain,
  });

  final ConceptSessionState state;
  final Concept concept;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<ConceptSessionCubit>();
    final question = concept.question!;
    final evaluation = state.evaluation;
    final clip = BodyClip(
      status: state.audio,
      slow: state.slow,
      length: state.clipLength,
      playCount: state.playCount,
      onToggle: cubit.togglePlay,
      onSlow: cubit.playSlow,
      onStop: cubit.stopAudio,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConceptChip(name: concept.arabic),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text(
                    question.instruction,
                    textDirection: TextDirection.rtl,
                    style: context.texts.bodyStrong.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                exerciseBody(
                  question,
                  BodyAnswer(
                    draft: state.draft,
                    evaluation: evaluation,
                    onDraft: cubit.updateDraft,
                    onSubmit: cubit.check,
                  ),
                  clip,
                  onSkipSpeech: cubit.skip,
                ),
              ],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: AppMotion.resolve(context, AppMotion.quick),
          child: evaluation != null
              ? FeedbackSheet(
                  key: ValueKey('feedback:${question.id}'),
                  exercise: question,
                  evaluation: evaluation,
                  draft: state.draft,
                  hinted: false,
                  xp: null,
                  explainEnabled: concept.explainEnabled,
                  clip: FeedbackClip(
                    playing: state.audio == ClipStatus.playing,
                    onToggle: cubit.toggleAnswerClip,
                  ),
                  onNext: cubit.answered,
                  onExplain: onExplain,
                  onReport: cubit.report,
                  onRetry: cubit.retry,
                  onSkip: cubit.skip,
                )
              : question.checksItself
              ? const SizedBox.shrink()
              : Padding(
                  key: const ValueKey('check'),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: AppButton(
                    label: 'lesson_check'.tr(),
                    size: AppButtonSize.large,
                    onPressed: state.canCheck ? cubit.check : null,
                  ),
                ),
        ),
      ],
    );
  }
}

/// What the answer did: a station passed, the concept mastered, or a step back
/// with nothing red.
class _Result extends StatelessWidget {
  const _Result({
    required this.concept,
    required this.outcome,
    required this.onNext,
  });

  final Concept concept;
  final ConceptOutcome outcome;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final wait = outcome.wait;
    final (String title, String? detail) = switch (outcome.kind) {
      OutcomeKind.mastered => ('concept_mastered_one'.tr(), null),
      OutcomeKind.step => (
        'concept_well_done'.tr(),
        'concept_next_station'.tr(namedArgs: {'days': daysText(wait!)}),
      ),
      OutcomeKind.again when outcome.startsOver => (
        'concept_start_over'.tr(),
        'concept_start_over_detail'.tr(),
      ),
      OutcomeKind.again => (
        'concept_back_in'.tr(namedArgs: {'days': daysText(wait!)}),
        'concept_back_detail'.tr(),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              child: Column(
                children: [
                  if (outcome.kind == OutcomeKind.mastered)
                    _Mastered(name: concept.arabic)
                  else
                    _StationsMoving(outcome: outcome),
                  const SizedBox(height: AppSpacing.xl),
                  if (outcome.kind != OutcomeKind.mastered)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: texts.title.copyWith(color: colors.textPrimary),
                      ),
                    ),
                  if (detail != null) ...[
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: texts.body.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.md,
          ),
          child: AppButton(
            label: 'concept_next'.tr(),
            size: AppButtonSize.large,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

/// The track as it was, then as the answer left it: the line grows to the
/// station passed, or goes back.
class _StationsMoving extends StatelessWidget {
  const _StationsMoving({required this.outcome});

  final ConceptOutcome outcome;

  static const _after = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) => TimedValue(
    delay: _after,
    duration: AppMotion.micro,
    builder: (context, value) =>
        StationTrack(passed: value < 1 ? outcome.from : outcome.to),
  );
}

/// The badge grows, its check is drawn, then the guide jumps; the concept's
/// name under it with a star.
class _Mastered extends StatelessWidget {
  const _Mastered({required this.name});

  final String name;

  static const _halo = 180.0;
  static const _guide = 120.0;
  static const _badge = 48.0;
  static const _badgeAt = Duration(milliseconds: 150);
  static const _checkAt = Duration(milliseconds: 380);
  static const _hopAt = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final reduce = AppMotion.reduceMotion(context);
    return Column(
      children: [
        SizedBox.square(
          dimension: _halo,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.success.surface,
                  shape: BoxShape.circle,
                ),
              ),
              const Center(
                child: HopOnce(
                  delay: _hopAt,
                  child: Mascot(
                    expression: MascotExpression.happy,
                    size: _guide,
                    animate: false,
                  ),
                ),
              ),
              PositionedDirectional(
                end: AppSpacing.xs + 2,
                bottom: AppSpacing.xs + 2,
                child: TimedValue(
                  delay: _badgeAt,
                  duration: AppMotion.fast,
                  curve: AppMotion.overshoot,
                  builder: (context, grow) => Opacity(
                    opacity: reduce ? 1 : grow.clamp(0, 1),
                    child: Transform.scale(
                      scale: reduce ? 1 : .6 + .4 * grow,
                      child: Container(
                        width: _badge,
                        height: _badge,
                        decoration: BoxDecoration(
                          color: colors.success.fill,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.background,
                            width: 4,
                          ),
                        ),
                        child: TimedValue(
                          delay: _checkAt,
                          duration: AppMotion.sheetIn,
                          builder: (context, drawn) => ClipRect(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: reduce ? 1 : drawn,
                              child: Icon(
                                Icons.check_rounded,
                                size: AppSizes.iconMd,
                                color: colors.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: AppSpacing.md,
                top: AppSpacing.lg,
                child: Icon(
                  Icons.star_rounded,
                  size: AppSizes.iconMd,
                  color: colors.reward.fill,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          liveRegion: true,
          child: Text(
            'concept_mastered_one'.tr(),
            textAlign: TextAlign.center,
            style: texts.title.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.info.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            name,
            style: texts.captionStrong.copyWith(color: colors.info.text),
          ),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.state, required this.onFinish});

  final ConceptSessionState state;
  final VoidCallback onFinish;

  static const _guide = 120.0;
  static const _rowHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    Widget row(IconData icon, Color ink, String text, {bool strong = false}) =>
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowHeight),
          child: Row(
            children: [
              Icon(icon, size: AppSizes.iconMd - 4, color: ink),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Expanded(
                child: Text(
                  text,
                  style: (strong ? texts.bodyStrong : texts.body).copyWith(
                    color: strong ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
    final divider = Divider(height: 1, color: context.scheme.outlineVariant);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Entrance(
            motion: EntranceMotion.up,
            delay: Duration.zero,
            child: Mascot(
              expression: MascotExpression.happy,
              size: _guide,
              animate: false,
            ),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              'concept_done'.plural(state.outcomes.length),
              textAlign: TextAlign.center,
              style: texts.title.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                row(
                  Icons.workspace_premium_outlined,
                  colors.success.fill,
                  'concept_done_mastered'.tr(
                    namedArgs: {'n': '${state.count(OutcomeKind.mastered)}'},
                  ),
                  strong: true,
                ),
                divider,
                row(
                  Icons.north_rounded,
                  colors.primary.fill,
                  'concept_done_step'.tr(
                    namedArgs: {'n': '${state.count(OutcomeKind.step)}'},
                  ),
                ),
                divider,
                row(
                  Icons.replay_rounded,
                  colors.textSecondary,
                  'concept_done_again'.tr(
                    namedArgs: {'n': '${state.count(OutcomeKind.again)}'},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'concept_finish'.tr(),
            size: AppButtonSize.large,
            onPressed: onFinish,
          ),
        ],
      ),
    );
  }
}
