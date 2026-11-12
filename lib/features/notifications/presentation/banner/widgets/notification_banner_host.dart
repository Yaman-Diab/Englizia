import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/notifications/push_message.dart';
import 'package:englizia/features/notifications/presentation/banner/cubit/in_app_notifications_cubit.dart';
import 'package:englizia/features/notifications/presentation/banner/widgets/notification_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Puts the in-app banner over the whole app, above every route and sheet
/// (design "Notifications" 04): 12 from the sides, 8 under the status bar.
class NotificationBannerHost extends StatelessWidget {
  const NotificationBannerHost({
    required this.child,
    required this.onOpen,
    super.key,
  });

  final Widget child;

  /// A banner was tapped, or the goal's «تابع الدرس».
  final ValueChanged<PushMessage> onOpen;

  static const _belowStatusBar = AppSpacing.sm;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      BlocBuilder<InAppNotificationsCubit, InAppNotificationsState>(
        buildWhen: (before, now) =>
            before.showing != now.showing || before.serial != now.serial,
        builder: (context, state) {
          final message = state.showing;
          if (message == null) return const SizedBox.shrink();
          final cubit = context.read<InAppNotificationsCubit>();
          final serial = state.serial;
          return PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + _belowStatusBar,
            start: AppSpacing.md,
            end: AppSpacing.md,
            child: Material(
              type: MaterialType.transparency,
              child: NotificationBanner(
                message: message,
                serial: serial,
                onOpen: () => onOpen(message),
                onDismissed: () => cubit.dismissed(serial),
                onLater: () => cubit.later(),
              ),
            ),
          );
        },
      ),
    ],
  );
}
