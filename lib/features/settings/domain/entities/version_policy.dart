import 'package:englizia/features/settings/domain/entities/app_version.dart';
import 'package:equatable/equatable.dart';

/// What the installed version must do about updating.
enum UpdateNeed {
  none,

  /// Older than the recommended version: a reminder on home, once a day.
  suggested,

  /// Older than the minimum version: the app stops at the update screen.
  required,
}

/// The server's versions for this phone's platform (server doc §19.2). A
/// value it sent that isn't valid is left out alone, so it decides nothing.
final class VersionPolicy extends Equatable {
  const VersionPolicy({this.minimum, this.recommended, this.updateUrl});

  /// Nothing known: no update is asked for.
  static const none = VersionPolicy();

  final AppVersion? minimum;
  final AppVersion? recommended;

  /// The app's store page, tried after the store app itself.
  final Uri? updateUrl;

  UpdateNeed needOf(AppVersion? installed) {
    if (installed == null) return UpdateNeed.none;
    if (minimum case final minimum? when installed < minimum) {
      return UpdateNeed.required;
    }
    if (recommended case final recommended? when installed < recommended) {
      return UpdateNeed.suggested;
    }
    return UpdateNeed.none;
  }

  @override
  List<Object?> get props => [minimum, recommended, updateUrl];
}
