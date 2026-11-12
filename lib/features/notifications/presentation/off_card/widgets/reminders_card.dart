import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/features/me/presentation/settings/widgets/settings_parts.dart';
import 'package:englizia/features/notifications/presentation/off_card/cubit/notifications_card_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «أنا»'s word on reminders (design "Notifications" 09–10), the settings'
/// band with its own words: put off twice, «فعّلها» opens the prompt again;
/// kept off by the phone, «افتح الإعدادات». Checked again on coming back, so
/// it goes as soon as they are on. Never for a child.
class RemindersCard extends StatefulWidget {
  const RemindersCard({required this.onEnable, super.key});

  /// Opens the prompt; done when it closes.
  final Future<void> Function() onEnable;

  @override
  State<RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends State<RemindersCard> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<NotificationsCardCubit>().check(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    final cubit = context.read<NotificationsCardCubit>();
    await widget.onEnable();
    await cubit.check();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<NotificationsCardCubit, NotificationsCard>(
        builder: (context, card) => SmoothSize(
          duration: AppMotion.fast,
          curve: AppMotion.out,
          alignment: AlignmentDirectional.topCenter,
          child: switch (card) {
            NotificationsCard.none => const SizedBox(width: double.infinity),
            NotificationsCard.off => NotificationsBlocked(
              text: 'notification_card_off'.tr(),
              action: 'notification_card_enable'.tr(),
              onOpen: () => unawaited(_enable()),
            ),
            NotificationsCard.system => NotificationsBlocked(
              text: 'settings_notifications_off'.tr(),
              onOpen: () => unawaited(
                context.read<NotificationsCardCubit>().openPhoneSettings(),
              ),
            ),
          },
        ),
      );
}
