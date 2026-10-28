import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/account/presentation/account/cubit/account_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The account part of «أنا» (ADR 10): a guest is told the progress lives on
/// this phone only and offered an account, which upgrades the guest; signing
/// out as a guest warns first that the progress will be lost.
class AccountCard extends StatelessWidget {
  const AccountCard({required this.onCreateAccount, super.key});

  /// Opens sign-up, which upgrades the guest account.
  final VoidCallback onCreateAccount;

  static const _badgeSize = 40.0;
  static const _iconSize = 20.0;

  Future<void> _signOut(BuildContext context, AccountState state) async {
    final cubit = context.read<AccountCubit>();
    if (!state.isGuest) return cubit.signOut();
    final choice = await showActionSheet(
      context,
      icon: AppIcon.phone,
      tone: SheetTone.warning,
      title: 'account_guest_sign_out_title'.tr(),
      body: 'account_guest_sign_out_body'.tr(),
      primaryLabel: 'account_guest_create'.tr(),
      secondaryLabel: 'account_sign_out'.tr(),
      destructiveSecondary: true,
    );
    switch (choice) {
      case SheetAction.primary:
        onCreateAccount();
      case SheetAction.secondary:
        await cubit.signOut();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isGuest) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.info.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: _badgeSize,
                          height: _badgeSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: AppIconView(
                            AppIcon.phone,
                            size: _iconSize,
                            color: colors.info.text,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'account_guest_title'.tr(),
                            style: texts.bodyStrong.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'account_guest_body'.tr(),
                      style: texts.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'account_guest_create'.tr(),
                      onPressed: state.signingOut ? null : onCreateAccount,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            label: 'account_sign_out'.tr(),
            variant: state.isGuest
                ? AppButtonVariant.destructive
                : AppButtonVariant.secondary,
            isLoading: state.signingOut,
            onPressed: () => _signOut(context, state),
          ),
        ],
      ),
    );
  }
}
