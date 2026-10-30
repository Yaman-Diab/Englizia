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
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/entities/social_provider.dart';
import 'package:englizia/features/account/presentation/sign_in/cubit/sign_in_cubit.dart';
import 'package:englizia/features/account/presentation/sign_in/widgets/social_sign_in.dart';
import 'package:englizia/features/account/presentation/widgets/account_notice.dart';
import 'package:englizia/features/account/presentation/widgets/auth_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sign-in (requirements v3.0 §5.1, design "Login v2"): Google (and Apple
/// on iOS) first as equal ways, the last one used badged, then email and
/// password. While a field is in use the providers and the line under the
/// title fold away and the guide shrinks; it covers its eyes over the
/// password and peeks when it is shown. A refused try keeps the email,
/// clears the password and shakes it; too many tries count the server's
/// wait down on the button.
class SignInPage extends StatefulWidget {
  const SignInPage({
    required this.onSignedIn,
    required this.onProvider,
    required this.onForgotPassword,
    required this.onCreateAccount,
    required this.onBack,
    this.lastProvider,
    super.key,
  });

  /// Signed in: the session, not started yet.
  final ValueChanged<AuthTokens> onSignedIn;
  final ValueChanged<SocialProvider> onProvider;

  /// Opens password recovery with the email typed so far.
  final ValueChanged<String> onForgotPassword;
  final VoidCallback onCreateAccount;
  final VoidCallback onBack;

  /// The provider used last on this phone, badged «آخر دخول لك».
  final SocialProvider? lastProvider;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  late final _email = TextEditingController(
    text: context.read<SignInCubit>().state.email,
  );
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _passwordHidden = true;

  static const _mascotSize = 80.0;

