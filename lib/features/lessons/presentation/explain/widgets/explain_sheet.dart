import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/ai_spark.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';
import 'package:englizia/features/lessons/presentation/explain/cubit/explain_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens «اشرح لي» over the feedback, up to [_maxShare] of the screen; the
/// scrim or the cross closes it.
Future<void> showExplainSheet(
  BuildContext context, {
  required ExplainCubit Function() cubit,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  clipBehavior: Clip.antiAlias,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * _maxShare,
  ),
  sheetAnimationStyle: sheetAnimation(context),
  builder: (_) => BlocProvider(
    create: (_) => cubit()..start(),
    child: const ExplainSheet(),
  ),
);

const _maxShare = .75;

class ExplainSheet extends StatelessWidget {
  const ExplainSheet({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    scopesRoute: true,
    namesRoute: true,
    explicitChildNodes: true,
    label: 'explain_title'.tr(),
    child: BlocBuilder<ExplainCubit, ExplainState>(
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Head(loading: state.status == ExplainStatus.loading),
          Flexible(
            child: switch (state.status) {
              ExplainStatus.loading => const _Writing(),
              ExplainStatus.ready => _Explained(state: state),
              ExplainStatus.failed || ExplainStatus.quotaOut => _NoAi(
                quotaOut: state.status == ExplainStatus.quotaOut,
                lesson: context.read<ExplainCubit>().request.lessonExplanation,
              ),
            },
          ),
          if (state.status == ExplainStatus.ready) _Rating(state: state),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    ),
  );
}

/// The violet head: only it and ✦ say this is the AI; the content keeps its
/// usual colors.
class _Head extends StatelessWidget {
  const _Head({required this.loading});

  final bool loading;

  static const _bar = 56.0;
  static const _handleWidth = 36.0;
  static const _handleHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.ai.surface,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: _handleWidth,
            height: _handleHeight,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(_handleHeight / 2),
            ),
          ),
          SizedBox(
            height: _bar,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xl - AppSpacing.xs,
                end: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _Glint(
                    active: loading,
                    child: AiSpark(
                      size: AppSizes.iconMd - AppSpacing.xxs,
                      color: colors.ai.fill,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'explain_title'.tr(),
                        style: context.texts.bodyStrong.copyWith(
                          color: colors.ai.text,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'explain_close'.tr(),
                    color: colors.textSecondary,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✦ dims, shrinks and turns a little, slowly, while the AI writes; still
/// under reduce motion.
class _Glint extends StatelessWidget {
  const _Glint({required this.active, required this.child});

  final bool active;
  final Widget child;

  static const _turn = 18 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    if (!active || AppMotion.reduceMotion(context)) return child;
    return child
        .animate(onPlay: (loop) => loop.repeat())
        .custom(
          duration: AppMotion.aiGlint,
          curve: AppMotion.inOut,
          builder: (_, value, child) {
            final t = math.sin(math.pi * value);
            return Opacity(
              opacity: 1 - .6 * t,
              child: Transform.rotate(
                angle: _turn * t,
                child: Transform.scale(scale: 1 - .2 * t, child: child),
              ),
            );
          },
        );
  }
}

/// «نكتب لك الشرح…», with the sections' places held.
class _Writing extends StatelessWidget {
  const _Writing();

  static const _bars = [(52.0, 1.0), (52.0, .88), (76.0, 1.0), (76.0, .72)];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'explain_writing'.tr(),
              style: context.texts.caption.copyWith(color: colors.ai.text),
            ),
            for (final (height, share) in _bars) ...[
              const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
              ExcludeSemantics(
                child: FractionallySizedBox(
                  widthFactor: share,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: colors.ai.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
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

/// «إجابتك», «الصحيح», «السبب» and «مثال آخر».
class _Explained extends StatelessWidget {
  const _Explained({required this.state});

  final ExplainState state;

  @override
  Widget build(BuildContext context) {
    final explanation = state.explanation!;
    final animate = state.fresh && !AppMotion.reduceMotion(context);
    final body = SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl - AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (explanation.yours.isNotEmpty) ...[
            _Section(
              label: 'explain_yours'.tr(),
              child: _Sentence(
                words: explanation.yours,
                yours: true,
                drawStrikes: animate,
              ),
            ),
            const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
            _Section(
              label: 'explain_right'.tr(),
              child: _Sentence(words: explanation.right, yours: false),
            ),
            const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
          ],
          _Section(
            label: 'explain_why'.tr(),
            child: Text(
              explanation.why,
              style: context.texts.body.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
          _Section(
            label: 'explain_example'.tr(),
            child: _Example(explanation: explanation),
          ),
        ],
      ),
    );
    if (!animate) return body;
    return body.animate().fadeIn(
      duration: AppMotion.fast,
      curve: AppMotion.out,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: context.texts.captionStrong.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      child,
    ],
  );
}

/// A sentence word by word: in the learner's answer the wrong words are
/// struck in a quiet color, never red; in the right one the words put right
/// are strong, in the success color.
class _Sentence extends StatelessWidget {
  const _Sentence({
    required this.words,
    required this.yours,
    this.drawStrikes = false,
  });

  final List<ExplainWord> words;
  final bool yours;

  /// The lines are drawn, from where the sentence starts, as it arrives.
  final bool drawStrikes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final sentence = words.map((word) => word.text).join(' ');
    final marked = [
      for (final word in words)
        if (word.marked) word.text,
    ];
    var strike = 0;
    return Semantics(
      label: yours
          ? 'explain_yours_label'.tr(
              namedArgs: {'sentence': sentence, 'wrong': marked.join(' ')},
            )
          : sentence,
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          spacing: AppSpacing.xs + AppSpacing.xxs / 2,
          children: [
            for (final word in words)
              if (yours)
                _StruckWord(
                  word: word,
                  order: word.marked ? strike++ : 0,
                  draw: drawStrikes,
                )
              else
                Text(
                  word.text,
                  style: (word.marked ? texts.bodyStrong : texts.body).copyWith(
                    color: word.marked
                        ? colors.success.text
                        : colors.textPrimary,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StruckWord extends StatelessWidget {
  const _StruckWord({
    required this.word,
    required this.order,
    required this.draw,
  });

  final ExplainWord word;
  final int order;
  final bool draw;

  static const _line = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Text(
      word.text,
      style: context.texts.body.copyWith(
        color: word.marked ? colors.textSecondary : colors.textPrimary,
      ),
    );
    if (!word.marked) return text;
    final line = Container(
      height: _line,
      decoration: BoxDecoration(
        color: colors.textSecondary,
        borderRadius: BorderRadius.circular(_line / 2),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        text,
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, .1),
            child: draw
                ? line.animate().scaleX(
                    begin: 0,
                    end: 1,
                    alignment: AlignmentDirectional.centerStart.resolve(
                      TextDirection.ltr,
                    ),
                    delay:
                        AppMotion.strikeDelay + AppMotion.stagger * 1.5 * order,
                    duration: AppMotion.closeUp,
                    curve: AppMotion.out,
                  )
                : line,
          ),
        ),
      ],
    );
  }
}

/// «مثال آخر» with its voice and its translation.
class _Example extends StatelessWidget {
  const _Example({required this.explanation});

  final Explanation explanation;

  static const _speaker = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  explanation.example,
                  style: texts.body.copyWith(color: colors.textPrimary),
                ),
              ),
              if (explanation.exampleAudioUrl != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: context.read<ExplainCubit>().playExample,
                  tooltip: 'explain_listen'.tr(),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(_speaker),
                    minimumSize: const Size.square(_speaker),
                    backgroundColor: colors.info.fill,
                    foregroundColor: colors.surface,
                  ),
                  iconSize: AppSizes.iconSm + AppSpacing.xxs,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ],
          ),
        ),
        if (explanation.exampleArabic.isNotEmpty)
          Text(
            explanation.exampleArabic,
            textDirection: TextDirection.rtl,
            style: texts.caption.copyWith(
              color: colors.textSecondary,
              fontSize: texts.body.fontSize! * .875,
              height: 22 / 14,
            ),
          ),
      ],
    );
  }
}

