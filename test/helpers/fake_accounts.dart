import 'dart:async';

import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/entities/account_email.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';

const guestTokens = AuthTokens(
  accessToken: 'g',
  refreshToken: 'r',
  kind: AccountKind.guest,
);

const memberTokens = AuthTokens(accessToken: 'm', refreshToken: 'r');

/// Records what was sent and answers from a script: the nth call gets the
/// nth result, the last one repeating. While [gate] is set, calls wait for
/// it, so a test can look at the sending state.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    this.guestResults = const [Ok(guestTokens)],
    this.accountResults = const [Ok(memberTokens)],
    this.signInResults = const [Ok(memberTokens)],
    this.resetResults = const [Ok(null)],
    this.linkResults = const [Ok(null)],
    this.newPasswordResults = const [Ok(memberTokens)],
    this.emailResults = const [
      Ok(AccountEmail(email: 'user@example.com', verified: false)),
    ],
    this.emailActionResults = const [Ok(null)],
    this.verifyResults = const [Ok(null)],
  });

  final List<Result<AuthTokens>> guestResults;
  final List<Result<AuthTokens>> accountResults;
  final List<Result<AuthTokens>> signInResults;
  final signIns = <(String, String)>[];
  final List<Result<void>> resetResults;
  final resetRequests = <String>[];
  final List<Result<void>> linkResults;
  final linkChecks = <String>[];
  final List<Result<AuthTokens?>> newPasswordResults;
  final newPasswords = <(String, String)>[];
  final List<Result<AccountEmail>> emailResults;

  /// What resending and correcting answer, one after another.
  final List<Result<void>> emailActionResults;
  final List<Result<void>> verifyResults;
  var emailReads = 0;
  var linkResends = 0;
  final changedEmails = <String>[];
  final verifiedTokens = <String>[];
  final guestAnswers = <OnboardingPath>[];
  final accounts = <NewAccount>[];
  final upgrades = <NewAccount>[];
  var logOuts = 0;
  Completer<void>? gate;

  @override
  Future<Result<AuthTokens>> createGuestAccount({
    required OnboardingPath answers,
    required String languageCode,
    required int utcOffsetMinutes,
  }) async {
    guestAnswers.add(answers);
    await gate?.future;
    return _nth(guestResults, guestAnswers.length);
  }

  @override
  Future<Result<AuthTokens>> createAccount(NewAccount account) async {
    accounts.add(account);
    await gate?.future;
    return _nth(accountResults, accounts.length);
  }

  @override
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  }) async {
    signIns.add((email, password));
    await gate?.future;
    return _nth(signInResults, signIns.length);
  }

  @override
  Future<Result<void>> requestPasswordReset(String email) async {
    resetRequests.add(email);
    await gate?.future;
    return resetResults[(resetRequests.length - 1).clamp(
      0,
      resetResults.length - 1,
    )];
  }

  @override
  Future<Result<void>> verifyPasswordLink(String token) async {
    linkChecks.add(token);
    await gate?.future;
    return linkResults[(linkChecks.length - 1).clamp(
      0,
      linkResults.length - 1,
    )];
  }

  @override
  Future<Result<AuthTokens?>> resetPassword({
    required String token,
    required String password,
  }) async {
    newPasswords.add((token, password));
    await gate?.future;
    return newPasswordResults[(newPasswords.length - 1).clamp(
      0,
      newPasswordResults.length - 1,
    )];
  }

  @override
  Future<Result<AccountEmail>> getEmail() async =>
      emailResults[(emailReads++).clamp(0, emailResults.length - 1)];

  Result<void> _emailAction() =>
      emailActionResults[(linkResends + changedEmails.length - 1).clamp(
        0,
        emailActionResults.length - 1,
      )];

  @override
  Future<Result<void>> resendEmailLink() async {
    linkResends++;
    await gate?.future;
    return _emailAction();
  }

  @override
  Future<Result<void>> changeEmail(String email) async {
    changedEmails.add(email);
    await gate?.future;
    return _emailAction();
  }

  @override
  Future<Result<void>> verifyEmail(String token) async {
    verifiedTokens.add(token);
    return verifyResults[(verifiedTokens.length - 1).clamp(
      0,
      verifyResults.length - 1,
    )];
  }

  /// Answers from [accountResults], like [createAccount].
  @override
  Future<Result<AuthTokens>> upgradeGuest(NewAccount account) async {
    upgrades.add(account);
    await gate?.future;
    return _nth(accountResults, upgrades.length);
  }

  @override
  Future<Result<void>> logOut() async {
    logOuts++;
    await gate?.future;
    return const Ok(null);
  }

  static Result<AuthTokens> _nth(List<Result<AuthTokens>> results, int n) =>
      results[(n - 1).clamp(0, results.length - 1)];
}
