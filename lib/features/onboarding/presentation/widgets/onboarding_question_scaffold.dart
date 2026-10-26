import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_motion.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/onboarding/presentation/widgets/speech_bubble.dart';
import 'package:englizia/features/onboarding/presentation/widgets/staggered_entrance.dart';
import 'package:flutter/material.dart';

/// The shared layout of every onboarding question (design "Onboarding
/// Question"): back + progress, the guide asking in a bubble, the answers,
/// an optional helper line and the continue button. Only the content
/// changes per step.
class OnboardingQuestionScaffold extends StatelessWidget {
  const OnboardingQuestionScaffold({
    required this.question,
    required this.step,
    required this.totalSteps,
    required this.options,
    required this.continueLabel,
    required this.onContinue,
    required this.onBack,
    this.helper,
    this.helperIcon,
    this.helperIsInfo = false,
    this.expression = MascotExpression.welcome,
    this.mascotSize = defaultMascotSize,
    super.key,
  });

  final String question;

  /// 1-based position on the learner's path, and the path's length.
  final int step;
  final int totalSteps;
  final List<Widget> options;
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

  static const defaultMascotSize = 72.0;
  static const playfulMascotSize = 104.0;

  /// The bubble sits higher than the guide's feet, level with its head.
  static const _bubbleLiftRatio = .28;

  // Entrance slots, as fractions of AppMotion.heroEntrance (design delays).
  static const _slot = .448;
  static const _optionStart = .272;
  static const _optionStagger = .048;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: StaggeredEntrance(
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
                    EntranceItem(
                      motion: EntranceMotion.pop,
                      begin: .096,
                      end: .096 + _slot,
                      child: Mascot(expression: expression, size: mascotSize),
                    ),
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          bottom: mascotSize * _bubbleLiftRatio,
                        ),
                        child: EntranceItem(
                          motion: EntranceMotion.pop,
                          begin: .192,
                          end: .192 + _slot,
                          child: SpeechBubble(text: question),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.lg + AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, option) in options.indexed) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        EntranceItem(
                          motion: EntranceMotion.up,
                          begin: _optionStart + i * _optionStagger,
                          end: _optionStart + i * _optionStagger + _slot,
                          child: option,
                        ),
                      ],
                      if (helper case final helper?) ...[
                        const SizedBox(height: AppSpacing.lg),
                        EntranceItem(
                          motion: EntranceMotion.up,
                          begin: .432,
                          end: .432 + _slot,
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
              EntranceItem(
                motion: EntranceMotion.up,
                begin: .48,
                end: .48 + _slot,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    AppSpacing.xs,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: AppButton(
                    label: continueLabel,
                    onPressed: onContinue,
                    size: AppButtonSize.large,
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
