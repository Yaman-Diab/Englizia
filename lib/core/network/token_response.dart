import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/session/auth_tokens.dart';

/// The server's `TokenResponse` (register, login, refresh;
/// docs/api/openapi.json) as [AuthTokens]. [body] may still be wrapped in
/// the envelope. `expiresIn` (seconds) is counted from [now], the moment
/// the response arrived. The account's kind is [kind] when given, else its
/// `user.accountType` (`guest`, `standard`).
abstract final class TokenResponse {
  static AuthTokens parse(
    Object? body, {
    required DateTime now,
    AccountKind? kind,
    AuthTokens? current,
  }) {
    final json = asJsonMap(ApiClient.unwrap(body));
    final access = json.firstOf([
      'accessToken',
      'access_token',
    ], json.readString);
    if (access == null) {
      throw const FormatException('Token response has no access token');
    }
    final refresh = json.firstOf([
      'refreshToken',
      'refresh_token',
    ], json.readString);
    final expiresIn = json.readInt('expiresIn');
    final accessExpiresAt = expiresIn == null
        ? null
        : now.toUtc().add(Duration(seconds: expiresIn));
    final refreshExpiresAt = json
        .readDateTime('refreshTokenExpiresAt')
        ?.toUtc();
    final userId = json.readMap('user')?.readString('id');
    if (current != null) {
      return current.renewed(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: accessExpiresAt,
        refreshExpiresAt: refreshExpiresAt,
        userId: userId,
      );
    }
    if (refresh == null) {
      throw const FormatException('Token response has no refresh token');
    }
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      kind:
          kind ??
          (json.readMap('user')?.readString('accountType') == 'guest'
              ? AccountKind.guest
              : AccountKind.member),
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      deviceId: json.readString('deviceId'),
      userId: userId,
    );
  }
}
