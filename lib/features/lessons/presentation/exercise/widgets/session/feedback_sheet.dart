import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/feedback_content.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// What the sheet shows of the question's clip.
final class FeedbackClip {
  const FeedbackClip({required this.playing, required this.onToggle});

  final bool playing;
  final VoidCallback onToggle;
}

/// Takes the place of «تحقق» after checking, in the same container, for every
/// template (requirements v3.0 §7.2, design "Exercise Feedback"). The state is
/// always an icon, a text and a color together, and a mistake is a moment to
/// learn: the right answer, its sound and why. It comes up from below; «التالي»
/// takes it down first and only then moves on. Long content scrolls inside it,
/// up to [_maxShare] of the screen, with «التالي» fixed under it.
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({
    required this.exercise,
    required this.evaluation,
    required this.draft,
    required this.hinted,
    required this.xp,
    required this.explainEnabled,
    required this.clip,
    required this.onNext,
    required this.onExplain,
    required this.onReport,
    required this.onRetry,
    required this.onSkip,
    super.key,
  });

  final Exercise exercise;
  final Evaluation evaluation;
  final ExerciseDraft? draft;
  final bool hinted;

  /// What a right answer earns, once the server sends it (v1.0).
  final int? xp;
  final bool explainEnabled;
  final FeedbackClip clip;
  final VoidCallback onNext;
  final VoidCallback onExplain;
  final ValueChanged<ProblemReason> onReport;

  /// A sentence not heard well enough: try again, or move on uncounted.
  final VoidCallback onRetry;
  final VoidCallback onSkip;

  static const _maxShare = .6;

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet>
    with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
    reverseDuration: AppMotion.sheetOut,
  );
  late final _curve = CurvedAnimation(parent: _rise, curve: AppMotion.out);
  bool _overflows = false;
  bool _leaving = false;
  bool _thanks = false;
  Timer? _thanksTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_rise.forward());
  }

  @override
  void dispose() {
    _thanksTimer?.cancel();
    _curve.dispose();
    _rise.dispose();
    super.dispose();
  }

  /// Takes the sheet down, and only then does [then].
  Future<void> _leave(VoidCallback then) async {
    if (_leaving) return;
    _leaving = true;
    await _rise.reverse().orCancel.catchError((_) {});
    if (mounted) then();
  }

  Future<void> _report() async {
    final reason = await showReportSheet(context);
    if (reason == null || !mounted) return;
    widget.onReport(reason);
    setState(() => _thanks = true);
    _thanksTimer?.cancel();
    _thanksTimer = Timer(AppMotion.toastHold, () {
      if (mounted) setState(() => _thanks = false);
    });
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    final overflows = notification.metrics.maxScrollExtent > 0;
    if (overflows != _overflows) setState(() => _overflows = overflows);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final evaluation = widget.evaluation;
    final ToneColors tone = switch (evaluation) {
      ReviewPending() ||
      ReviewLater() ||
      SpokenOffTopic() ||
      ReviewQuotaOut() => colors.info,
      SpeechEvaluation(correct: false) => colors.info,
      _ when evaluation.correct => colors.success,
      _ => colors.error,
    };
    final reduce = AppMotion.reduceMotion(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    final waiting = evaluation is ReviewPending;
    final retrying =
        (evaluation is SpeechEvaluation && !evaluation.correct) ||
        evaluation is SpokenOffTopic;
    final sheet = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * FeedbackSheet._maxShare,
      ),
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.quick),
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: AnimatedSize(
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.out,
          alignment: AlignmentDirectional.bottomStart,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: _onMetrics,
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.xl,
                      AppSpacing.xl - _Content.titleSlack,
                      AppSpacing.xl,
                      0,
                    ),
                    child: _Content(
                      exercise: widget.exercise,
                      evaluation: evaluation,
                      draft: widget.draft,
                      hinted: widget.hinted,
                      xp: widget.xp,
                      explainEnabled: widget.explainEnabled,
                      clip: widget.clip,
                      tone: tone,
                      onExplain: widget.onExplain,
                      onReport: _report,
                    ),
                  ),
                ),
              ),
              if (waiting)
                SizedBox(height: AppSpacing.xl + inset)
              else if (retrying)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    AppSpacing.lg + AppSpacing.xs,
                    AppSpacing.xl,
                    AppSpacing.xs + inset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: 'lesson_fb_try_again'.tr(),
                        size: AppButtonSize.large,
                        onPressed: () => _leave(widget.onRetry),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: 'lesson_fb_skip'.tr(),
                        variant: AppButtonVariant.text,
                        onPressed: () => _leave(widget.onSkip),
                      ),
                    ],
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: _overflows
                        ? Border(top: BorderSide(color: colors.border))
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.xl,
                      AppSpacing.lg + AppSpacing.xs,
                      AppSpacing.xl,
                      AppSpacing.md + inset,
                    ),
                    child: AppButton(
                      label: 'lesson_next'.tr(),
                      size: AppButtonSize.large,
                      onPressed: () => _leave(widget.onNext),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => reduce
          ? Opacity(opacity: _curve.value, child: child)
          : FractionalTranslation(
              translation: Offset(0, 1 - _curve.value),
              child: child,
            ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          sheet,
          if (_thanks)
            const PositionedDirectional(
              top: -AppSpacing.md,
              start: AppSpacing.lg,
              end: AppSpacing.lg,
              child: FractionalTranslation(
                translation: Offset(0, -1),
                child: _ThanksStrip(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.exercise,
    required this.evaluation,
    required this.draft,
    required this.hinted,
    required this.xp,
    required this.explainEnabled,
    required this.clip,
    required this.tone,
    required this.onExplain,
    required this.onReport,
  });

  final Exercise exercise;
  final Evaluation evaluation;
  final ExerciseDraft? draft;
  final bool hinted;
  final int? xp;
  final bool explainEnabled;
  final FeedbackClip clip;
  final ToneColors tone;
  final VoidCallback onExplain;
  final VoidCallback onReport;

  /// The report button is taller than the title row by this much on each side;
  /// the gaps around the row allow for it.
  static const titleSlack = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final evaluation = this.evaluation;
    if (evaluation is ReviewPending) {
      return _Waiting(
        tone: tone,
        title: 'lesson_fb_reviewing'.tr(),
        leading: exercise is SpeakAnswerExercise
            ? const _AiDots()
            : AppSpinner(size: _Mark.size - 8, color: tone.fill),
      );
    }
    if (evaluation is ReviewLater) {
      return _Waiting(
        tone: tone,
        title: 'lesson_fb_later'.tr(),
        leading: Container(
          width: _Mark.size,
          height: _Mark.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tone.fill, shape: BoxShape.circle),
          child: AppIconView(
            AppIcon.clock,
            size: AppSizes.iconSm + AppSpacing.xxs,
            color: context.colors.surface,
          ),
        ),
      );
    }
    if (evaluation is ReviewQuotaOut) {
      return _Waiting(
        tone: tone,
        title: 'lesson_fb_quota'.tr(),
        leading: Container(
          width: _Mark.size,
          height: _Mark.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tone.fill, shape: BoxShape.circle),
          child: Icon(
            Icons.info_outline_rounded,
            size: AppSizes.iconSm + AppSpacing.xxs,
            color: context.colors.surface,
          ),
        ),
      );
    }
    if (evaluation is SpeechEvaluation && !evaluation.correct) {
      return _SpeechRetry(
        tone: tone,
        title: 'lesson_fb_try_title'.tr(),
        body: 'lesson_fb_try_body'.tr(),
        icon: Icons.mic_rounded,
      );
    }
    if (evaluation is SpokenOffTopic) {
      return _SpeechRetry(
        tone: tone,
        title: 'lesson_fb_off_title'.tr(),
        body: evaluation.note,
        icon: Icons.info_outline_rounded,
      );
    }
    final correct = evaluation.correct;
    final xp = this.xp;
    final other = correct ? otherRightForm(exercise, draft, evaluation) : null;
    final spelling = correct ? spellingParts(exercise, evaluation) : null;
    final explanation = exercise.explanation;
    final listening = exercise is ListenChooseExercise;
    final parts = correctAnswerParts(exercise);
    final title = correct
        ? exercise is SpeakAnswerExercise
              ? 'lesson_fb_answered'.tr()
              : exercise.isSpeech
              ? 'lesson_fb_well_done'.tr()
              : exercise.checksItself
              ? 'lesson_fb_matched'.tr()
              : 'lesson_fb_correct'.tr()
        : 'lesson_fb_wrong'.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: correct
              ? title
              : 'lesson_fb_wrong_said'.tr(
                  namedArgs: {
                    'answer': parts
                        .where((p) => !p.struck)
                        .map((p) => p.text)
                        .join(),
                  },
                ),
          child: Row(
            children: [
              _Mark(correct: correct),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    style: context.texts.title.copyWith(color: tone.text),
                  ),
                ),
              ),
              IconButton(
                onPressed: onReport,
                tooltip: 'lesson_report'.tr(),
                color: context.colors.textSecondary,
                style: IconButton.styleFrom(
                  padding: EdgeInsetsDirectional.zero,
                  fixedSize: const Size.square(AppSizes.minTapTarget),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(
                  Icons.outlined_flag_rounded,
                  size: _Mark.size - 12,
                ),
              ),
            ],
          ),
        ),
        if (correct && hinted) ...[const _Assisted()],
        if (correct && xp != null) ...[
          SizedBox(height: hinted ? AppSpacing.md : AppSpacing.xs),
          _XpBadge(xp: xp),
        ],
        if (spelling != null) ...[
          SizedBox(height: xp == null ? AppSpacing.sm : AppSpacing.lg),
          _Caption('lesson_fb_spelling'.tr()),
          const SizedBox(height: AppSpacing.xs),
          _EnglishLine(parts: spelling),
        ],
        if (other != null) ...[
          SizedBox(height: xp == null ? AppSpacing.sm : AppSpacing.lg),
          _Caption(
            exercise is TranslationExercise
                ? 'lesson_fb_other_translation'.tr()
                : 'lesson_fb_other_form'.tr(),
          ),
          const SizedBox(height: AppSpacing.xs),
          _EnglishLine(parts: [AnswerPart(other)]),
        ],
        if (evaluation case SpokenAnswered(:final note, :final better)) ...[
          const SizedBox(height: AppSpacing.md),
          _AiNote(note: note, better: better),
        ],
        if (!correct && !listening && parts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Caption('lesson_fb_right_answer'.tr()),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: _EnglishLine(parts: parts)),
              if (exercise.answerClipUrl != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _SmallClipButton(clip: clip),
              ],
            ],
          ),
        ],
        if (!correct && listening) ...[
          const SizedBox(height: AppSpacing.sm),
          _ListenAgain(clip: clip),
          const SizedBox(height: AppSpacing.lg),
          _Caption('lesson_fb_heard'.tr()),
          const SizedBox(height: AppSpacing.xs),
          _EnglishLine(
            parts: heardParts(exercise as ListenChooseExercise, switch (draft) {
              ChoiceDraft(:final optionId) => optionId,
              _ => null,
            }),
          ),
        ],
        if (!correct && explanation != null) ...[
          const SizedBox(height: AppSpacing.md),
          _Explanation(text: explanation),
        ],
        if (!correct && explainEnabled) ...[
          const SizedBox(height: AppSpacing.lg),
          _ExplainButton(onTap: onExplain),
        ],
      ],
    );
  }
}