/// «هل ساعدك الشرح؟» with the thumbs, then «شكرًا», and the explanations
/// left today.
class _Rating extends StatelessWidget {
  const _Rating({required this.state});

  final ExplainState state;

  static const _thumb = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<ExplainCubit>();
    final line = texts.caption.copyWith(
      fontSize: texts.body.fontSize! * .875,
      height: 22 / 14,
    );
    Widget thumb(IconData icon, String label, {required bool helpful}) =>
        IconButton(
          onPressed: () => cubit.rate(helpful: helpful),
          tooltip: label,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(_thumb),
            minimumSize: const Size.square(_thumb),
            foregroundColor: colors.textSecondary,
            side: BorderSide(color: colors.border),
          ),
          iconSize: AppSizes.iconSm + AppSpacing.xxs,
          icon: Icon(icon),
        );
    final left = state.left;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTapTarget,
              ),
              child: state.helpful == null
                  ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            'explain_helped'.tr(),
                            style: line.copyWith(color: colors.textPrimary),
                          ),
                        ),
                        thumb(
                          Icons.thumb_up_outlined,
                          'explain_helped_yes'.tr(),
                          helpful: true,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        thumb(
                          Icons.thumb_down_outlined,
                          'explain_helped_no'.tr(),
                          helpful: false,
                        ),
                      ],
                    )
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          'explain_thanks'.tr(),
                          style: line.copyWith(color: colors.textSecondary),
                        ),
                      ),
                    ),
            ),
            if (left != null)
              Text(
                'explain_left'.tr(namedArgs: {'count': '$left'}),
                style: texts.caption.copyWith(color: colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// The AI couldn't explain, or none are left today: said as information, as
/// nothing went wrong for the learner, with the lesson's own explanation.
class _NoAi extends StatelessWidget {
  const _NoAi({required this.quotaOut, required this.lesson});

  final bool quotaOut;
  final String? lesson;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final lesson = this.lesson;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl - AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: colors.info.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  AppIconView(
                    quotaOut ? AppIcon.clock : AppIcon.infoCircle,
                    size: AppSizes.iconMd - AppSpacing.xs,
                    color: colors.info.fill,
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      quotaOut
                          ? 'explain_quota_out'.tr()
                          : 'explain_failed'.tr(),
                      style: texts.bodyStrong.copyWith(
                        color: colors.info.text,
                        fontSize: texts.body.fontSize! * .94,
                        height: 24 / 15,
                      ),
                    ),
                  ),
                  if (!quotaOut) ...[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: context.read<ExplainCubit>().retry,
                      style: TextButton.styleFrom(
                        fixedSize: const Size.fromHeight(40),
                        backgroundColor: colors.surface,
                        foregroundColor: colors.primary.text,
                        shape: const StadiumBorder(),
                        textStyle: texts.captionStrong,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.md + AppSpacing.xxs,
                        ),
                      ),
                      child: Text('common_retry'.tr()),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (lesson != null && lesson.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
            _Section(
              label: 'explain_lesson'.tr(),
              child: Text(
                lesson,
                style: texts.body.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
