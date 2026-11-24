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

  /// 400 from a recovery link's token: expired, used already, replaced by a
  /// newer one or unknown, one answer for all.
  static const linkInvalid = 'auth.reset_token_invalid';

  /// 400 from the link that confirms an email, for the same reasons.
  static const emailLinkInvalid = 'auth.email_link_invalid';

  /// 400 from the password change: the current password is wrong. Not a
  /// 401, as the session still stands.
  static const currentPasswordInvalid = 'auth.current_password_invalid';

  /// 401 from Google sign-in: the ID token failed Google's checks, or was
  /// made for another client than the server's.
  static const googleTokenInvalid = 'auth.google_token_invalid';

  /// 409: the email has an account. From Google sign-in, one Google did not
  /// verify, so the two are not joined.
  static const emailTaken = 'auth.email_taken';

  /// 409 from Google sign-in: the email's account is linked to another
  /// Google account.
  static const externalLoginConflict = 'auth.external_login_conflict';

  /// 426 from any `/app/` call: this app's version is below the server's
  /// minimum (`X-App-Version`).
  static const updateRequired = 'app.update_required';

  /// 409 from a guest's upgrade: the account has a login already, so it
  /// was upgraded (a retry after a lost answer).
  static const notGuest = 'auth.not_guest';

  /// 403: the account was disabled from the dashboard.
  static const accountDisabled = 'auth.account_disabled';

  /// 409 from a placement stage: not the session's current one (sent twice,
  /// or the session is over). Read the session and go on from it.
  static const placementStageNotCurrent = 'placement.stage_not_current';

  /// 409 from «اختر»: an older session than the account's latest result.
  static const placementSessionNotLatest = 'placement.session_not_latest';

  /// 409 from «ابدأ الاختبار»: the 30 days since the last result aren't over.
  static const placementRetakeNotYet = 'placement.retake_not_yet';

  /// 422 from a level's change: the track moves to its next level by
  /// itself; only a grade is chosen.
  static const gradeChangeNotAllowed = 'enrollment.grade_change_not_allowed';

  /// 404: no such endpoint on this server.
  static const routeNotFound = 'route.not_found';

  /// 404 from the sync: the account was deleted while its token still works.
  static const userNotFound = 'user.not_found';

  /// 413 from the sync: more answers than one request may carry.
  static const syncBatchTooLarge = 'sync.batch_too_large';
}