/// Not heard well enough, or an answer to something else: neutral, as speech
/// can't be wrong (S §7.5). No red, no cross, nothing counted.
class _SpeechRetry extends StatelessWidget {
  const _SpeechRetry({
    required this.tone,
    required this.title,
    required this.body,
    required this.icon,
  });

  final ToneColors tone;
  final String title;
  final String body;
  final IconData icon;

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(top: _Content.titleSlack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: _Mark.size,
                height: _Mark.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: _iconSize,
                  color: context.colors.surface,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: context.texts.title.copyWith(color: tone.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: context.texts.body.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// While the answer is with the server, or waits for it: no judgement yet, so
/// no report or score either.
class _Waiting extends StatelessWidget {
  const _Waiting({
    required this.tone,
    required this.title,
    required this.leading,
  });

  final ToneColors tone;
  final String title;
  final Widget leading;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(top: _Content.titleSlack),
      child: Row(
        children: [
          SizedBox.square(
            dimension: _Mark.size,
            child: Center(child: leading),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: context.texts.bodyStrong.copyWith(color: tone.text),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The verdict's mark: a circle grows in, then its check or cross draws itself
/// (a check in one stroke, a cross in two). All of it just there under reduce
/// motion. Decorative: the title beside it says the same.
class _Mark extends StatelessWidget {
  const _Mark({required this.correct});

  final bool correct;

  static const size = 32.0;
  static const _inkSize = 18.0;
  static const _growFrom = .6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = correct ? colors.success.fill : colors.error.fill;
    final reduce = AppMotion.reduceMotion(context);
    final ink = colors.surface;
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: reduce
          ? _ink(1, ink)
          : const SizedBox.square(dimension: _inkSize).animate().custom(
              delay: FeedbackEntrance.stroke,
              duration: AppMotion.fast,
              curve: AppMotion.out,
              builder: (_, value, _) => _ink(value, ink),
            ),
    );
    return ExcludeSemantics(
      child: reduce
          ? circle
          : circle
                .animate()
                .fadeIn(
                  delay: FeedbackEntrance.circle,
                  duration: AppMotion.quick,
                  curve: AppMotion.out,
                )
                .scaleXY(begin: _growFrom, end: 1, curve: AppMotion.out),
    );
  }

  Widget _ink(double progress, Color color) => CustomPaint(
    size: const Size.square(_inkSize),
    painter: _MarkPainter(correct: correct, progress: progress, color: color),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.correct,
    required this.progress,
    required this.color,
  });

  final bool correct;
  final double progress;
  final Color color;

  static const _box = 24.0;
  static const _stroke = 3.2;

  static Path get _check => Path()
    ..moveTo(5, 12.5)
    ..lineTo(9.5, 17)
    ..lineTo(19, 7.5);

  static Path _line(double x1, double y1, double x2, double y2) => Path()
    ..moveTo(x1, y1)
    ..lineTo(x2, y2);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _box);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final strokes = correct
        ? [_check]
        : [_line(7, 7, 17, 17), _line(17, 7, 7, 17)];
    for (final (i, stroke) in strokes.indexed) {
      final share = ((progress * strokes.length) - i).clamp(0.0, 1.0);
      for (final PathMetric metric in stroke.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * share), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.correct != correct;
}

class _Assisted extends StatelessWidget {
  const _Assisted();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        AppIconView(
          AppIcon.lightbulb,
          size: AppSizes.iconSm,
          color: colors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'lesson_fb_assisted'.tr(),
          style: context.texts.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// What the answer earned, arriving after the verdict.
class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp});

  final int xp;

  static const _height = 32.0;
  static const _iconSize = 18.0;
  static const _growFrom = .8;
  static const _riseFrom = .2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badge = Container(
      height: _height,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.sm + AppSpacing.xxs,
        end: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.reward.surface,
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: _iconSize, color: colors.reward.fill),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'lesson_fb_xp'.tr(namedArgs: {'xp': '$xp'}),
            textDirection: TextDirection.ltr,
            style: context.texts.captionStrong.copyWith(
              color: colors.reward.text,
            ),
          ),
        ],
      ),
    );
    return AppMotion.reduceMotion(context)
        ? badge
        : badge
              .animate()
              .fadeIn(
                delay: FeedbackEntrance.reward,
                duration: AppMotion.sheetIn,
                curve: AppMotion.smoothOut,
              )
              .slideY(begin: _riseFrom, end: 0, curve: AppMotion.smoothOut)
              .scaleXY(begin: _growFrom, end: 1, curve: AppMotion.smoothOut);
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.texts.caption.copyWith(color: context.colors.textSecondary),
  );
}

