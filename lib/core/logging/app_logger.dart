import 'package:englizia/core/logging/crash_reporter.dart';
import 'package:englizia/core/logging/redactor.dart';
import 'package:flutter/foundation.dart';

/// The only logging entry point (`print` is banned by lint).
///
/// Debug builds write to the console; release builds forward breadcrumbs and
/// errors to [reporter]. Text is redacted before it leaves this class.
abstract final class AppLogger {
  static CrashReporter reporter = const NoopCrashReporter();

  static void debug(String message) {
    if (kDebugMode) debugPrint('[D] ${Redactor.redactText(message)}');
  }

  static void info(String message) {
    final safe = Redactor.redactText(message);
    if (kDebugMode) {
      debugPrint('[I] $safe');
    } else {
      reporter.breadcrumb(safe);
    }
  }

  static void warning(String message, [Object? error]) {
    final safe = Redactor.redactText(
      error == null ? message : '$message: $error',
    );
    if (kDebugMode) {
      debugPrint('[W] $safe');
    } else {
      reporter.breadcrumb('WARN $safe');
    }
  }

  static void error(Object error, [StackTrace? stackTrace, String? reason]) {
    if (kDebugMode) {
      final text = Redactor.redactText('${reason ?? 'Error'}: $error');
      debugPrint('[E] $text${stackTrace == null ? '' : '\n$stackTrace'}');
    } else {
      reporter.recordError(error, stackTrace, reason: reason);
    }
  }
}
