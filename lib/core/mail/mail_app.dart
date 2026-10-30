import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter/services.dart';

/// Opens the phone's mail app (its inbox, not a new message).
abstract interface class MailApp {
  /// False when the phone has no mail app to open.
  Future<bool> open();
}

/// A little native code rather than a package: Android asks for the apps in
/// its email category (`MainActivity.kt`), iOS opens Mail (`AppDelegate.swift`).
final class PlatformMailApp implements MailApp {
  const PlatformMailApp();

  static const _channel = MethodChannel('englizia/mail_app');

  @override
  Future<bool> open() async {
    try {
      return await _channel.invokeMethod<bool>('open') ?? false;
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Could not open the mail app');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
