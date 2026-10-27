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
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/presentation/sign_up/cubit/sign_up_cubit.dart';
import 'package:englizia/features/account/presentation/sign_up/widgets/email_suggestions.dart';
import 'package:englizia/features/account/presentation/sign_up/widgets/email_taken_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Create your account" with email (requirements v3.0 §4.3, design
/// "Create Account v2" with the v3 behavior notes): name, email and
/// password with the guide alongside. Errors show when a field is left or
/// the form is sent, never while typing; a refused send shakes the wrong
/// fields and focuses the first. An email with an account offers sign-in
/// instead, and a failed connection keeps what was typed with a retry.
class SignUpPage extends StatefulWidget {
  const SignUpPage({required this.onSignIn, required this.onBack, super.key});

  /// Opens sign-in with the email typed so far (may be empty).
  final ValueChanged<String> onSignIn;
  final VoidCallback onBack;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  late final Map<SignUpField, TextEditingController> _text = {
    for (final field in SignUpField.values) field: TextEditingController(),
  };
  late final Map<SignUpField, FocusNode> _focus = {
    for (final field in SignUpField.values)
      field: FocusNode()..addListener(() => _onFocus(field)),
  };

  static const _mascotSize = 68.0;
  static const _fieldGap = AppSpacing.lg + AppSpacing.xxs;

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onFocus(SignUpField field) {
    if (!_focus[field]!.hasFocus) context.read<SignUpCubit>().left(field);
    // The footer swaps the sign-in link for domain suggestions.
    setState(() {});
  }