/// An English sentence, left to right in any app language, its key parts heavier.
class _EnglishLine extends StatelessWidget {
  const _EnglishLine({required this.parts});

  final List<AnswerPart> parts;

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;
    return SizedBox(
      width: double.infinity,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text.rich(
          locale: const Locale('en'),
          TextSpan(
            style: texts.body.copyWith(color: context.colors.textPrimary),
            children: [
              for (final part in parts)
                TextSpan(
                  text: part.text,
                  // Each weight has its own family (ADR 5).
                  style: part.strong
                      ? TextStyle(
                          fontFamily: texts.bodyStrong.fontFamily,
                          decoration: part.underlined
                              ? TextDecoration.underline
                              : null,
                        )
                      : part.struck
                      ? TextStyle(
                          color: context.colors.textSecondary,
                          decoration: TextDecoration.lineThrough,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says the right sentence, ringed while it plays.
class _SmallClipButton extends StatelessWidget {
  const _SmallClipButton({required this.clip});

  final FeedbackClip clip;

  static const _circle = 40.0;
  static const _iconSize = 20.0;
  static const _ring = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      onPressed: clip.onToggle,
      tooltip: 'lesson_fb_listen_sentence'.tr(),
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
              color: clip.playing ? colors.info.surface : Colors.transparent,
              spreadRadius: _ring,
            ),
          ],
        ),
        child: AppIconView(
          AppIcon.volume,
          size: _iconSize,
          color: colors.surface,
        ),
      ),
    );
  }
}

/// On a listening question the clip is the point, so its button stands out.
class _ListenAgain extends StatelessWidget {
  const _ListenAgain({required this.clip});

