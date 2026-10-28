import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/models/guest_account_model.dart';
import 'package:englizia/features/account/data/models/register_model.dart';
import 'package:englizia/features/account/data/models/sign_in_model.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';

final class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl(
    this._remote, {
    required TokenStorage tokens,
    required this.installationId,
    required this.devicePlatform,
  }) : _tokens = tokens;

  final AccountRemoteDataSource _remote;
  final TokenStorage _tokens;

  /// This install's id, which the guest account is tied to.
  final Future<String> Function() installationId;

  /// The server's `DevicePlatform` for this phone, or null when it has none.
  final String? devicePlatform;

  @override
  Future<Result<AuthTokens>> createGuestAccount({
    required OnboardingPath answers,
    required String languageCode,
    required int utcOffsetMinutes,
  }) => guard(
    () async => _remote.createGuestAccount(
      GuestAccountModel.request(
        installationId: await installationId(),
        answers: answers,
        languageCode: languageCode,
        utcOffsetMinutes: utcOffsetMinutes,
      ),
    ),
  );

  @override
  Future<Result<AuthTokens>> createAccount(NewAccount account) => guard(
    () => _remote.createAccount(
      RegisterModel.request(account, platform: devicePlatform),
    ),
  );

  @override
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  }) => guard(
    () => _remote.signIn(
      SignInModel.request(
        email: email,
        password: password,
        platform: devicePlatform,
      ),
    ),
  );

  @override
  Future<Result<void>> requestPasswordReset(String email) =>
      guard(() => _remote.requestPasswordReset(email.trim()));

  // ASSUMPTION(api): the upgrade takes register's fields (docs/api/auth.md).
  @override
  Future<Result<AuthTokens>> upgradeGuest(NewAccount account) => guard(
    () => _remote.upgradeGuest(
      RegisterModel.request(account, platform: devicePlatform),
    ),
  );

  @override
  Future<Result<void>> logOut() => guard(() async {
    final tokens = await _tokens.read();
    if (tokens != null) await _remote.logOut(tokens.refreshToken);
  });
}
