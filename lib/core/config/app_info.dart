/// What the installed app is, as the settings show it.
final class AppInfo {
  const AppInfo({required this.version, this.packageName = ''});

  /// "1.0.0", from the build.
  final String version;

  /// The application ID ("com.engleazia.app"), for the store's page.
  final String packageName;
}
