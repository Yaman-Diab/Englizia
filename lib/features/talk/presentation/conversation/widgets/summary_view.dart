import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/ai_dots.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/presentation/conversation/cubit/conversation_cubit.dart';
import 'package:englizia/features/talk/presentation/conversation/widgets/chat_parts.dart';
import 'package:englizia/features/talk/presentation/widgets/talk_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A conversation's summary (requirements v3.0 §8.6, design "Talk Summary"):
/// the tasks done, which never wait for the notes, then an AI conversation's
/// better ways to say up to three lines, and the whole conversation to read.
class SummaryView extends StatefulWidget {
  const SummaryView({required this.onDone, super.key});

  /// «انتهيت».
  final VoidCallback onDone;

  @override
  State<SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends State<SummaryView> {
  var _full = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConversationCubit>();
    return PopScope(
      canPop: !_full,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _full = false);
      },
      child: BlocBuilder<ConversationCubit, ConversationState>(
        builder: (context, state) => _full
            ? TranscriptView(
                state: state,
                onBack: () => setState(() => _full = false),
                onPlay: cubit.playBetter,
              )
            : _Summary(
                state: state,
                onFull: () => setState(() => _full = true),
                onPlay: cubit.playBetter,
                onRetry: cubit.restart,
                onDone: widget.onDone,
              ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.state,
    required this.onFull,
    required this.onPlay,
    required this.onRetry,
    required this.onDone,
  });

