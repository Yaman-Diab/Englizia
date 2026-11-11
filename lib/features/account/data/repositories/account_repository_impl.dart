import 'package:englizia/core/error/provider_exception.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/datasources/google_identity_source.dart';
import 'package:englizia/features/account/data/models/google_sign_in_model.dart';
import 'package:englizia/features/account/data/models/guest_account_model.dart';
import 'package:englizia/features/account/data/models/register_model.dart';
import 'package:englizia/features/account/data/models/reset_password_model.dart';
import 'package:englizia/features/account/data/models/sign_in_model.dart';
import 'package:englizia/features/account/domain/entities/account_email.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/domain/entities/social_session.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';

final class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl(
    this._remote, {
    required TokenStorage tokens,
    required this.installationId,
    required this.savedDeviceId,
    required this.saveDeviceId,
    required this.devicePlatform,
    GoogleIdentitySource? google,
  }) : _tokens = tokens,
       _google = google;

  final AccountRemoteDataSource _remote;
  final TokenStorage _tokens;

  /// Null where Google's sign-in is not offered.
  final GoogleIdentitySource? _google;

  /// This install's id, which the guest account is tied to.
  final Future<String> Function() installationId;

  /// The id the server gave this phone, or null before the first time.
  final String? Function() savedDeviceId;
  final Future<void> Function(String id) saveDeviceId;

  /// The server's `DevicePlatform` for this phone, or null when it has none.
  final String? devicePlatform;

  @override
  Future<Result<AuthTokens>> createGuestAccount({
    required OnboardingPath answers,
    required String languageCode,
    required int utcOffsetMinutes,
  }) => guard(
    () async => _remembered(
      await _remote.createGuestAccount(
        GuestAccountModel.request(
          installationId: await installationId(),
          answers: answers,
          languageCode: languageCode,
          utcOffsetMinutes: utcOffsetMinutes,
        ),
      ),
    ),
  );

  @override
  Future<Result<AuthTokens>> createAccount(NewAccount account) => guard(
    () async => _remembered(
      await _remote.createAccount(
        RegisterModel.request(
          account,
          deviceId: savedDeviceId(),
          platform: devicePlatform,
        ),
      ),
    ),
  );

  @override
  Future<Result<AuthTokens>> signIn({
    required String email,
    required String password,
  }) => guard(
    () async => _remembered(
      await _remote.signIn(
        SignInModel.request(
          email: email,
          password: password,
          deviceId: savedDeviceId(),
          platform: devicePlatform,
        ),
      ),
    ),
  );

  @override
  Future<Result<SocialSession?>> signInWithGoogle() => guard(() async {
    final google = _google;
    if (google == null) {
      throw const ProviderException('Google sign-in is not part of this build');
    }
    final idToken = await google.idToken();
    if (idToken == null) return null;
    final session = await _remote.signInWithGoogle(
      GoogleSignInModel.request(
        idToken: idToken,
        deviceId: savedDeviceId(),
        platform: devicePlatform,
      ),
    );
    await _remembered(session.tokens);
    return session;
  });

  @override
  Future<Result<void>> requestPasswordReset(String email) =>
      guard(() => _remote.requestPasswordReset(email.trim()));

  @override
  Future<Result<void>> verifyPasswordLink(String token) =>
      guard(() => _remote.verifyPasswordLink(token));

  @override
  Future<Result<AuthTokens?>> resetPassword({
    required String token,
    required String password,
  }) => guard(() async {
    final tokens = await _remote.resetPassword(
      ResetPasswordModel.request(
        token: token,
        password: password,
        deviceId: savedDeviceId(),
        platform: devicePlatform,
      ),
    );
    return tokens == null ? null : _remembered(tokens);
  });

  @override
  Future<Result<AccountEmail>> getEmail() => guard(_remote.getEmail);

  @override
  Future<Result<void>> resendEmailLink() => guard(_remote.resendEmailLink);

  @override
  Future<Result<void>> changeEmail(String email) =>
      guard(() => _remote.changeEmail(email.trim()));

  @override
  Future<Result<void>> verifyEmail(String token) =>
      guard(() => _remote.verifyEmail(token));

  // ASSUMPTION(api): the upgrade takes register's fields (docs/api/auth.md).
  @override
  Future<Result<AuthTokens>> upgradeGuest(NewAccount account) => guard(
    () async => _remembered(
      await _remote.upgradeGuest(
        RegisterModel.request(
          account,
          deviceId: savedDeviceId(),
          platform: devicePlatform,
        ),
      ),
    ),
  );

  @override
  Future<Result<void>> logOut() => guard(() async {
    await _forgetGoogleAccount();
    final tokens = await _tokens.read();
    if (tokens != null) await _remote.logOut(tokens.refreshToken);
  });

  /// So the next Google sign-in asks which account. Signing out never
  /// depends on it.
  Future<void> _forgetGoogleAccount() async {
    try {
      await _google?.signOut();
    } catch (error) {
      AppLogger.warning('Google sign-out failed', error);
    }
  }

  /// Keeps the id the server gave this phone. The account exists by now: an
  /// id that was not saved costs a new device, never the account.
  Future<AuthTokens> _remembered(AuthTokens tokens) async {
    if (tokens.deviceId case final id?) {
      try {
        await saveDeviceId(id);
      } catch (error, stackTrace) {
        AppLogger.error(error, stackTrace, 'Saving the device id failed');
      }
    }
    return tokens;
  }
}
