import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/models/guest_account_model.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';

final class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl(this._remote, {required this.installationId});

  final AccountRemoteDataSource _remote;

  /// This install's id, which the guest account is tied to.
  final Future<String> Function() installationId;

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
}
