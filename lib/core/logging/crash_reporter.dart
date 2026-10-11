/// Release diagnostics sink. The provider (Sentry or Crashlytics) is not
/// chosen yet, so [NoopCrashReporter] is installed by default.
abstract interface class CrashReporter {
  void breadcrumb(String message);

  void recordError(Object error, StackTrace? stackTrace, {String? reason});
}

final class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  void breadcrumb(String message) {}

  @override
  void recordError(Object error, StackTrace? stackTrace, {String? reason}) {}
}
