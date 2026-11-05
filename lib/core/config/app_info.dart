/// What the installed app is: shown in the settings and sent with feedback.
final class AppInfo {
  const AppInfo({required this.version, required this.platform});

  /// "1.0.0", from the build.
  final String version;

  /// "android" or "ios", as the API's headers say it.
  final String platform;
}
