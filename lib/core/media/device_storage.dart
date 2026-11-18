import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter/services.dart';

/// How much room the phone has left, so a download isn't started that can't
/// finish.
abstract interface class DeviceStorage {
  /// Null when the phone doesn't say: the check is then skipped.
  Future<int?> freeBytes();
}

/// A little native code rather than a package, as `PlatformExternalLink`:
/// Android reads the app's own volume (`MainActivity.kt`), iOS the volume's
/// room for what matters to the user (`AppDelegate.swift`).
final class PlatformDeviceStorage implements DeviceStorage {
  const PlatformDeviceStorage();

  static const _channel = MethodChannel('englizia/storage');

  @override
  Future<int?> freeBytes() async {
    try {
      return await _channel.invokeMethod<int>('freeBytes');
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Free space unknown');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
