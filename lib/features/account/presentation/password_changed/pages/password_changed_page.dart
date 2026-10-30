import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
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
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      bottom: _guideLift,
                                    ),
                                    child: Center(
                                      child: reduce
                                          ? guide
                                          : Animate(
                                                  delay: PasswordChangedEntrance
                                                      .hop,
                                                  child: guide,
                                                )
                                                .moveY(
                                                  begin: 0,
                                                  end: -PasswordChangedEntrance
                                                      .hopHeight,
                                                  duration:
                                                      PasswordChangedEntrance
                                                          .hopUp,
                                                  curve: AppMotion.out,
                                                )
                                                .then()
                                                .moveY(
                                                  begin: 0,
                                                  end: PasswordChangedEntrance
                                                      .hopHeight,
                                                  duration:
                                                      PasswordChangedEntrance
                                                          .hopDown,
                                                  curve: AppMotion.inOut,
                                                ),
                                    ),
                                  ),
                                ),
                              ),
                              const PositionedDirectional(
                                end: 1,
                                bottom: 1,
                                child: _SuccessBadge(),
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

/// The success mark on the circle's edge: it grows, then its check draws
/// itself. Under reduce motion, all of it is simply there.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  static const _size = 48.0;
  static const _ring = 4.0;
  static const _checkSize = 26.0;
  static const _growFrom = .6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduce = AppMotion.reduceMotion(context);
    final mark = colors.onPrimaryStrong;
    final badge = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.success.fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.background,
          width: _ring,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: reduce
          ? _check(1, mark)
          : const SizedBox.square(dimension: _checkSize).animate().custom(
              delay: PasswordChangedEntrance.check,
              duration: PasswordChangedEntrance.checkDraw,
              curve: AppMotion.inOut,
              builder: (_, value, _) => _check(value, mark),
            ),
    );
    return ExcludeSemantics(
      child: reduce
          ? badge
          : badge
                .animate()
                .fadeIn(
                  delay: PasswordChangedEntrance.badge,
                  duration: PasswordChangedEntrance.badgeGrow,
                  curve: AppMotion.out,
                )
                .scaleXY(begin: _growFrom, end: 1, curve: AppMotion.bounce),
    );
  }

  static Widget _check(double progress, Color color) => CustomPaint(
    size: const Size.square(_checkSize),
    painter: _CheckPainter(progress: progress, color: color),
  );
}

/// The check of the app's icons (`AppIcon.check`), drawn up to [progress].
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _viewBox = 24.0;
  static const _stroke = 2.8;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _viewBox);
    final check = Path()
      ..moveTo(5, 12.5)
      ..lineTo(9.5, 17)
      ..lineTo(19, 7.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final metric = check.computeMetrics().single;
    if (progress > 0) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
