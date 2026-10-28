import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/core/session/auth_tokens.dart';

/// `LoginRequest` and its `TokenResponse` (docs/api/openapi.json).
abstract final class SignInModel {
  /// [platform] as in `RegisterModel.request`.
  static Map<String, Object?> request({
    required String email,
    required String password,
    required String? platform,
    String? deviceId,
  }) => {
    'email': email.trim(),
    'password': password,
    'deviceId': deviceId,
    'platform': platform,
  };

  static AuthTokens tokens(Object? body, {required DateTime now}) =>
      TokenResponse.parse(body, now: now);
}
