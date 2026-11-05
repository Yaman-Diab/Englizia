import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter/services.dart';

/// Opens a link outside the app: a WhatsApp chat, a web page.
abstract interface class ExternalLink {
  /// False when nothing on the phone can open it.
  Future<bool> open(Uri uri);
}

/// A little native code rather than a package, as `PlatformMailApp`:
/// Android views the link (`MainActivity.kt`), iOS opens it (`AppDelegate.swift`).
final class PlatformExternalLink implements ExternalLink {
  const PlatformExternalLink();

  static const _channel = MethodChannel('englizia/links');

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await _channel.invokeMethod<bool>('open', uri.toString()) ?? false;
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Could not open a link');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
