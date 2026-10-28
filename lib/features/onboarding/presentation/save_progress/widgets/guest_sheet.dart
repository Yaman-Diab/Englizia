import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:flutter/widgets.dart';

/// Before carrying on as a guest: the progress stays on this phone only.
/// True when the learner chooses to continue as a guest; false or null
/// when they go back to create an account.
Future<bool?> showGuestSheet(BuildContext context) async =>
    switch (await showActionSheet(
      context,
      icon: AppIcon.phone,
      title: 'onboarding_save_guest_title'.tr(),
      body: 'onboarding_save_guest_body'.tr(),
      primaryLabel: 'onboarding_save_guest_create'.tr(),
      secondaryLabel: 'onboarding_save_guest_continue'.tr(),
    )) {
      SheetAction.secondary => true,
      SheetAction.primary => false,
      null => null,
    };
