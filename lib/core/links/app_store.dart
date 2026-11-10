import 'package:englizia/core/links/external_link.dart';

/// The app's page in the phone's store, for an update.
final class AppStore {
  const AppStore(
    this._links, {
    required this.packageName,
    required this.platform,
  });

  final ExternalLink _links;

  /// The Android application ID ("com.example.englizia").
  final String packageName;

  /// "android", "ios" or null (`devicePlatform()`).
  final String? platform;

  /// The store app first (Google Play's own link), then [updateUrl] in
  /// whatever opens it. False when neither opened.
  Future<bool> open(Uri? updateUrl) async {
    if (platform == 'android' &&
        await _links.open(Uri.parse('market://details?id=$packageName'))) {
      return true;
    }
    final page = webPage(updateUrl);
    return page != null && await _links.open(page);
  }

  /// The page to copy into a browser when no store opened: the server's,
  /// else Google Play's web page on Android. None on iOS without the
  /// server's, since only it knows the App Store ID.
  Uri? webPage(Uri? updateUrl) =>
      updateUrl ??
      (platform == 'android'
          ? Uri.https('play.google.com', '/store/apps/details', {
              'id': packageName,
            })
          : null);
}
