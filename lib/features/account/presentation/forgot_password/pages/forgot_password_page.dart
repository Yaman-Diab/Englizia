import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_text_field.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/features/account/presentation/forgot_password/cubit/forgot_password_cubit.dart';
import 'package:englizia/features/account/presentation/widgets/auth_layout.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Forgot your password?" (requirements v3.0 §5.2 step 1, design "Forgot
/// Password"): the guide holds a key over one email field, already filled
/// from sign-in when it was typed there (no keyboard opens by itself), and
/// a line for Google users, who need no password. "Send the link" waits
/// for a complete email; once sent, the button shows a check for a moment
/// and the next step, "check your email", follows.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    required this.onSent,
    required this.onGoogle,
    required this.onBack,
    super.key,
  });

  /// The link was asked for: opens "check your email" with the address,
  /// and completes when the learner comes back.
  final Future<void> Function(String email) onSent;

  /// Back to sign-in, where Google is.
  final VoidCallback onGoogle;
  final VoidCallback onBack;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final _email = TextEditingController(
    text: context.read<ForgotPasswordCubit>().state.email,
  );
  final _focus = FocusNode();

  static const _mascotSize = 80.0;
  static const _hintIconSize = 16.0;

  /// The check stays on the button this long before the next step (design:
  /// 150 ms to appear, 400 ms held).
  static const _doneHold = AppMotion.verySlow;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) context.read<ForgotPasswordCubit>().left();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<ForgotPasswordCubit>().submit();
  }

  Future<void> _moveOn(String email) async {
    await Future<void>.delayed(_doneHold);
    if (!mounted) return;
    await widget.onSent(email.trim());
    if (mounted) context.read<ForgotPasswordCubit>().reopened();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
          listenWhen: (before, now) => now.sent && !before.sent,
          listener: (_, state) => _moveOn(state.email),
        ),
        BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
          listenWhen: (before, now) =>
              now.failure != null && now.failure != before.failure,
          listener: (context, state) => showFailureSnackBar(
            context,
            state.failure!,
            onRetry: context.read<ForgotPasswordCubit>().submit,
          ),
        ),
      ],
      child: BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
        builder: _build,
      ),
    );
  }

  Widget _build(BuildContext context, ForgotPasswordState state) {
    final cubit = context.read<ForgotPasswordCubit>();
    final colors = context.colors;
    final texts = context.texts;
    final busy = state.sending || state.sent;

    return PopScope(
      canPop: !busy,
      child: AuthScaffold(
        onBack: busy ? null : widget.onBack,
        footer: AuthFooter(
          keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
          submit: AppButton(
            label: 'forgot_submit'.tr(),
            size: AppButtonSize.large,
            isLoading: state.sending,
            isDone: state.sent,
            onPressed: state.canSubmit ? _submit : null,
          ),
        ),
        body: Column(
          children: [
            const Entrance(
              motion: EntranceMotion.pop,
              delay: FormEntrance.header,
              child: Mascot(
                expression: MascotExpression.focused,
                prop: MascotProp.key,
                size: _mascotSize,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              motion: EntranceMotion.up,
              delay: FormEntrance.header,
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'sign_in_forgot'.tr(),
                      textAlign: TextAlign.center,
                      style: texts.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'forgot_body'.tr(),
                    textAlign: TextAlign.center,
                    style: texts.body.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Entrance(
              motion: EntranceMotion.up,
              delay: FormEntrance.field(0),
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: AppTextField(
                  label: 'account_field_email'.tr(),
                  icon: AppIcon.mail,
                  controller: _email,
                  focusNode: _focus,
                  readOnly: busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.email],
                  message: state.showsError
                      ? FieldMessage(
                          'forgot_email_invalid'.tr(
                            namedArgs: {
                              'example':
                                  '${Unicode.LRI}name@gmail.com${Unicode.PDI}',
                            },
                          ),
                          FieldMessageTone.error,
                        )
                      : null,
                  onChanged: cubit.changed,
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              motion: EntranceMotion.up,
              delay: FormEntrance.field(1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.xxs,
                    ),
                    child: AppIconView(
                      AppIcon.infoCircle,
                      size: _hintIconSize,
                      color: colors.info.fill,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'forgot_google_hint'.tr(),
                          style: texts.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : widget.onGoogle,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            minimumSize: const Size(0, AppSizes.minTapTarget),
                          ),
                          child: Text('forgot_google'.tr()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
