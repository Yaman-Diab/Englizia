import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:flutter/material.dart';

/// The frame of the account screens (designs "Create Account v2", "Login
/// v2"): back, a scrolling body, and a footer that rides on the keyboard, so
/// the body shrinks above it and a snack bar floats over the button.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.onBack,
    required this.body,
    required this.footer,
    super.key,
  });

  /// Null while something is being sent.
  final VoidCallback? onBack;
  final Widget body;
  final Widget footer;

  static const _topBarHeight = 56.0;

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    bottomNavigationBar: Padding(
      padding: EdgeInsetsDirectional.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Entrance(
          motion: EntranceMotion.up,
          delay: FormEntrance.action,
          child: footer,
        ),
      ),
    ),
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          SizedBox(
            height: _topBarHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'common_back'.tr(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg + AppSpacing.xs,
              ),
              child: body,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The title and its line at the start, the guide at the end. [compact]
/// folds the line away and shrinks the guide, so the fields come up while
/// the keyboard is open (design "Login v2").
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    required this.subtitle,
    required this.expression,
    this.waving = false,
    this.compact = false,
    this.mascotSize = defaultMascotSize,
    super.key,
  });

  final String title;
  final String subtitle;
  final MascotExpression expression;
  final bool waving;
  final bool compact;
  final double mascotSize;

  static const defaultMascotSize = 68.0;
  static const compactMascotSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final duration = AppMotion.resolve(context, AppMotion.fast);
    return Entrance(
      motion: EntranceMotion.up,
      delay: FormEntrance.header,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: texts.display.copyWith(color: colors.textPrimary),
                  ),
                ),
                AnimatedSize(
                  duration: duration,
                  curve: AppMotion.out,
                  alignment: AlignmentDirectional.topStart,
                  child: compact
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.xs,
                          ),
                          child: Text(
                            subtitle,
                            style: texts.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          TweenAnimationBuilder<double>(
            tween: Tween(end: compact ? compactMascotSize : mascotSize),
            duration: duration,
            curve: AppMotion.out,
            builder: (_, size, _) =>
                Mascot(expression: expression, waving: waving, size: size),
          ),
        ],
      ),
    );
  }
}

/// The send button, anything [above] it while the keyboard is open (email
/// domains), and the switch to the other account screen under it while
/// the keyboard is closed (the keyboard would hide it).
class AuthFooter extends StatelessWidget {
  const AuthFooter({
    required this.keyboardOpen,
    required this.submit,
    this.switchLead,
    this.switchAction,
    this.onSwitch,
    this.above,
    super.key,
  });

  final bool keyboardOpen;
  final Widget submit;

  /// "Have an account?" and "Sign in", or the other way round; none when
  /// both are null.
  final String? switchLead;
  final String? switchAction;
  final VoidCallback? onSwitch;
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: keyboardOpen
            ? null
            : Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.sm + AppSpacing.xxs,
          AppSpacing.xl,
          AppSpacing.sm + AppSpacing.xxs,
        ),
        child: AnimatedSize(
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.smoothOut,
          alignment: AlignmentDirectional.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (keyboardOpen && above != null) above!,
              submit,
              if (!keyboardOpen && switchAction != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                TextButton(
                  onPressed: onSwitch,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: switchLead ?? '',
                          style: texts.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: switchAction,
                          style: texts.bodyStrong.copyWith(
                            color: colors.primary.text,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
