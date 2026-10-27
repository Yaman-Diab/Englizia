import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';

/// `RegisterRequest` and its `TokenResponse` (docs/api/openapi.json).
abstract final class RegisterModel {
  /// [platform] is a `DevicePlatform` (`android`, `web`) or null. The server
  /// gives the device an id in its response, so a first sign-up sends none.
  static Map<String, Object?> request(
    NewAccount account, {
    required String? platform,
    String? deviceId,
  }) => {
    'email': account.email.trim(),
    'password': account.password,
    'displayName': account.name.trim(),
    'deviceId': deviceId,
    'platform': platform,
  };

  static AuthTokens tokens(Object? body, {required DateTime now}) =>
      TokenResponse.parse(body, now: now);
}
