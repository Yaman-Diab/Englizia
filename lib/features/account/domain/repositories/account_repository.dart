import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/entities/account_email.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';

abstract interface class AccountRepository {
  /// Creates the anonymous guest account of this phone with the onboarding
  /// [answers] (ADR 10). Safe to retry: the same phone gets the same guest.
  Future<Result<AuthTokens>> createGuestAccount({
    required OnboardingPath answers,
    required String languageCode,
    required int utcOffsetMinutes,
  });

  /// Creates a member account with email and password and returns its
  /// session. An email that already has an account fails with
  /// `ConflictFailure`; a value the server refuses, with `ValidationFailure`
  /// naming the field (`displayName`, `email`, `password`).
  Future<Result<AuthTokens>> createAccount(NewAccount account);

  /// Signs in with email and password. Wrong credentials, whether or not
  /// the email has an account, fail with `UnauthorizedFailure`; too many
  /// tries with `RateLimitFailure`, whose wait comes from the server.
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  });

  /// Asks for a link to set a new password, sent to [email] if it has an
  /// account. The answer is the same either way, so no screen can tell
  /// which emails are registered.
  Future<Result<void>> requestPasswordReset(String email);

  /// Checks a recovery link before its form shows. One out of date or used
  /// already fails with `LinkExpiredFailure`.
  Future<Result<void>> verifyPasswordLink(String token);

  /// Sets the new password from a recovery link, which ends the account's
  /// other sessions. Returns the new session, or null when the password
  /// changed but the server started none. Fails with `LinkExpiredFailure`
  /// or, for a password it refuses, `ValidationFailure` naming `password`.
  Future<Result<AuthTokens?>> resetPassword({
    required String token,
    required String password,
  });

  /// The account's email and whether it is confirmed.
  Future<Result<AccountEmail>> getEmail();

  /// Sends the link that confirms the email again. Too many requests fail with
  /// `RateLimitFailure`.
  Future<Result<void>> resendEmailLink();

  /// Corrects the email, which sends a link to the new one. One that has an
  /// account fails with `ConflictFailure`, one the server refuses with
  /// `ValidationFailure`.
  Future<Result<void>> changeEmail(String email);

  /// Confirms the email from the link in the message. One out of date or used
  /// already fails with `LinkExpiredFailure`.
  Future<Result<void>> verifyEmail(String token);

  /// Turns this phone's guest account into a member account with [account]'s
  /// email and password, keeping its progress (ADR 10). Fails like
  /// [createAccount].
  Future<Result<AuthTokens>> upgradeGuest(NewAccount account);

  /// Ends this phone's session on the server. Signing out never waits on
  /// it: a failure only means the server forgets the session later.
  Future<Result<void>> logOut();
}
