import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/design_system/widgets/app_text_field.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/presentation/new_password/cubit/new_password_cubit.dart';
import 'package:englizia/features/account/presentation/widgets/auth_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Set a new password" (requirements v3.0 §5.2 step 3, design "New
/// Password"): opened by the link in the email, so it closes instead of going
/// back. One field with no confirmation (the eye is enough to check it) and
/// its rule always in sight, never red while typing. An expired link is not
/// the learner's mistake, so it uses no error colors.
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({
    required this.onClose,
    required this.onNewLink,
    required this.onSaved,
    super.key,
  });

  final VoidCallback onClose;

  /// Opens "forgot your password" for a new link.
  final VoidCallback onNewLink;

  /// The password changed; [session] is the one the server started, if any.
  final ValueChanged<AuthTokens?> onSaved;

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _password = TextEditingController();

  static const _checkingHeight = 104.0;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _save() {
    final cubit = context.read<NewPasswordCubit>();
    FocusScope.of(context).unfocus();
    cubit.save();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NewPasswordCubit, NewPasswordState>(
          listenWhen: (before, now) => now.saved && !before.saved,
          listener: (_, state) => widget.onSaved(state.session),
        ),
        BlocListener<NewPasswordCubit, NewPasswordState>(
          listenWhen: (before, now) =>
              now.phase == NewPasswordPhase.form &&
              now.failure != null &&
              now.failure != before.failure,
          listener: (context, state) => showFailureSnackBar(
            context,
            state.failure!,
            onRetry: context.read<NewPasswordCubit>().save,
          ),
        ),
      ],
      child: BlocBuilder<NewPasswordCubit, NewPasswordState>(builder: _build),
    );
  }

  Widget _build(BuildContext context, NewPasswordState state) {
    final expired = state.phase == NewPasswordPhase.expired;
    final busy = state.saving || state.saved;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) widget.onClose();
      },
      child: AuthScaffold(
        closes: true,
        onBack: busy ? null : widget.onClose,
        footer: AuthFooter(
          keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
          submit: expired
              ? AppButton(
                  label: 'new_password_new_link'.tr(),
                  size: AppButtonSize.large,
                  onPressed: widget.onNewLink,
                )
              : AppButton(
                  label: 'new_password_submit'.tr(),
                  size: AppButtonSize.large,
                  isLoading: state.saving,
                  onPressed: state.canSave ? _save : null,
                ),
        ),
        body: Column(
          children: [
            Entrance(
              motion: EntranceMotion.pop,
              delay: FormEntrance.header,
              child: _GuideBadge(expired: expired),
            ),
            const SizedBox(height: AppSpacing.lg),
            Entrance(
              motion: EntranceMotion.up,
              delay: FormEntrance.header,
              child: expired ? const _ExpiredText() : _Heading(state.email),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (state.phase == NewPasswordPhase.verifying)
              _checking(context, state)
            else if (!expired)
              Entrance(
                motion: EntranceMotion.up,
                delay: FormEntrance.field(0),
                child: _field(context, state),
              ),
          ],
        ),
      ),
    );
  }

  /// A failed check keeps the screen with a retry; the field never shows
  /// before the link is known to be good.
  Widget _checking(BuildContext context, NewPasswordState state) {
    final failure = state.failure;
    if (failure != null) {
      return AppStateView.error(
        message: failure.localizedMessage,
        onRetry: context.read<NewPasswordCubit>().verify,
      );
    }
    return SizedBox(
      height: _checkingHeight,
      child: Center(
        child: AppSpinner(
          size: AppSpinner.pageSize,
          color: context.colors.primary.fill,
          semanticLabel: 'new_password_verifying'.tr(),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, NewPasswordState state) {
    final cubit = context.read<NewPasswordCubit>();
    return AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: AppTextField(
        label: 'new_password_field'.tr(),
        icon: AppIcon.lock,
        controller: _password,
        obscurable: true,
        readOnly: state.saving,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        textDirection: TextDirection.ltr,
        autofillHints: const [AutofillHints.newPassword],
        shakeTrigger: state.refusals,
        message: FieldMessage(
          'account_password_rule'.plural(AccountRules.passwordMinLength),
          state.refused
              ? FieldMessageTone.error
              : state.ruleMet
              ? FieldMessageTone.success
              : FieldMessageTone.hint,
        ),
        onChanged: cubit.changed,
        onSubmitted: (_) => state.ruleMet ? _save() : null,
      ),
    );
  }
}

/// The guide in its circle; an expired link adds a clock on its edge.
class _GuideBadge extends StatelessWidget {
  const _GuideBadge({required this.expired});

  final bool expired;

  static const _circle = 96.0;
  static const _guide = 80.0;
  static const _badge = 36.0;
  static const _badgeIcon = 20.0;
  static const _badgeInset = -4.0;
  static const _badgeRing = 3.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox.square(
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
              child: Center(
                child: Mascot(
                  expression: expired
                      ? MascotExpression.understand
                      : MascotExpression.focused,
                  size: _guide,
                ),
              ),
            ),
          ),
          if (expired)
            PositionedDirectional(
              end: _badgeInset,
              bottom: _badgeInset,
              child: Container(
                width: _badge,
                height: _badge,
                decoration: BoxDecoration(
                  color: colors.info.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.background,
                    width: _badgeRing,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: Center(
                  child: AppIconView(
                    AppIcon.clock,
                    size: _badgeIcon,
                    color: colors.info.fill,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The title, and whose password this is when the link says.
class _Heading extends StatelessWidget {
  const _Heading(this.email);

  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            'new_password_title'.tr(),
            textAlign: TextAlign.center,
            style: texts.title.copyWith(color: colors.textPrimary),
          ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'new_password_for'.tr(),
                style: texts.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  email,
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                  style: texts.bodyStrong.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ExpiredText extends StatelessWidget {
  const _ExpiredText();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              'new_password_expired_title'.tr(),
              textAlign: TextAlign.center,
              style: texts.title.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'new_password_expired_body'.tr(),
            textAlign: TextAlign.center,
            style: texts.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
