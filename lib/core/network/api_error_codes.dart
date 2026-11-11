/// Stable error codes the server sends in `error.code` (docs/api/README.md).
/// The app chooses its own text by code, never shows the server's message.
abstract final class ApiErrorCodes {
  /// 400: one or more fields are invalid; see `error.details`.
  static const validationFailed = 'validation.failed';

  /// 401: the request needs a signed-in session.
  static const unauthenticated = 'auth.unauthenticated';

  /// 401 from the refresh endpoint: the refresh token is invalid, expired
  /// or revoked; the session is over.
  static const refreshTokenInvalid = 'auth.refresh_token_invalid';

  /// 400 from a link's token (recovery or the email's confirmation): expired,
  /// used already or unknown, one answer for all three.
  static const linkInvalid = 'auth.reset_token_invalid';

  /// 401 from Google sign-in: the ID token failed Google's checks, or was
  /// made for another client than the server's.
  static const googleTokenInvalid = 'auth.google_token_invalid';

  /// 409: the email has an account. From Google sign-in, one Google did not
  /// verify, so the two are not joined.
  static const emailTaken = 'auth.email_taken';

  /// 409 from Google sign-in: the email's account is linked to another
  /// Google account.
  static const externalLoginConflict = 'auth.external_login_conflict';

  /// 403: the account was disabled from the dashboard.
  static const accountDisabled = 'auth.account_disabled';
}
