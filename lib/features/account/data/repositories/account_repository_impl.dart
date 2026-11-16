import 'package:englizia/core/error/provider_exception.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
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
  AccountRepositoryImpl(
    this._remote, {
    required TokenStorage tokens,
    required this.savedDeviceId,
    required this.saveDeviceId,
    required this.devicePlatform,
    GoogleIdentitySource? google,
    String Function()? language,
    String Function()? timeZone,
  }) : _tokens = tokens,
       _google = google,
       _language = language ?? (() => 'ar'),
       _timeZone =
           timeZone ??
           (() => OnboardingModel.timeZoneOf(DateTime.now().timeZoneOffset));

  final AccountRemoteDataSource _remote;
  final TokenStorage _tokens;

  /// Null where Google's sign-in is not offered.
  final GoogleIdentitySource? _google;

  /// The app's language, and the phone's time zone, for a new account.
  final String Function() _language;
  final String Function() _timeZone;

  /// A new account the server made whose onboarding answers didn't reach it:
  /// a retry of the same way gives them, and makes no second account.
  ({_NewAccountWay way, AuthTokens account})? _withoutAnswers;

  /// The id the server gave this phone, or null before the first time.
  final String? Function() savedDeviceId;
  final Future<void> Function(String id) saveDeviceId;

  /// The server's `DevicePlatform` for this phone, or null when it has none.
  final String? devicePlatform;

  @override
  Future<Result<AuthTokens>> createGuestAccount({
    required OnboardingPath answers,
  }) => guard(
    () => _newAccount(
      _NewAccountWay.guest,
      answers,
      () async => _remembered(
        await _remote.createGuestAccount(
          GuestAccountModel.request(
            deviceId: savedDeviceId(),
            platform: devicePlatform,
          ),
        ),
      ),
    ),
  );

  @override
  Future<Result<AuthTokens>> createAccount(
    NewAccount account, {
    OnboardingPath? answers,
  }) => guard(
    () => _newAccount(
      _NewAccountWay.email,
      answers,
      () async => _remembered(
        await _remote.createAccount(
          RegisterModel.request(
            account,
            deviceId: savedDeviceId(),
            platform: devicePlatform,
          ),
        ),
      ),
    ),
  );

  /// Makes the account (or takes the one a failed try made), then gives it
  /// [answers], with its own token as its session hasn't started yet.
  Future<AuthTokens> _newAccount(
    _NewAccountWay way,
    OnboardingPath? answers,
    Future<AuthTokens> Function() create,
  ) async {
    final made = _withoutAnswers;
    final account = made != null && made.way == way
        ? made.account
        : await create();
    if (answers != null) await _giveAnswers(way, account, answers);
    return account;
  }

  Future<void> _giveAnswers(
    _NewAccountWay way,
    AuthTokens account,
    OnboardingPath answers,
  ) async {
    _withoutAnswers = (way: way, account: account);
    try {
      await _remote.submitOnboarding(
        OnboardingModel.request(
          answers,
          language: _language(),
          timeZone: _timeZone(),
        ),
        accessToken: account.accessToken,
      );
    } on ApiException catch (error) {
      // A conflict: answered already, a retry after an answer that was lost.
      if (error.statusCode != ApiStatusCodes.conflict) rethrow;
    }
    _withoutAnswers = null;
  }

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
  Future<Result<SocialSession?>> signInWithGoogle({
    OnboardingPath? answers,
  }) => guard(() async {
    // A new account whose answers didn't reach it: only they are sent again.
    if (_withoutAnswers case (
      way: _NewAccountWay.google,
      :final account,
    ) when answers != null) {
      await _giveAnswers(_NewAccountWay.google, account, answers);
      return SocialSession(tokens: account, isNewAccount: true);
    }
    final google = _google;
    if (google == null) {
      throw const ProviderException('Google sign-in is not part of this build');
    }
    final idToken = await google.idToken();
    if (idToken == null) return null;
    // A guest's own account takes Google and keeps its progress, unless
    // this Google account has one already: then that one is signed in to.
    final current = await _tokens.read();
    if (current != null && current.kind == AccountKind.guest) {
      try {
        final upgraded = await _upgraded(
          () => _remote.upgradeGuestWithGoogle(idToken),
        );
        return SocialSession(
          tokens: upgraded,
          isNewAccount: false,
          keptGuest: true,
        );
      } on ApiException catch (error) {
        // That account is signed in to below, leaving the guest behind.
        if (error.code != ApiErrorCodes.externalLoginConflict) rethrow;
      }
    }
    final session = await _remote.signInWithGoogle(
      GoogleSignInModel.request(
        idToken: idToken,
        deviceId: savedDeviceId(),
        platform: devicePlatform,
      ),
    );
    await _remembered(session.tokens);
    if (session.isNewAccount && answers != null) {
      await _giveAnswers(_NewAccountWay.google, session.tokens, answers);
    }
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

  @override
  Future<Result<AuthTokens>> upgradeGuest(NewAccount account) => guard(
    () => _upgraded(
      () => _remote.upgradeGuestWithEmail({
        'email': account.email.trim(),
        'password': account.password,
        'displayName': account.name.trim(),
      }),
    ),
  );

  /// The guest's session carries on as the member's: the server answers
  /// with the account, not new tokens. `auth.not_guest` means a retry of an
  /// upgrade already done.
  Future<AuthTokens> _upgraded(Future<void> Function() upgrade) async {
    final guest = await _tokens.read();
    if (guest == null) {
      throw const ApiException(statusCode: ApiStatusCodes.unauthorized);
    }
    try {
      await upgrade();
    } on ApiException catch (error) {
      // Not a guest any more: upgraded already.
      if (error.code != ApiErrorCodes.notGuest) rethrow;
    }
    return guest.asMember();
  }

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

/// The ways a new account is made, for a retry to take the same one.
enum _NewAccountWay { guest, email, google }
