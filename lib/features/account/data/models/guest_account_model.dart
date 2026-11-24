import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';

/// `CreateGuestRequest` and its `TokenResponse` (docs/api/openapi.json):
/// the guest is made bare, and its answers follow with [OnboardingModel].
abstract final class GuestAccountModel {
  /// [deviceId] is the server's id for this phone, null the first time;
  /// [platform] its `DevicePlatform`. The server names the guest itself.
  static Map<String, Object?> request({
    required String? deviceId,
    required String? platform,
  }) => {'deviceId': deviceId, 'platform': platform, 'displayName': null};

  /// The account is a guest's whatever the response says, since this
  /// endpoint only makes guests.
  static AuthTokens tokens(Object? body, {required DateTime now}) =>
      TokenResponse.parse(body, now: now, kind: AccountKind.guest);
}

/// `OnboardingRequest` of `POST /api/v1/app/me/onboarding`
/// (docs/api/openapi.json): onboarding's answers, given to a new account
/// once it exists, whichever way it was made (S §4.3).
abstract final class OnboardingModel {
  /// [language] is the app's (`ar`, `en`); [timeZone] the phone's as an
  /// IANA name.
  static Map<String, Object?> request(
    OnboardingPath answers, {
    required String language,
    required String timeZone,
  }) {
    // Each kind of track takes only its own: the server refuses any other
    // (`422 enrollment.start_invalid`). A placement track starts at its
    // first published level unless the test places the learner, a grade
    // track at the grade chosen, a direct track at its first level.
    final (String? start, String? levelId) = switch (answers) {
      OnboardingPath(entryMethod: TrackEntryMethod.placementTest) => (
        answers.placementTest ? 'placement' : 'beginner',
        null,
      ),
      OnboardingPath(entryMethod: TrackEntryMethod.gradeSelection) => (
        null,
        answers.grade?.id,
      ),
      OnboardingPath(entryMethod: TrackEntryMethod.directStart) => (null, null),
      // No track kind known: what the answers chose.
      OnboardingPath(:final grade?) => (null, grade.id),
      OnboardingPath(placementTest: true) => ('placement', null),
      _ => (null, null),
    };
    return {
      'uiLanguage': language,
      'timeZone': timeZone,
      'learnerKind': switch (answers.audience) {
        TrackAudience.self => 'adult',
        TrackAudience.child => 'child',
        TrackAudience.schoolStudent => 'school_student',
        null => null,
      },
      'trackId': answers.trackId,
      // Left out rather than null: a field a track doesn't take is refused.
      'start': ?start,
      'levelId': ?levelId,
      if (answers.childName != null)
        'child': {'name': answers.childName, 'age': answers.childAge},
      'learningReasons': [for (final reason in answers.reasons) reason.name],
      'dailyGoalMinutes': answers.dailyGoalMinutes,
      'streakGoalDays': answers.challengeDays,
      'reminderTime': switch (answers.reminder) {
        final ReminderTime time => clock(time),
        null => null,
      },
    };
  }

  /// "HH:mm:ss", as the contract's `time` format reads.
  static String clock(ReminderTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:00';

  /// The phone's offset as an IANA name: `Etc/GMT-3` is three hours ahead
  /// of UTC (the zone's sign is reversed by its standard).
  // ASSUMPTION(api): an `Etc/GMT` zone is accepted where a city is expected;
  // an offset with minutes has none, so it goes as UTC (STATUS D-043).
  static String timeZoneOf(Duration offset) {
    if (offset.inMinutes % 60 != 0 || offset == Duration.zero) return 'UTC';
    final hours = offset.inHours;
    return hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
  }
}