  final FeedbackClip clip;

  static const _height = AppSizes.minTapTarget;
  static const _iconSize = 20.0;
  static const _ring = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_height / 2);
    return PressScale(
      child: Semantics(
        button: true,
        selected: clip.playing,
        label: 'lesson_fb_listen_clip'.tr(),
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.quick),
            height: _height,
            decoration: BoxDecoration(
              color: colors.info.fill,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: clip.playing
                      ? colors.info.fill.withValues(alpha: .25)
                      : Colors.transparent,
                  spreadRadius: _ring,
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: clip.onToggle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.lg,
                    end: AppSpacing.lg + AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIconView(
                        AppIcon.volume,
                        size: _iconSize,
                        color: colors.surface,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'lesson_fb_listen_again'.tr(),
                        style: context.texts.button.copyWith(
                          color: colors.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Why, in the content's Arabic, a paragraph per line.
class _Explanation extends StatelessWidget {
  const _Explanation({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, line) in text.split('\n').indexed) ...[
        if (i > 0) const SizedBox(height: AppSpacing.sm),
        Text(
          line,
          textDirection: TextDirection.rtl,
          style: context.texts.body.copyWith(color: context.colors.textPrimary),
        ),
      ],
    ],
  );
}

/// «اشرح لي»: the only violet on the screen, as violet means AI.
class _ExplainButton extends StatelessWidget {
  const _ExplainButton({required this.onTap});

  final VoidCallback onTap;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_height / 2);
    return PressScale(
      child: Material(
        color: colors.ai.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.md,
                end: AppSpacing.lg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: AppSizes.iconSm,
                    color: colors.ai.text,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'lesson_fb_explain'.tr(),
                    style: context.texts.captionStrong.copyWith(
                      color: colors.ai.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots that pulse while the AI judges, still under reduce motion.
class _AiDots extends StatefulWidget {
  const _AiDots();

  @override
  State<_AiDots> createState() => _AiDotsState();
}

class _AiDotsState extends State<_AiDots> with SingleTickerProviderStateMixin {
  static const _dot = 7.0;
  static const _dots = 3;
  static const _dimmest = .3;

  late final _round = AnimationController(
    vsync: this,
    duration: AppMotion.aiDots,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _round.stop();
    } else if (!_round.isAnimating) {
      unawaited(_round.repeat());
    }
  }

  @override
  void dispose() {
    _round.dispose();
    super.dispose();
  }

  double _strength(int dot) {
    final offset =
        AppMotion.aiDotsOffset.inMilliseconds /
        AppMotion.aiDots.inMilliseconds *
        dot;
    final t = (_round.value - offset) % 1;
    return _dimmest + (1 - _dimmest) * (1 - (2 * t - 1).abs());
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.ai.fill;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _round,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dots; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: _strength(i)),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the AI has to say: the only violet in these templates, as violet means
/// AI.
class _AiNote extends StatelessWidget {
  const _AiNote({required this.note, required this.better});

  final String note;
  final String? better;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final better = this.better;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.ai.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: AppSizes.iconSm,
                color: colors.ai.text,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'lesson_fb_ai_note'.tr(),
                style: texts.captionStrong.copyWith(color: colors.ai.text),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            note,
            textDirection: TextDirection.rtl,
            style: texts.caption.copyWith(color: colors.textPrimary),
          ),
          if (better != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _Caption('lesson_fb_ai_better'.tr()),
            const SizedBox(height: AppSpacing.xxs),
            _EnglishLine(parts: [AnswerPart(better, strong: true)]),
          ],
        ],
      ),
    );
  }
}

/// Floats over the sheet for a moment; the sheet stays as it was.
class _ThanksStrip extends StatelessWidget {
  const _ThanksStrip();

  static const _minHeight = AppSizes.minTapTarget;
  static const _iconSize = 20.0;
  static const _riseFrom = .15;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strip = Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: _minHeight),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.success.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.success.fill),
        ),
        child: Row(
          children: [
            AppIconView(
              AppIcon.check,
              size: _iconSize,
              color: colors.success.fill,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'lesson_report_thanks'.tr(),
                style: context.texts.captionStrong.copyWith(
                  color: colors.success.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AppMotion.reduceMotion(context)
        ? strip
        : strip
              .animate()
              .fadeIn(duration: AppMotion.fast, curve: AppMotion.out)
              .slideY(begin: _riseFrom, end: 0, curve: AppMotion.out);
  }
}