  final ConversationState state;
  final VoidCallback onFull;
  final ValueChanged<BetterSaying> onPlay;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  static const _avatar = 72.0;
  static const _guide = 56.0;
  static const _ring = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final scenario = state.scenario!;
    final notes = state.notes;
    final clear = notes?.status == NotesStatus.ready && notes!.notes.isEmpty;
    final retry = AppButton(
      label: 'talk_retry'.tr(),
      onPressed: onRetry,
      variant: state.allDone
          ? AppButtonVariant.secondary
          : AppButtonVariant.primary,
      size: AppButtonSize.large,
    );
    final done = AppButton(
      label: 'talk_finished'.tr(),
      onPressed: onDone,
      variant: state.allDone
          ? AppButtonVariant.primary
          : AppButtonVariant.secondary,
      size: AppButtonSize.large,
    );
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.xxl - AppSpacing.xs,
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.xl - AppSpacing.xs,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.background,
                              spreadRadius: _ring,
                            ),
                          ],
                        ),
                        child: CharacterAvatar(
                          character: scenario.character,
                          size: _avatar,
                          kind: scenario.kind,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(
                          Directionality.of(context) == TextDirection.rtl
                              ? AppSpacing.xs + AppSpacing.xxs
                              : -(AppSpacing.xs + AppSpacing.xxs),
                          0,
                        ),
                        child: const Mascot(
                          expression: MascotExpression.happy,
                          size: _guide,
                          animate: false,
                          sparkles: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  Semantics(
                    header: true,
                    child: Text(
                      'talk_summary_title'.tr(
                        namedArgs: {'name': scenario.character.name},
                      ),
                      textAlign: TextAlign.center,
                      style: texts.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Tasks(state: state),
                  if (notes != null && !clear) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _Notes(
                      notes: notes,
                      taskCount: scenario.tasks.length,
                      onPlay: onPlay,
                    ),
                  ],
                  if (clear) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const _AllClear(),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: onFull,
                      iconAlignment: IconAlignment.end,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, AppSizes.minTapTarget),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        foregroundColor: colors.primary.text,
                        textStyle: texts.bodyStrong.copyWith(
                          fontSize: texts.body.fontSize! * .94,
                        ),
                      ),
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: AppSizes.iconMd - AppSpacing.xs,
                      ),
                      label: Text('talk_show_full'.tr()),
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(
                  top: BorderSide(color: context.scheme.outlineVariant),
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.sm,
                ),
                // What is left to do leads: another try, or done.
                child: Row(
                  children: [
                    Expanded(child: state.allDone ? done : retry),
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                    Expanded(child: state.allDone ? retry : done),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «مهامك», each marked in turn as the summary arrives.
class _Tasks extends StatelessWidget {
  const _Tasks({required this.state});

  final ConversationState state;

  static const _circle = 24.0;
  static const _rowHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final tasks = state.scenario!.tasks;
    final reduce = AppMotion.reduceMotion(context);
    final heading = texts.bodyStrong.copyWith(
      color: colors.textPrimary,
      fontSize: texts.body.fontSize! * .94,
    );
    var marked = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('talk_your_tasks'.tr(), style: heading),
              ),
            ),
            Text(
              'talk_done_of'.tr(
                namedArgs: {
                  'done': '${state.tasksDone.length}',
                  'total': '${tasks.length}',
                },
              ),
              style: heading,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              for (final (index, task) in tasks.indexed) ...[
                if (index > 0)
                  Divider(height: 1, color: context.scheme.outlineVariant),
                Semantics(
                  label: state.tasksDone.contains(task.id)
                      ? 'talk_task_done'.tr(namedArgs: {'task': task.text})
                      : 'talk_task_open'.tr(namedArgs: {'task': task.text}),
                  excludeSemantics: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: _rowHeight),
                    child: Row(
                      children: [
                        _mark(
                          context,
                          done: state.tasksDone.contains(task.id),
                          order: state.tasksDone.contains(task.id)
                              ? marked++
                              : 0,
                          animate: !reduce,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            task.text,
                            style: texts.body.copyWith(
                              fontSize: texts.body.fontSize! * .94,
                              height: 22 / 15,
                              color: state.tasksDone.contains(task.id)
                                  ? colors.textPrimary
                                  : colors.textSecondary,
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
      ],
    );
  }

  Widget _mark(
    BuildContext context, {
    required bool done,
    required int order,
    required bool animate,
  }) {
    final colors = context.colors;
    final ring = Container(
      width: _circle,
      height: _circle,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.border, width: 1.5),
      ),
    );
    if (!done) return ring;
    final fill = Container(
      width: _circle,
      height: _circle,
      decoration: BoxDecoration(
        color: colors.success.fill,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        size: AppSizes.iconSm * .875,
        color: colors.onPrimaryStrong,
      ),
    );
    return Stack(
      children: [
        ring,
        if (animate)
          fill.animate().scaleXY(
            begin: 0,
            end: 1,
            delay: summaryMarkDelay(order),
            duration: AppMotion.taskPop,
            curve: AppMotion.overshoot,
          )
        else
          fill,
      ],
    );
  }
}

/// When the [order]-th done task is marked: one after another.
Duration summaryMarkDelay(int order) =>
    AppMotion.fast + AppMotion.summaryMarkStep * order;

/// «لتقول أفضل»: what the AI noticed, or that it is still coming.
class _Notes extends StatelessWidget {
  const _Notes({
    required this.notes,
    required this.taskCount,
    required this.onPlay,
  });

  final TalkNotes notes;
  final int taskCount;
  final ValueChanged<BetterSaying> onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Semantics(
      container: true,
      label: 'talk_better'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AiSpark(size: 14),
              const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
              Semantics(
                header: true,
                child: Text(
                  'talk_better'.tr(),
                  style: texts.bodyStrong.copyWith(
                    color: colors.ai.text,
                    fontSize: texts.body.fontSize! * .94,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          AnimatedSwitcher(
            duration: AppMotion.resolve(context, AppMotion.medium),
            child: switch (notes.status) {
              NotesStatus.pending => const _Pending(),
              NotesStatus.failed => const _Later(),
              NotesStatus.ready => _Cards(
                notes: notes.notes,
                after: summaryMarkDelay(taskCount) + AppMotion.fast,
                onPlay: onPlay,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({
    required this.notes,
    required this.after,
    required this.onPlay,
  });

  final List<BetterSaying> notes;

  /// They fade in once the tasks are marked.
  final Duration after;
  final ValueChanged<BetterSaying> onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final note in notes) ...[
          BetterCard(note: note, onPlay: () => onPlay(note)),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
        ],
        Row(
          children: [
            AppIconView(
              AppIcon.bookmarkAdd,
              size: AppSizes.iconSm,
              color: colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'talk_added_concepts'.tr(),
                style: context.texts.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    if (AppMotion.reduceMotion(context)) return cards;
    return cards.animate().fadeIn(
      delay: after,
      duration: AppMotion.medium,
      curve: AppMotion.out,
    );
  }
}

/// A line the learner said, struck through, and its better form with the
/// corrected part underlined, its voice and its concept.
class BetterCard extends StatelessWidget {
  const BetterCard({required this.note, required this.onPlay, super.key});

  final BetterSaying note;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md + AppSpacing.xxs,
        AppSpacing.md + AppSpacing.xxs,
        AppSpacing.md + AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.ai.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'talk_you_said'.tr(namedArgs: {'text': note.said}),
            excludeSemantics: true,
            child: Text(
              note.said,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              style: texts.body.copyWith(
                color: colors.textSecondary,
                fontSize: texts.body.fontSize! * .94,
                height: 24 / 15,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          BetterLine(note: note, onPlay: onPlay),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConceptTag(name: note.concept),
          ),
        ],
      ),
    );
  }
}

/// The better form, its corrected part underlined, with its voice.
class BetterLine extends StatelessWidget {
  const BetterLine({
    required this.note,
    required this.onPlay,
    this.small = false,
    super.key,
  });

  final BetterSaying note;
  final VoidCallback onPlay;

  /// The whole conversation's, a little smaller than the summary's.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final style = texts.bodyStrong.copyWith(
      color: colors.textPrimary,
      fontSize: small ? texts.body.fontSize! * .94 : null,
      height: small ? 24 / 15 : null,
    );
    final speaker = small ? 36.0 : 40.0;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: note.before),
                  TextSpan(
                    text: note.fix,
                    style: style.copyWith(
                      decoration: TextDecoration.underline,
                      decorationThickness: 2,
                      decorationColor: colors.textPrimary,
                    ),
                  ),
                  TextSpan(text: note.after),
                ],
              ),
              style: style,
            ),
          ),
          if (note.audioUrl != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: onPlay,
              tooltip: 'talk_listen_better'.tr(),
              style: IconButton.styleFrom(
                fixedSize: Size.square(speaker),
                minimumSize: Size.square(speaker),
                backgroundColor: colors.info.fill,
                foregroundColor: colors.surface,
              ),
              iconSize: small ? AppSizes.iconSm : AppSizes.iconSm + 2,
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

/// The concept a better form is about, now among the concepts to strengthen.
class ConceptTag extends StatelessWidget {
  const ConceptTag({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xxs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.info.surface,
        borderRadius: BorderRadius.circular(AppRadius.md + AppSpacing.xxs),
      ),
      child: Text(
        name,
        style: texts.captionStrong.copyWith(
          color: colors.info.text,
          fontSize: texts.caption.fontSize! * .92,
          height: 18 / 12,
        ),
      ),
    );
  }
}

/// «نجهّز ملاحظاتك…»: the tasks never wait for this.
class _Pending extends StatelessWidget {
  const _Pending();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.ai.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const AiDots(dot: 8),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'talk_notes_pending'.tr(),
              style: context.texts.body.copyWith(
                color: context.colors.textPrimary,
                fontSize: context.texts.body.fontSize! * .94,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The notes couldn't be made: information, not an error, as the learner did
/// nothing wrong.
class _Later extends StatelessWidget {
  const _Later();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
              child: AppIconView(
                AppIcon.infoCircle,
                size: AppSizes.iconMd - AppSpacing.xs,
                color: colors.info.fill,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            Expanded(
              child: Text(
                'talk_notes_later'.tr(),
                style: context.texts.caption.copyWith(
                  color: colors.info.text,
                  fontSize: context.texts.body.fontSize! * .875,
                  height: 22 / 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing to say better.
class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md + AppSpacing.xxs,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.success.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: AppSizes.iconMd - AppSpacing.xxs,
              color: colors.success.fill,
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            Expanded(
              child: Text(
                'talk_all_clear'.tr(),
                style: context.texts.captionStrong.copyWith(
                  color: colors.success.text,
                  fontSize: context.texts.body.fontSize! * .875,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The whole conversation, to read: a line with a note is dotted, and opens
/// its better form.
class TranscriptView extends StatefulWidget {
  const TranscriptView({
    required this.state,
    required this.onBack,
    required this.onPlay,
    super.key,
  });

  final ConversationState state;
  final VoidCallback onBack;
  final ValueChanged<BetterSaying> onPlay;

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  /// The learner's lines opened, by their turn.
  final _open = <int>{};

  static const _bar = 56.0;
  static const _bubbleShare = .84;
  static const _mineShare = .88;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final state = widget.state;
    final scenario = state.scenario!;
    final ai = scenario.kind == TalkKind.ai;
    final notes = {
      for (final note in state.notes?.notes ?? const <BetterSaying>[])
        note.turn: note,
    };
    var turn = 0;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: _bar,
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xs,
                end: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    tooltip: 'common_back'.tr(),
                    color: colors.textPrimary,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'talk_full_title'.tr(),
                            style: texts.bodyStrong.copyWith(
                              color: colors.textPrimary,
                              height: 22 / 16,
                            ),
                          ),
                        ),
                        Text(
                          'talk_full_with'.tr(
                            namedArgs: {'name': scenario.character.name},
                          ),
                          style: texts.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: texts.caption.fontSize! * .92,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth - 2 * AppSpacing.lg;
                  return ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xl - AppSpacing.xs,
                    ),
                    children: [
                      if (ai && notes.isNotEmpty) ...[
                        const _DottedHint(),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      for (final (index, message)
                          in state.messages.indexed) ...[
                        if (index > 0) const SizedBox(height: AppSpacing.md),
                        if (message.mine)
                          _mine(
                            context,
                            message,
                            notes[turn],
                            turn++,
                            width * _mineShare,
                          )
                        else
                          _character(
                            context,
                            message,
                            scenario,
                            width * _bubbleShare,
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _character(
    BuildContext context,
    TalkMessage message,
    Scenario scenario,
    double maxWidth,
  ) {
    final colors = context.colors;
    final ai = scenario.kind == TalkKind.ai;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterAvatar(
              character: scenario.character,
              size: 28,
              kind: scenario.kind,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Container(
                padding: bubblePadding,
                decoration: BoxDecoration(
                  color: ai ? colors.ai.surface : colors.surface,
                  border: ai ? null : Border.all(color: colors.border),
                  borderRadius: characterCorners,
                ),
                child: _english(context, message.line.english),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mine(
    BuildContext context,
    TalkMessage message,
    BetterSaying? note,
    int turn,
    double maxWidth,
  ) {
    final colors = context.colors;
    final texts = context.texts;
    final open = _open.contains(turn);
    final bubble = Container(
      padding: bubblePadding,
      decoration: BoxDecoration(
        color: colors.primary.surface,
        borderRadius: mineCorners,
      ),
      child: note == null
          ? _english(context, message.line.english)
          : Text(
              message.line.english,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              style: texts.body.copyWith(
                color: colors.textPrimary,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: colors.ai.text,
                decorationThickness: 2,
              ),
            ),
    );
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (note == null)
              bubble
            else
              Semantics(
                button: true,
                expanded: open,
                label: 'talk_has_better'.tr(
                  namedArgs: {'text': message.line.english},
                ),
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(
                    () => open ? _open.remove(turn) : _open.add(turn),
                  ),
                  child: bubble,
                ),
              ),
            if (note != null && open) ...[
              const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md + AppSpacing.xxs,
                  AppSpacing.sm + AppSpacing.xxs,
                  AppSpacing.sm + AppSpacing.xxs,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: colors.ai.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const AiSpark(size: 12),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'talk_better_form'.tr(),
                          style: texts.captionStrong.copyWith(
                            color: colors.ai.text,
                            fontSize: texts.caption.fontSize! * .92,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                    BetterLine(
                      note: note,
                      small: true,
                      onPlay: () => widget.onPlay(note),
                    ),
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConceptTag(name: note.concept),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _english(BuildContext context, String text) => Text(
    text,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.start,
    style: context.texts.body.copyWith(color: context.colors.textPrimary),
  );
}

/// «اضغط الجمل المنقّطة لترى صيغتها الأدق», with «المنقّطة» dotted as they are.
class _DottedHint extends StatelessWidget {
  const _DottedHint();

  static const _mark = '{dotted}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.texts.caption.copyWith(color: colors.textSecondary);
    final parts = 'talk_full_hint'
        .tr(namedArgs: {'dotted': _mark})
        .split(_mark);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts.first),
          TextSpan(
            text: 'talk_full_dotted'.tr(),
            style: style.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: colors.ai.text,
              decorationThickness: 2,
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts.last),
        ],
      ),
      style: style,
    );
  }
}
