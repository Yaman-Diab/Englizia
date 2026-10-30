import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/illustrations/mail_scene.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_text_field.dart';
import 'package:englizia/core/design_system/widgets/notice_card.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the sheet over [context], sharing its [VerifyEmailCubit], so the wait
/// to resend goes on between openings.
Future<void> showVerifyEmailSheet(BuildContext context) {
  final cubit = context.read<VerifyEmailCubit>()..sheetOpened();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: sheetAnimation(context),
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const VerifyEmailSheet()),
  );
}

/// Confirming the email (requirements v3.0 §5.3, design "Verify Email"): the
/// mail app, the link again after a wait, and correcting the address. Closes by
/// itself when the email is confirmed elsewhere. Its messages live inside it, as
/// a snack bar would lie under it.
class VerifyEmailSheet extends StatefulWidget {
  const VerifyEmailSheet({super.key});

  @override
  State<VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends State<VerifyEmailSheet> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  static const _sceneWidth = 120.0;
  static const _sceneHeight = 108.0;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The current address comes selected, to be typed over.
  void _startEditing(VerifyEmailState state) {
    _field
      ..text = state.draft
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: state.draft.length,
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<VerifyEmailCubit, VerifyEmailState>(
          listenWhen: (before, now) => now.verified && !before.verified,
          listener: (context, _) => Navigator.of(context).pop(),
        ),
        BlocListener<VerifyEmailCubit, VerifyEmailState>(
          listenWhen: (before, now) =>
              before.mode != now.mode && now.mode == VerifyEmailMode.edit,
          listener: (_, state) => _startEditing(state),
        ),
      ],
      child: BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
        builder: (context, state) {
          final colors = context.colors;
          final texts = context.texts;
          final editing = state.mode == VerifyEmailMode.edit;
          return Padding(
            padding: EdgeInsetsDirectional.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: SizedBox(
                      width: _sceneWidth,
                      height: _sceneHeight,
                      child: FittedBox(child: MailScene()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      'verify_title'.tr(),
                      textAlign: TextAlign.center,
                      style: texts.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Fade(
                    id: state.mode,
                    child: editing
                        ? _EditPart(state: state, field: _field, focus: _focus)
                        : _ViewPart(state: state),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSize(
                    duration: AppMotion.resolve(context, AppMotion.fast),
                    curve: AppMotion.smoothOut,
                    alignment: AlignmentDirectional.bottomCenter,
                    child: _Message(state: state),
                  ),
                  _Fade(
                    id: state.mode,
                    child: editing
                        ? _EditButtons(state: state)
                        : _ViewButtons(state: state),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A crossfade between the sheet's two modes.
class _Fade extends StatelessWidget {
  const _Fade({required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.resolve(context, AppMotion.quick),
    child: KeyedSubtree(key: ValueKey(id), child: child),
  );
}

class _ViewPart extends StatelessWidget {
  const _ViewPart({required this.state});

  final VerifyEmailState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Column(
      children: [
        Text(
          'verify_sent_to'.tr(),
          textAlign: TextAlign.center,
          style: texts.body.copyWith(color: colors.textSecondary),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                state.email ?? '',
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: texts.bodyStrong.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: context.read<VerifyEmailCubit>().startEditing,
              child: Text('verify_correct'.tr()),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditPart extends StatelessWidget {
  const _EditPart({
    required this.state,
    required this.field,
    required this.focus,
  });

  final VerifyEmailState state;
  final TextEditingController field;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VerifyEmailCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'verify_edit_body'.tr(),
          textAlign: TextAlign.center,
          style: context.texts.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        if (state.taken) ...[
          const SizedBox(height: AppSpacing.md),
          NoticeCard(icon: AppIcon.infoCircle, title: 'verify_taken'.tr()),
        ],
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'account_field_email'.tr(),
          icon: AppIcon.mail,
          controller: field,
          focusNode: focus,
          readOnly: state.sending != null,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          textDirection: TextDirection.ltr,
          autofillHints: const [AutofillHints.email],
          message: state.showsFieldError
              ? FieldMessage(
                  'forgot_email_invalid'.tr(
                    namedArgs: {
                      'example': '${Unicode.LRI}name@gmail.com${Unicode.PDI}',
                    },
                  ),
                  FieldMessageTone.error,
                )
              : null,
          onChanged: cubit.draftChanged,
          onSubmitted: (_) => cubit.change(),
        ),
      ],
    );
  }
}

/// What just happened: a link on its way, no mail app, or a failure to retry.
class _Message extends StatelessWidget {
  const _Message({required this.state});

  final VerifyEmailState state;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    final notice = state.notice;
    final card = failure != null
        ? NoticeCard(
            icon: failure is NetworkFailure
                ? AppIcon.wifiOff
                : AppIcon.errorCircle,
            error: true,
            title: failure is NetworkFailure
                ? 'verify_send_failed'.tr()
                : failure.localizedMessage,
            trailing: TextButton(
              onPressed: context.read<VerifyEmailCubit>().retry,
              child: Text('common_retry'.tr()),
            ),
          )
        : switch (notice) {
            VerifyEmailNotice.sent => NoticeCard(
              icon: AppIcon.checkCircle,
              success: true,
              title: 'check_email_resent'.tr(),
            ),
            VerifyEmailNotice.noMailApp => NoticeCard(
              icon: AppIcon.infoCircle,
              title: 'check_email_no_mail_app'.tr(),
            ),
            null => null,
          };
    if (card == null) return const SizedBox(width: double.infinity);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: card,
    );
  }
}

class _ViewButtons extends StatelessWidget {
  const _ViewButtons({required this.state});

  final VerifyEmailState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VerifyEmailCubit>();
    final colors = context.colors;
    return Column(
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
          isLoading: state.sending == VerifyEmailAction.resend,
          onPressed: state.canResend ? cubit.resend : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'check_email_spam'.tr(
            namedArgs: {'spam': '${Unicode.LRI}(Spam)${Unicode.PDI}'},
          ),
          textAlign: TextAlign.center,
          style: context.texts.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _EditButtons extends StatelessWidget {
  const _EditButtons({required this.state});

  final VerifyEmailState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VerifyEmailCubit>();
    final busy = state.sending != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'verify_send_new'.tr(),
          size: AppButtonSize.large,
          isLoading: state.sending == VerifyEmailAction.change,
          onPressed: cubit.change,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'common_cancel'.tr(),
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.large,
          onPressed: busy ? null : cubit.cancelEditing,
        ),
      ],
    );
  }
}
