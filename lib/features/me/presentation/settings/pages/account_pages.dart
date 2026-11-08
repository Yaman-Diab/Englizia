import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_text_field.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/presentation/settings/cubit/preferences_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A wrong password is said under its field; anything else in the band.
bool _wrongPassword(Failure failure, String field) =>
    failure is ValidationFailure && failure.firstCodeFor(field) != null;

/// «كلمة المرور»: the current one, the new one with its rule in sight, and
/// «حفظ» once both are there.
class PasswordPage extends StatefulWidget {
  const PasswordPage({required this.onBack, required this.onSaved, super.key});

  final VoidCallback onBack;

  /// Back to the settings, which say it was saved.
  final VoidCallback onSaved;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  var _wrong = false;

  bool get _ruleMet => AccountRules.isPassword(_next.text);

  bool get _ready => _ruleMet && _current.text.isNotEmpty;

  Future<void> _save() async {
    if (!_ready) return;
    final failure = await context.read<PreferencesCubit>().changePassword(
      _current.text,
      _next.text,
    );
    if (!mounted) return;
    if (failure == null) return widget.onSaved();
    if (_wrongPassword(failure, 'currentPassword')) {
      setState(() => _wrong = true);
    } else {
      showFailureSnackBar(context, failure);
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.select((PreferencesCubit c) => c.state.saving);
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'common_back'.tr(),
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text('settings_password'.tr()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.lg + 4,
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.lg,
          ),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'settings_current_password'.tr(),
                  icon: AppIcon.lock,
                  controller: _current,
                  obscurable: true,
                  readOnly: saving,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.password],
                  message: _wrong
                      ? FieldMessage(
                          'settings_password_wrong'.tr(),
                          FieldMessageTone.error,
                        )
                      : null,
                  onChanged: (_) => setState(() => _wrong = false),
                ),
                const SizedBox(height: AppSpacing.lg + 4),
                AppTextField(
                  label: 'settings_new_password'.tr(),
                  icon: AppIcon.lock,
                  controller: _next,
                  obscurable: true,
                  readOnly: saving,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  message: FieldMessage(
                    'account_password_rule'.plural(
                      AccountRules.passwordMinLength,
                    ),
                    _ruleMet ? FieldMessageTone.success : FieldMessageTone.hint,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
                const Spacer(),
                AppButton(
                  label: 'common_save'.tr(),
                  isLoading: saving,
                  onPressed: _ready ? _save : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «حذف الحساب»: what will go first, then the password (or signing in again)
/// to confirm, then the account is gone.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    required this.signIn,
    required this.onBack,
    required this.onReauthenticate,
    required this.onDone,
    super.key,
  });

  final SignInMethod signIn;
  final VoidCallback onBack;

  /// Signs in again with Google or Apple; true once it did.
  final Future<bool> Function() onReauthenticate;

  /// «العودة إلى البداية»: the session ends.
  final VoidCallback onDone;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

enum _Step { warn, confirm, deleted }

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _password = TextEditingController();
  var _step = _Step.warn;
  var _wrong = false;
  var _reauthenticated = false;

  bool get _withPassword => widget.signIn == SignInMethod.email;

  bool get _ready =>
      _withPassword ? _password.text.isNotEmpty : _reauthenticated;

  Future<void> _delete() async {
    if (!_ready) return;
    final failure = await context.read<PreferencesCubit>().deleteAccount(
      password: _withPassword ? _password.text : null,
    );
    if (!mounted) return;
    if (failure == null) return setState(() => _step = _Step.deleted);
    if (_wrongPassword(failure, 'password')) {
      setState(() => _wrong = true);
    } else {
      showFailureSnackBar(context, failure);
    }
  }

  Future<void> _reauthenticate() async {
    final done = await widget.onReauthenticate();
    if (mounted) setState(() => _reauthenticated = done);
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final saving = context.select((PreferencesCubit c) => c.state.saving);
    return PopScope(
      canPop: _step == _Step.warn,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _step == _Step.confirm) {
          setState(() => _step = _Step.warn);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: _step == _Step.deleted
            ? null
            : AppBar(
                leading: IconButton(
                  tooltip: 'common_back'.tr(),
                  onPressed: _step == _Step.warn
                      ? widget.onBack
                      : () => setState(() => _step = _Step.warn),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: Text(
                  _step == _Step.warn
                      ? 'settings_delete'.tr()
                      : 'settings_delete_confirm'.tr(),
                ),
              ),
        body: SafeArea(
          child: switch (_step) {
            _Step.warn => _warning(context),
            _Step.confirm => _confirming(context, saving),
            _Step.deleted => _deleted(context),
          },
        ),
      ),
    );
  }

  Widget _warning(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        28,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.error.surface,
                shape: BoxShape.circle,
              ),
              child: AppIconView(
                AppIcon.errorCircle,
                size: 32,
                color: colors.error.fill,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              'settings_delete_title'.tr(),
              textAlign: TextAlign.center,
              style: texts.title,
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 4),
          Text(
            'settings_delete_will'.tr(),
            style: texts.bodyStrong.copyWith(fontSize: 14, height: 22 / 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in [
            'settings_delete_progress'.tr(),
            'settings_delete_words'.tr(),
            'settings_delete_tests'.tr(),
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(child: Text(line, style: texts.body)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('settings_delete_no_undo'.tr(), style: texts.bodyStrong),
          const Spacer(),
          AppButton(label: 'common_cancel'.tr(), onPressed: widget.onBack),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => setState(() => _step = _Step.confirm),
            style: TextButton.styleFrom(
              foregroundColor: colors.error.text,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text('settings_delete_continue'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _confirming(BuildContext context, bool saving) {
    final colors = context.colors;
    final provider = widget.signIn == SignInMethod.apple
        ? 'settings_apple'.tr()
        : 'settings_google'.tr();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_withPassword)
            AppTextField(
              label: 'settings_delete_type'.tr(),
              icon: AppIcon.lock,
              controller: _password,
              obscurable: true,
              readOnly: saving,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              message: _wrong
                  ? FieldMessage(
                      'settings_password_wrong'.tr(),
                      FieldMessageTone.error,
                    )
                  : null,
              onChanged: (_) => setState(() => _wrong = false),
            )
          else ...[
            Text(
              'settings_delete_reauth'.tr(),
              style: context.texts.bodyStrong.copyWith(
                fontSize: 14,
                height: 22 / 14,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'settings_delete_with'.tr(args: [provider]),
              variant: AppButtonVariant.secondary,
              isDone: _reauthenticated,
              onPressed: _reauthenticated ? null : _reauthenticate,
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: _ready && !saving ? _delete : null,
            style: FilledButton.styleFrom(
              backgroundColor: colors.error.fill,
              foregroundColor: colors.surface,
              minimumSize: const Size.fromHeight(AppSizes.minTapTarget + 8),
            ),
            child: Text('settings_delete_button'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _deleted(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Mascot(
            expression: MascotExpression.understand,
            size: 160,
            sparkles: false,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            'settings_delete_done'.tr(),
            textAlign: TextAlign.center,
            style: context.texts.title,
          ),
        ),
        const SizedBox(height: 28),
        AppButton(
          label: 'settings_delete_start'.tr(),
          onPressed: widget.onDone,
        ),
      ],
    ),
  );
}
