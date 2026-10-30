import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/motion/hop_once.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/design_system/widgets/success_badge.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/email_link_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where the confirming link lands (requirements v3.0 §5.3, design "Verify
/// Email"): a card saying the email is confirmed, or that the link ran out,
/// which uses no error colors, as it isn't the learner's mistake.
class EmailLinkPage extends StatelessWidget {
  const EmailLinkPage({
    required this.onContinue,
    required this.onNewLink,
    super.key,
  });

  /// On to the app, also by the system's back.
  final VoidCallback onContinue;

  /// The link ran out, and the learner asks for another.
  final VoidCallback onNewLink;

  static const _dim = .32;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EmailLinkCubit>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onContinue();
      },
      child: Scaffold(
        body: ColoredBox(
          color: context.scheme.scrim.withValues(alpha: _dim),
          child: SafeArea(
            child: BlocBuilder<EmailLinkCubit, EmailLinkState>(
              builder: (context, state) => switch (state.view) {
                EmailLinkView.verifying => Center(
                  child: AppSpinner(
                    size: AppSpinner.pageSize,
                    color: context.colors.surface,
                  ),
                ),
                EmailLinkView.failed => _Card(
                  child: AppStateView.error(
                    message: state.failure!.localizedMessage,
                    onRetry: cubit.verify,
                  ),
                ),
                EmailLinkView.verified => _Card(
                  child: _Outcome(
                    expired: false,
                    title: 'verify_done'.tr(),
                    action: 'common_continue'.tr(),
                    onAction: onContinue,
                  ),
                ),
                EmailLinkView.expired => _Card(
                  child: _Outcome(
                    expired: true,
                    title: 'verify_expired'.tr(),
                    action: 'new_password_new_link'.tr(),
                    onAction: onNewLink,
                  ),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  static const _radius = 24.0;
  static const _growFrom = AppMotion.scaleLarge;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: child,
      ),
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: AppMotion.reduceMotion(context)
            ? card
            : card
                  .animate()
                  .fadeIn(
                    duration: EmailConfirmedEntrance.card,
                    curve: AppMotion.smoothOut,
                  )
                  .scaleXY(begin: _growFrom, end: 1),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.expired,
    required this.title,
    required this.action,
    required this.onAction,
  });

  final bool expired;
  final String title;
  final String action;
  final VoidCallback onAction;

  static const _sceneWidth = 176.0;
  static const _sceneHeight = 104.0;
  static const _guide = 96.0;
  static const _guideTop = 4.0;
  static const _badge = 72.0;
  static const _badgeTop = 16.0;
  static const _inset = 12.0;
  static const _checkSize = 38.0;
  static const _clockSize = 36.0;
  static const _ring = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final guide = Mascot(
      expression: expired
          ? MascotExpression.understand
          : MascotExpression.happy,
      sparkles: false,
      size: _guide,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: _sceneWidth,
            height: _sceneHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PositionedDirectional(
                  end: _inset,
                  top: _guideTop,
                  child: expired
                      ? guide
                      : HopOnce(
                          delay: EmailConfirmedEntrance.hop,
                          child: guide,
                        ),
                ),
                PositionedDirectional(
                  start: _inset,
                  top: _badgeTop,
                  child: expired
                      ? Container(
                          width: _badge,
                          height: _badge,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.info.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: _ring,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            ),
                          ),
                          child: AppIconView(
                            AppIcon.clock,
                            size: _clockSize,
                            color: colors.info.fill,
                          ),
                        )
                      : SuccessBadge(
                          size: _badge,
                          checkSize: _checkSize,
                          ringColor: colors.surface,
                          growDelay: EmailConfirmedEntrance.badge,
                          checkDelay: EmailConfirmedEntrance.check,
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          liveRegion: true,
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.texts.title.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: action,
          size: AppButtonSize.large,
          onPressed: onAction,
        ),
      ],
    );
  }
}
