import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
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
}
