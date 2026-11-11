import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The update reminder's day (design App Update 03): at most once a day,
/// whatever the learner chose, so «لاحقًا», a swipe or the scrim all put it
/// off until the next day.
final class UpdateReminder {
  UpdateReminder(this._storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SettingsStorageService _storage;
  final DateTime Function() _now;

  bool get dueToday => _storage.updateReminderDay != _today();

  Future<void> shownToday() => _storage.setUpdateReminderDay(_today());

  String _today() {
    final now = _now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }
}

/// Offers a newer version on home when one is recommended, once a day.
/// The caller decides that home is settled and grown-up; this checks that
/// nothing covers it, since another sheet is never stacked on.
Future<void> remindToUpdate(
  BuildContext context,
  UpdateReminder reminder,
) async {
  final splash = context.read<SplashCubit>();
  final covered = !(ModalRoute.of(context)?.isCurrent ?? false);
  if (splash.state.need != UpdateNeed.suggested ||
      covered ||
      !reminder.dueToday) {
    return;
  }
  unawaited(reminder.shownToday());
  final action = await showActionSheet(
    context,
    title: 'update_reminder_title'.tr(),
    body: 'update_reminder_body'.tr(),
    primaryLabel: 'update_reminder_update'.tr(),
    secondaryLabel: 'update_reminder_later'.tr(),
    illustration: const _UpdateBadge(),
    outlinedSecondary: true,
  );
  if (action == SheetAction.primary) await splash.openStore();
}

/// The sheet's download arrow in its circle (design: 72 on the primary
/// surface).
class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge();

  static const _size = 72.0;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: primary.surface, shape: BoxShape.circle),
      // ASSUMPTION(design): the icon's size isn't in the export.
      child: AppIconView(
        AppIcon.download,
        size: AppSizes.iconLg,
        color: primary.fill,
      ),
    );
  }
}
