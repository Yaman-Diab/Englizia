import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';

/// The guest-account request and response; contract in docs/api/auth.md.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/auth.md).
abstract final class GuestAccountModel {
  static Map<String, Object?> request({
    required String installationId,
    required OnboardingPath answers,
    required String languageCode,
    required int utcOffsetMinutes,
  }) => {
    'installationId': installationId,
    'language': languageCode,
    'utcOffsetMinutes': utcOffsetMinutes,
    'onboarding': onboarding(answers),
  };

  /// The onboarding answers, as sent with any new account (S §4.3).
  static Map<String, Object?> onboarding(OnboardingPath answers) => {
    'audience': switch (answers.audience) {
      TrackAudience.self => 'self',
      TrackAudience.child => 'child',
      TrackAudience.schoolStudent => 'schoolStudent',
      null => null,
    },
    'trackId': answers.trackId,
    'child': answers.childName == null
        ? null
        : {'name': answers.childName, 'age': answers.childAge},
    'gradeLevelId': answers.grade?.id,
    'reasons': [for (final reason in answers.reasons) reason.name],
    'dailyGoalMinutes': answers.dailyGoalMinutes,
    'challengeDays': answers.challengeDays,
    'startLevelId': answers.startLevel?.id,
    'placementTest': answers.placementTest,
    'reminderTime': switch (answers.reminder) {
      final ReminderTime time => _clock(time),
      null => null,
    },
  };

  /// The session of the new guest: the server's `TokenResponse`, as for
  /// login and register. The account is a guest's whatever the response
  /// says, since this endpoint only makes guests.
  static AuthTokens tokens(Object? body, {required DateTime now}) =>
      TokenResponse.parse(body, now: now, kind: AccountKind.guest);

  static String _clock(ReminderTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
