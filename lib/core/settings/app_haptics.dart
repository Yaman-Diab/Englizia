import 'package:flutter/services.dart';

/// Every vibration of the app, silenced as one by the «الاهتزاز» setting
/// ([SettingsCubit] keeps [enabled] in step with it).
abstract final class AppHaptics {
  static var enabled = true;

  static Future<void> selectionClick() =>
      enabled ? HapticFeedback.selectionClick() : Future.value();

  static Future<void> lightImpact() =>
      enabled ? HapticFeedback.lightImpact() : Future.value();

  static Future<void> mediumImpact() =>
      enabled ? HapticFeedback.mediumImpact() : Future.value();
}
