import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/features/account/domain/entities/social_session.dart';

/// `GoogleSignInRequest` and its `TokenResponse` (docs/api/openapi.json).
abstract final class GoogleSignInModel {
  /// [idToken] is Google's, made for the server's client. [platform] as in
  /// `RegisterModel.request`.
  static Map<String, Object?> request({
    required String idToken,
    required String? platform,
    String? deviceId,
  }) => {'idToken': idToken, 'deviceId': deviceId, 'platform': platform};

  static SocialSession session(Object? body, {required DateTime now}) =>
      SocialSession(
        tokens: TokenResponse.parse(body, now: now),
        isNewAccount:
            asJsonMap(ApiClient.unwrap(body)).readBool('isNewUser') ?? false,
      );
}
