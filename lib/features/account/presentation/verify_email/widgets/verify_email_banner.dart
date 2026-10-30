import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The reminder on home: slides in a moment after home has loaded, pushing down
/// what is under it, and folds away when hidden or once the email is confirmed.
class VerifyEmailBanner extends StatefulWidget {
  const VerifyEmailBanner({super.key});

  @override
  State<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends State<VerifyEmailBanner> {
  Timer? _appear;
  bool _appeared = false;

  void _follow(VerifyEmailState state) {
    if (!state.showsReminder || _appeared || _appear != null) return;
    _appear = Timer(
      AppMotion.reduceMotion(context)
          ? Duration.zero
          : EmailReminderEntrance.delay,
      () {
        if (mounted) setState(() => _appeared = true);
      },
    );
  }

  @override
  void dispose() {
    _appear?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.resolve(context, AppMotion.fast);
    return BlocConsumer<VerifyEmailCubit, VerifyEmailState>(
      listenWhen: (before, now) => before.showsReminder != now.showsReminder,
      listener: (_, state) => _follow(state),
      builder: (context, state) {
        final open = _appeared && state.showsReminder;
        return AnimatedSize(
          duration: duration,
          curve: AppMotion.out,
          alignment: AlignmentDirectional.topStart,
          child: AnimatedOpacity(
            opacity: open ? 1 : 0,
            duration: duration,
            child: open
                ? const Padding(
                    padding: EdgeInsetsDirectional.only(bottom: AppSpacing.md),
                    child: _Content(),
                  )
                : const SizedBox(width: double.infinity),
          ),
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  static const _minHeight = 56.0;
  static const _iconSize = 20.0;
  static const _closeSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<VerifyEmailCubit>();
    return Material(
      color: colors.info.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showVerifyEmailSheet(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              end: AppSpacing.xs,
            ),
            child: Row(
              children: [
                AppIconView(
                  AppIcon.mail,
                  size: _iconSize,
                  color: colors.info.fill,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'verify_reminder'.tr(),
                    style: context.texts.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => showVerifyEmailSheet(context),
                  child: Text('verify_reminder_action'.tr()),
                ),
                IconButton(
                  onPressed: cubit.hideReminder,
                  tooltip: 'verify_reminder_hide'.tr(),
                  color: colors.textSecondary,
                  icon: const Icon(Icons.close_rounded, size: _closeSize),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
