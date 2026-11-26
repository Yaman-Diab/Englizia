import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// The phone's time zone by its IANA name ("Asia/Damascus"). The server
/// starts the learner's day by it, and a name follows the clock's changes
/// where a fixed offset can't (docs/api/auth.md).
abstract interface class PhoneTimeZone {
  /// Null when the phone gives no name the server would take.
  Future<String?> name();
}

final class PlatformPhoneTimeZone implements PhoneTimeZone {
  const PlatformPhoneTimeZone();

  @override
  Future<String?> name() async {
    try {
      return ianaZone((await FlutterTimezone.getLocalTimezone()).identifier);
    } on Object catch (error) {
      AppLogger.warning('The phone gave no time zone: $error');
      return null;
    }
  }
}

final _areaAndPlace = RegExp(r'^[A-Za-z_]+(/[A-Za-z0-9_+\-]+)+$');

/// [id] when it is an IANA name: an area and a place ("Asia/Damascus",
/// "America/Argentina/Buenos_Aires", "Etc/GMT-3"), or UTC. What a phone
/// calls a zone it has no place for ("GMT+03:00") the server refuses.
String? ianaZone(String id) =>
    id == 'UTC' || _areaAndPlace.hasMatch(id) ? id : null;
