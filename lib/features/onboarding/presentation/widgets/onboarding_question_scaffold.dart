import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/onboarding/presentation/widgets/speech_bubble.dart';
import 'package:flutter/material.dart';

/// The shared layout of every onboarding question (design "Onboarding
/// Question"): back + progress, the guide asking in a bubble, the answers,
/// optional details and helper line, and the continue button with an
/// optional secondary action and footnote. Only the content changes per
/// step.
class OnboardingQuestionScaffold extends StatelessWidget {
  const OnboardingQuestionScaffold({
    required this.question,
    required this.step,
    required this.totalSteps,
    required this.options,
    required this.continueLabel,
    required this.onContinue,
    required this.onBack,
    this.subtitle,
    this.lead,
    this.details,
    this.helper,
    this.helperIcon,
    this.helperIsInfo = false,
    this.expression = MascotExpression.welcome,
    this.mascotSize = defaultMascotSize,
    this.secondaryLabel,
    this.onSecondary,
    this.footnote,
    super.key,
  });

  final String question;

  /// A short line under the bubble, e.g. "pick all that apply".
  final String? subtitle;

  /// 1-based position on the learner's path, and the path's length.
  final int step;
  final int totalSteps;
  final List<Widget> options;

  /// Above the answers: what they change (e.g. a notification preview).
  final Widget? lead;

  /// Under the answers: what the chosen answer leads to. Changes animate.
  final Widget? details;
  final String? helper;
  final String continueLabel;

  /// Null keeps the button disabled (nothing chosen yet).
  final VoidCallback? onContinue;
  final VoidCallback onBack;
  final MascotExpression expression;

  /// Shown before [helper], e.g. a lock for privacy notes.
  final IconData? helperIcon;

  /// Info tone (hints, privacy) instead of the muted default.
  final bool helperIsInfo;

  /// 72 by default; the design's playful steps use [playfulMascotSize].
  final double mascotSize;

  /// A quieter action under the continue button, e.g. "test later".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// A short note under the buttons.
  final String? footnote;

  static const defaultMascotSize = 72.0;
  static const playfulMascotSize = 104.0;

  /// The bubble sits higher than the guide's feet, level with its head.
  static const _bubbleLiftRatio = .28;
  static const _mascotGap = AppSpacing.sm + AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(step: step, totalSteps: totalSteps, onBack: onBack),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Entrance(
                    motion: EntranceMotion.pop,
                    delay: QuestionEntrance.mascot,
                    child: Mascot(expression: expression, size: mascotSize),
                  ),
                  const SizedBox(width: _mascotGap),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        bottom: mascotSize * _bubbleLiftRatio,
                      ),
                      child: Entrance(
                        motion: EntranceMotion.pop,
                        delay: QuestionEntrance.bubble,
                        child: SpeechBubble(text: question),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle case final subtitle?)
              Padding(
                // Aligned under the bubble, past the guide.
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl + mascotSize + _mascotGap,
                  AppSpacing.sm + AppSpacing.xxs,
                  AppSpacing.xl,
                  0,
                ),
                child: Entrance(
                  motion: EntranceMotion.up,
                  delay: QuestionEntrance.subtitle,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      subtitle,
                      style: context.texts.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  subtitle == null ? AppSpacing.xl : AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg + AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lead case final lead?) ...[
                      Entrance(
                        motion: EntranceMotion.up,
                        delay: QuestionEntrance.answer(0),
                        child: _Resizing(clip: Clip.none, child: lead),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    for (final (i, option) in options.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      Entrance(
                        motion: EntranceMotion.up,
                        delay: QuestionEntrance.answer(i),
                        child: option,
                      ),
                    ],
                    if (details case final details?) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Entrance(
                        motion: EntranceMotion.up,
                        delay: QuestionEntrance.helper,
                        child: _Resizing(child: details),
                      ),
                    ],
                    if (helper case final helper?) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Entrance(
                        motion: EntranceMotion.up,
                        delay: QuestionEntrance.helper,
                        child: _Helper(
                          text: helper,
                          icon: helperIcon,
                          color: helperIsInfo
                              ? colors.info.text
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Entrance(
              motion: EntranceMotion.up,
              delay: QuestionEntrance.action,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: _Resizing(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: continueLabel,
                        onPressed: onContinue,
                        size: AppButtonSize.large,
                      ),
                      if (secondaryLabel case final label?) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppButton(
                          label: label,
                          onPressed: onSecondary,
                          variant: AppButtonVariant.text,
                        ),
                      ],
                      if (footnote case final footnote?)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.xxs,
                          ),
                          child: Text(
                            footnote,
                            textAlign: TextAlign.center,
                            style: context.texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grows and shrinks with its content instead of jumping.
class _Resizing extends StatelessWidget {
  const _Resizing({required this.child, this.clip = Clip.hardEdge});

  final Widget child;

  /// [Clip.none] for content with a shadow, which would be cut off.
  final Clip clip;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: AppMotion.resolve(context, AppMotion.medium),
    curve: AppMotion.smoothOut,
    alignment: AlignmentDirectional.topCenter,
    clipBehavior: clip,
    child: child,
  );
}

class _Helper extends StatelessWidget {
  const _Helper({required this.text, required this.color, this.icon});

  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = context.texts.caption.copyWith(color: color);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon case final icon?) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
            child: Icon(icon, size: AppSizes.iconSm, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  static const _height = 56.0;
  static const _trackHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final target = step / totalSteps;
    return SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.sm,
          end: AppSpacing.xl,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: 'common_back'.tr(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                label: 'onboarding_progress'.tr(
                  namedArgs: {'current': '$step', 'total': '$totalSteps'},
                ),
                child: ExcludeSemantics(
                  child: TweenAnimationBuilder<double>(
                    // Grows from the previous step so the move is visible.
                    tween: Tween(begin: (step - 1) / totalSteps, end: target),
                    duration: AppMotion.resolve(context, AppMotion.verySlow),
                    curve: AppMotion.smoothOut,
                    builder: (context, value, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: _trackHeight,
                        color: colors.primary.fill,
                        backgroundColor: context.scheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
