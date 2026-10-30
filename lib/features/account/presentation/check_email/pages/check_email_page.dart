import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/illustrations/mail_scene.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/features/account/presentation/check_email/cubit/check_email_cubit.dart';
import 'package:englizia/features/account/presentation/widgets/account_notice.dart';
import 'package:englizia/features/account/presentation/widgets/auth_layout.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Check your email" (requirements v3.0 §5.2 step 2, design "Check
/// Email"): never confirms that the account exists. Opens the mail app, and
/// sends the link again after a wait counted down on the button. "Change"
/// and back return to the email field.
class CheckEmailPage extends StatelessWidget {
  const CheckEmailPage({required this.onChange, super.key});

  /// Back to the email field, with the email in it.
  final VoidCallback onChange;

  static const _noMailAppFor = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return MultiBlocListener(
      listeners: [
        BlocListener<CheckEmailCubit, CheckEmailState>(
          listenWhen: (before, now) => now.resent != before.resent,
          listener: (context, _) => showNoticeSnackBar(
            context,
            icon: AppIcon.checkCircle,
            text: 'check_email_resent'.tr(),
            tone: context.colors.success,
          ),
        ),
        BlocListener<CheckEmailCubit, CheckEmailState>(
          listenWhen: (before, now) => now.noMailApp != before.noMailApp,
          listener: (context, _) => showNoticeSnackBar(
            context,
            icon: AppIcon.infoCircle,
            text: 'check_email_no_mail_app'.tr(),
            tone: context.colors.info,
            duration: _noMailAppFor,
          ),
        ),
        BlocListener<CheckEmailCubit, CheckEmailState>(
          listenWhen: (before, now) =>
              now.failure != null && now.failure != before.failure,
          listener: (context, state) => showFailureSnackBar(
            context,
            state.failure!,
            onRetry: context.read<CheckEmailCubit>().resend,
          ),
        ),
      ],
      child: BlocBuilder<CheckEmailCubit, CheckEmailState>(
        builder: (context, state) {
          final cubit = context.read<CheckEmailCubit>();
          return AuthScaffold(
            onBack: onChange,
            footer: AuthFooter(
              keyboardOpen: false,
              submit: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'check_email_open'.tr(),
                    icon: Icons.mail_outline_rounded,
                    size: AppButtonSize.large,
                    onPressed: cubit.openMailApp,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: state.waiting
                        ? 'check_email_resend_after'.tr(
                            namedArgs: {'time': formatWait(state.waitLeft)},
                          )
                        : 'check_email_resend'.tr(),
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.large,
                    isLoading: state.resending,
                    onPressed: state.canResend ? cubit.resend : null,
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                const MailScene(),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    'check_email_title'.tr(),
                    textAlign: TextAlign.center,
                    style: texts.title.copyWith(color: colors.textPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'check_email_body'.tr(),
                  textAlign: TextAlign.center,
                  style: texts.body.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        state.email,
                        textDirection: TextDirection.ltr,
                        overflow: TextOverflow.ellipsis,
                        style: texts.bodyStrong.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    TextButton(
                      onPressed: onChange,
                      child: Text('check_email_change'.tr()),
                    ),
                  ],
                ),
                Text(
                  'check_email_valid'.tr(),
                  textAlign: TextAlign.center,
                  style: texts.caption.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                AccountNotice(
                  icon: AppIcon.infoCircle,
                  title: 'check_email_spam'.tr(
                    namedArgs: {'spam': '${Unicode.LRI}(Spam)${Unicode.PDI}'},
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
