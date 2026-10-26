import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// The phone's answer about notifications. "Not asked yet" reads as
/// [denied] until [NotificationPermission.request] asks.
enum NotificationAccess { granted, denied }

/// The system permission to show notifications, asked for once the learner
/// has seen why (onboarding reminder step). Reminders themselves are sent by
/// the server at the learner's time (server doc §19.7).
abstract interface class NotificationPermission {
  Future<NotificationAccess> status();

  /// Shows the system prompt when the platform still allows it; otherwise
  /// returns the current answer at once (e.g. after a permanent refusal).
  Future<NotificationAccess> request();

  /// Opens this app's page in the phone settings. False if it could not.
  Future<bool> openSettings();
}

final class PlatformNotificationPermission implements NotificationPermission {
  const PlatformNotificationPermission();

  @override
  Future<NotificationAccess> status() async =>
      _supported ? _access(await Permission.notification.status) : _granted;

  @override
  Future<NotificationAccess> request() async =>
      _supported ? _access(await Permission.notification.request()) : _granted;

  @override
  Future<bool> openSettings() async => _supported && await openAppSettings();

  /// Only the phones ship; desktop and web builds are for development and
  /// have no such permission, so they never block the flow.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const _granted = NotificationAccess.granted;

  /// iOS "provisional" (quiet delivery) still shows notifications.
  static NotificationAccess _access(PermissionStatus status) =>
      status.isGranted || status.isProvisional || status.isLimited
      ? NotificationAccess.granted
      : NotificationAccess.denied;
}