  @override
  void initState() {
    super.initState();
    for (final node in [_emailFocus, _passwordFocus]) {
      node.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<SignInCubit>().submit();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SignInCubit, SignInState>(
          listenWhen: (before, now) =>
              now.session != null && before.session == null,
          listener: (_, state) {
            TextInput.finishAutofillContext();
            widget.onSignedIn(state.session!);
          },
        ),
        // A refused try: the password is cleared and typed again.
        BlocListener<SignInCubit, SignInState>(
          listenWhen: (before, now) => now.wrongTries != before.wrongTries,
          listener: (_, _) {
            _password.clear();
            _passwordFocus.requestFocus();
          },
        ),
        BlocListener<SignInCubit, SignInState>(
          listenWhen: (before, now) =>
              now.lockedUntil != null && before.lockedUntil == null,
          listener: (_, _) => _password.clear(),
        ),
        BlocListener<SignInCubit, SignInState>(
          listenWhen: (before, now) =>
              now.failure != null && now.failure != before.failure,
          listener: (context, state) => showFailureSnackBar(
            context,
            state.failure!,
            onRetry: context.read<SignInCubit>().submit,
          ),
        ),
      ],
      child: BlocBuilder<SignInCubit, SignInState>(builder: _build),
    );
  }

  Widget _build(BuildContext context, SignInState state) {
    final cubit = context.read<SignInCubit>();
    final focused = _emailFocus.hasFocus || _passwordFocus.hasFocus;
    final typed = state.email.isNotEmpty || state.password.isNotEmpty;
    // The error card points at the providers, so they come back with it.
    final compact = focused || typed && !state.wrongCredentials;
    final apple = Theme.of(context).platform == TargetPlatform.iOS;
    final expression = switch (state) {
      SignInState(wrongCredentials: true) ||
      SignInState(locked: true) ||
      SignInState(failure: _?) => MascotExpression.understand,
      _ when _passwordFocus.hasFocus =>
        _passwordHidden ? MascotExpression.cover : MascotExpression.peek,
      _ => MascotExpression.welcome,
    };
    final duration = AppMotion.resolve(context, AppMotion.fast);

    return PopScope(
      canPop: !state.sending,
      child: AuthScaffold(
        onBack: state.sending ? null : widget.onBack,
        footer: AuthFooter(
          keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
          submit: AppButton(
            label: state.locked
                ? 'sign_in_retry_after'.tr(
                    namedArgs: {'time': formatWait(state.waitLeft)},
                  )
                : 'sign_in_submit'.tr(),
            size: AppButtonSize.large,
            isLoading: state.sending,
            onPressed: state.canSubmit ? _submit : null,
          ),
          switchLead: 'sign_in_no_account'.tr(),
          switchAction: 'account_guest_create'.tr(),
          onSwitch: state.sending ? null : widget.onCreateAccount,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              title: 'sign_in_title'.tr(),
              subtitle: 'sign_in_subtitle'.tr(),
              expression: expression,
              waving: expression == MascotExpression.welcome && !compact,
              compact: compact,
              mascotSize: _mascotSize,
            ),
            // Folded, not removed: the providers keep their place in the
            // tree, so they unfold without replaying their entrance.
            TweenAnimationBuilder<double>(
              tween: Tween(end: compact ? 0 : 1),
              duration: duration,
              curve: AppMotion.out,
              builder: (context, open, child) => ClipRect(
                child: Align(
                  alignment: AlignmentDirectional.topCenter,
                  heightFactor: open,
                  child: Opacity(opacity: open, child: child),
                ),
              ),
              child: ExcludeFocus(
                excluding: compact,
                child: ExcludeSemantics(
                  excluding: compact,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.xl,
                    ),
                    child: Entrance(
                      motion: EntranceMotion.up,
                      delay: FormEntrance.field(0),
                      child: SocialSignIn(
                        apple: apple,
                        lastProvider: widget.lastProvider,
                        onProvider: state.sending || compact
                            ? null
                            : widget.onProvider,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: duration,
              curve: AppMotion.out,
              alignment: AlignmentDirectional.topCenter,
              child: switch (state) {
                SignInState(locked: true) => Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
                  child: AccountNotice(
                    icon: AppIcon.clock,
                    title: 'sign_in_locked'.tr(),
                    announcement: 'sign_in_locked_minutes'.plural(
                      (state.waitLeft.inSeconds / 60).ceil(),
                    ),
                  ),
                ),
                SignInState(wrongCredentials: true) => Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
                  child: AccountNotice(
                    icon: AppIcon.errorCircle,
                    error: true,
                    title: 'sign_in_wrong'.tr(),
                    detail: apple
                        ? 'sign_in_wrong_hint_both'.tr()
                        : 'sign_in_wrong_hint_google'.tr(),
                  ),
                ),
                _ => const SizedBox(width: double.infinity),
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Entrance(
                    motion: EntranceMotion.up,
                    delay: FormEntrance.field(1),
                    child: AppTextField(
                      label: 'account_field_email'.tr(),
                      icon: AppIcon.mail,
                      controller: _email,
                      focusNode: _emailFocus,
                      readOnly: state.sending,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.email],
                      onChanged: cubit.emailChanged,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                  Entrance(
                    motion: EntranceMotion.up,
                    delay: FormEntrance.field(2),
                    child: AppTextField(
                      label: 'account_field_password'.tr(),
                      icon: AppIcon.lock,
                      controller: _password,
                      focusNode: _passwordFocus,
                      readOnly: state.sending,
                      obscurable: true,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.password],
                      shakeTrigger: state.wrongTries,
                      onChanged: cubit.passwordChanged,
                      onObscuredChanged: (hidden) =>
                          setState(() => _passwordHidden = hidden),
                      onSubmitted: (_) => state.canSubmit
                          ? _submit()
                          : FocusScope.of(context).unfocus(),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: state.sending
                    ? null
                    : () => widget.onForgotPassword(state.email.trim()),
                // The only way forward while locked: drawn stronger.
                style: TextButton.styleFrom(
                  textStyle: state.locked
                      ? context.texts.bodyStrong
                      : context.texts.body,
                ),
                child: Text('sign_in_forgot'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
