import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/core/session/auth_tokens.dart';

/// Setting a new password from a recovery link: `ResetPasswordRequest` in
/// docs/api/openapi.json.
abstract final class ResetPasswordModel {
  static Map<String, Object?> request({
    required String token,
    required String password,
    required String? platform,
    String? deviceId,
  }) => {
    'token': token,
    'newPassword': password,
    'deviceId': deviceId,
    'platform': platform,
  };

  /// The session, or null without one: the password has changed by now, so a
  /// response with no session is not a failure.
  static AuthTokens? tokens(Object? body, {required DateTime now}) {
    try {
      return TokenResponse.parse(body, now: now);
    } on FormatException {
      return null;
    }
  }
}
