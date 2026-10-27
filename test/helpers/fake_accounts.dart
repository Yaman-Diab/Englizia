import 'dart:async';

import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
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
  });

  final List<Result<AuthTokens>> guestResults;
  final List<Result<AuthTokens>> accountResults;
  final guestAnswers = <OnboardingPath>[];
  final accounts = <NewAccount>[];
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

  static Result<AuthTokens> _nth(List<Result<AuthTokens>> results, int n) =>
      results[(n - 1).clamp(0, results.length - 1)];
}
