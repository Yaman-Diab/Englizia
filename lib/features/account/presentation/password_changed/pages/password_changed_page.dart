import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/motion/hop_once.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/success_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// "Password changed" (requirements v3.0 §5.2 step 4, design "Password
/// Changed"): a quiet success, with no way back to the password screen. The
/// learner is signed in with the new password and carries on, or, when no
/// session started, signs in by hand.
class PasswordChangedPage extends StatelessWidget {
  const PasswordChangedPage({
    required this.signedIn,
    required this.onContinue,
    required this.onLeave,
    super.key,
  });

  final bool signedIn;

  /// "Keep learning", or "sign in" when not [signedIn].
  final VoidCallback onContinue;

  /// The system's back: home, never the password screen.
  final VoidCallback onLeave;

  static const _circle = 168.0;
  static const _guide = 140.0;
  static const _badge = 48.0;
  static const _badgeCheck = 26.0;

  /// The design stands the guide a little above the circle's middle.
  static const _guideLift = 8.0;
  static const _bodyMaxWidth = 290.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final reduce = AppMotion.reduceMotion(context);
    final action = AppButton(
      label: signedIn
          ? 'password_changed_continue'.tr()
          : 'sign_in_submit'.tr(),
      size: AppButtonSize.large,
      onPressed: onContinue,
    );
    const guide = Mascot(
      expression: MascotExpression.happy,
      sparkles: false,
      size: _guide,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        SizedBox.square(
                          dimension: _circle,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.primary.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      bottom: _guideLift,
                                    ),
                                    child: Center(
                                      child: HopOnce(
                                        delay: PasswordChangedEntrance.hop,
                                        child: guide,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                end: 1,
                                bottom: 1,
                                child: SuccessBadge(
                                  size: _badge,
                                  checkSize: _badgeCheck,
                                  ringColor: colors.background,
                                  growDelay: PasswordChangedEntrance.badge,
                                  checkDelay: PasswordChangedEntrance.check,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Semantics(
                          liveRegion: true,
                          child: Column(
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'password_changed_title'.tr(),
                                  textAlign: TextAlign.center,
                                  style: texts.title.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: _bodyMaxWidth,
                                ),
                                child: Text(
                                  signedIn
                                      ? 'password_changed_signed_in'.tr()
                                      : 'password_changed_sign_in'.tr(),
                                  textAlign: TextAlign.center,
                                  style: texts.body.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: reduce
                      ? action
                      : action.animate().fadeIn(
                          delay: PasswordChangedEntrance.action,
                          duration: PasswordChangedEntrance.actionFade,
                          curve: AppMotion.out,
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