  void _next(SignUpField field) {
    final next = field.index + 1;
    if (next < SignUpField.values.length) {
      _focus[SignUpField.values[next]]!.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<SignUpCubit>().submit();
  }

  void _pickEmail(String email) {
    _text[SignUpField.email]!.value = TextEditingValue(
      text: email,
      selection: TextSelection.collapsed(offset: email.length),
    );
    context.read<SignUpCubit>().changed(SignUpField.email, email);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SignUpCubit, SignUpState>(
          listenWhen: (before, now) => now.created && !before.created,
          listener: (_, _) => TextInput.finishAutofillContext(),
        ),
        // A refused send: the first wrong field takes the focus.
        BlocListener<SignUpCubit, SignUpState>(
          listenWhen: (before, now) =>
              now.shakes != before.shakes && now.invalid.isNotEmpty,
          listener: (_, state) => _focus[state.invalid.first]!.requestFocus(),
        ),
        BlocListener<SignUpCubit, SignUpState>(
          listenWhen: (before, now) =>
              now.failure != null && now.failure != before.failure,
          listener: (context, state) => showFailureSnackBar(
            context,
            state.failure!,
            onRetry: context.read<SignUpCubit>().submit,
          ),
        ),
      ],
      child: BlocBuilder<SignUpCubit, SignUpState>(builder: _build),
    );
  }

  Widget _build(BuildContext context, SignUpState state) {
    final cubit = context.read<SignUpCubit>();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final expression = _expressionFor(state);
    return PopScope(
      canPop: !state.sending,
      child: Scaffold(
        // The footer rides on the keyboard itself, so the body shrinks
        // above it and a snack bar floats over the button, not on it.
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
              child: _Footer(
                keyboardOpen: keyboardOpen,
                suggestions: _focus[SignUpField.email]!.hasFocus
                    ? EmailSuggestions(email: state.email, onPick: _pickEmail)
                    : null,
                submit: AppButton(
                  label: 'account_create_submit'.tr(),
                  size: AppButtonSize.large,
                  isLoading: state.sending,
                  onPressed: state.canSubmit ? _submit : null,
                ),
                onSignIn: state.sending
                    ? null
                    : () => widget.onSignIn(state.email.trim()),
              ),
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(onBack: state.sending ? null : widget.onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.lg + AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Entrance(
                        motion: EntranceMotion.up,
                        delay: FormEntrance.header,
                        child: _Header(
                          expression: expression,
                          waving: expression == MascotExpression.welcome,
                        ),
                      ),
                      AnimatedSize(
                        duration: AppMotion.resolve(context, AppMotion.medium),
                        curve: AppMotion.smoothOut,
                        alignment: AlignmentDirectional.topCenter,
                        child: state.emailTaken
                            ? Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  top: AppSpacing.lg + AppSpacing.xs,
                                ),
                                child: EmailTakenCard(
                                  onSignIn: () =>
                                      widget.onSignIn(state.email.trim()),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AutofillGroup(
                        onDisposeAction: AutofillContextAction.cancel,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final field in SignUpField.values) ...[
                              if (field.index > 0)
                                const SizedBox(height: _fieldGap),
                              Entrance(
                                motion: EntranceMotion.up,
                                delay: FormEntrance.field(field.index),
                                child: _field(field, state, cubit),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(SignUpField field, SignUpState state, SignUpCubit cubit) {
    final error = state.showsError(field);
    final (label, icon) = switch (field) {
      SignUpField.name => ('account_field_name'.tr(), AppIcon.person),
      SignUpField.email => ('account_field_email'.tr(), AppIcon.mail),
      SignUpField.password => ('account_field_password'.tr(), AppIcon.lock),
    };
    final message = switch (field) {
      SignUpField.name when error => FieldMessage(
        'account_name_invalid'.tr(),
        FieldMessageTone.error,
      ),
      SignUpField.email when error => FieldMessage(
        'account_email_invalid'.tr(),
        FieldMessageTone.error,
      ),
      SignUpField.password => FieldMessage(
        'account_password_rule'.plural(AccountRules.passwordMinLength),
        error
            ? FieldMessageTone.error
            : AccountRules.isPassword(state.password)
            ? FieldMessageTone.success
            : FieldMessageTone.hint,
      ),
      _ => null,
    };
    final last = field == SignUpField.password;
    return AppTextField(
      label: label,
      icon: icon,
      controller: _text[field]!,
      focusNode: _focus[field],
      message: message,
      readOnly: state.sending,
      obscurable: last,
      shakeTrigger: state.shakes[field],
      onChanged: (value) => cubit.changed(field, value),
      onSubmitted: (_) => _next(field),
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      textDirection: field == SignUpField.name ? null : TextDirection.ltr,
      maxLength: field == SignUpField.name ? AccountRules.nameMaxLength : null,
      textCapitalization: field == SignUpField.name
          ? TextCapitalization.words
          : TextCapitalization.none,
      keyboardType: switch (field) {
        SignUpField.name => TextInputType.name,
        SignUpField.email => TextInputType.emailAddress,
        SignUpField.password => TextInputType.visiblePassword,
      },
      autofillHints: switch (field) {
        SignUpField.name => const [AutofillHints.name],
        SignUpField.email => const [AutofillHints.email],
        SignUpField.password => const [AutofillHints.newPassword],
      },
    );
  }

  /// The guide keeps the learner company: waving at first, encouraging
  /// after a mistake, curious about a known email, focused while sending.
  static MascotExpression _expressionFor(SignUpState state) => switch (state) {
    SignUpState(sending: true) => MascotExpression.focused,
    SignUpState(emailTaken: true) => MascotExpression.curious,
    _ when SignUpField.values.any(state.showsError) =>
      MascotExpression.encourage,
    _ => MascotExpression.welcome,
  };
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  /// Null while the account is being created.
  final VoidCallback? onBack;

  static const _height = 56.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _height,
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
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.expression, required this.waving});

  final MascotExpression expression;
  final bool waving;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'account_create_title'.tr(),
                  style: texts.display.copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'account_create_subtitle'.tr(),
                style: texts.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Mascot(
          expression: expression,
          waving: waving,
          size: _SignUpPageState._mascotSize,
        ),
      ],
    );
  }
}

/// The send button, with the domain suggestions above it while the email
/// is typed, and "have an account? sign in" under it while the keyboard is
/// closed (the keyboard would hide it).
class _Footer extends StatelessWidget {
  const _Footer({
    required this.keyboardOpen,
    required this.suggestions,
    required this.submit,
    required this.onSignIn,
  });

  final bool keyboardOpen;
  final Widget? suggestions;
  final Widget submit;
  final VoidCallback? onSignIn;

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
              if (keyboardOpen && suggestions != null) suggestions!,
              submit,
              if (!keyboardOpen) ...[
                const SizedBox(height: AppSpacing.xxs),
                TextButton(
                  onPressed: onSignIn,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'account_have_account'.tr(),
                          style: texts.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: 'account_sign_in'.tr(),
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
