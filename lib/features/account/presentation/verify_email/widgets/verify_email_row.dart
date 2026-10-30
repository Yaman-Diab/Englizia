import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The email in the account section of «أنا», with its badge. Until confirmed
/// it opens the sheet; after that there is nothing to do, so no arrow either.
class VerifyEmailRow extends StatelessWidget {
  const VerifyEmailRow({super.key});

  static const _minHeight = 64.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
      builder: (context, state) {
        if (!state.applies) return const SizedBox.shrink();
        final verified = state.verified;
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
          child: Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: colors.border),
            ),
            child: InkWell(
              onTap: verified ? null : () => showVerifyEmailSheet(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minHeight),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      AppIconView(
                        AppIcon.mail,
                        size: _iconSize,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.email!,
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.body.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            AnimatedSwitcher(
                              duration: AppMotion.resolve(
                                context,
                                AppMotion.quick,
                              ),
                              switchInCurve: AppMotion.smoothOut,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: Tween<double>(
                                      begin: AppMotion.scaleMark,
                                      end: 1,
                                    ).animate(animation),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                              child: _Badge(
                                key: ValueKey(verified),
                                verified: verified,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!verified)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textSecondary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.verified, super.key});

  final bool verified;

  static const _height = 22.0;
  static const _checkSize = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = verified ? colors.success : colors.info;
    return Container(
      height: _height,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verified) ...[
            AppIconView(AppIcon.check, size: _checkSize, color: tone.fill),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            verified
                ? 'account_email_verified'.tr()
                : 'account_email_unverified'.tr(),
            style: context.texts.captionStrong.copyWith(color: tone.text),
          ),
        ],
      ),
    );
  }
}
