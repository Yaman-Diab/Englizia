import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/models/guest_account_model.dart';
import 'package:englizia/features/account/data/models/register_model.dart';
import 'package:englizia/features/account/data/models/reset_password_model.dart';
import 'package:englizia/features/account/data/models/sign_in_model.dart';
import 'package:flutter/services.dart';

abstract interface class AccountRemoteDataSource {
  /// [request] is [GuestAccountModel.request].
  Future<AuthTokens> createGuestAccount(Map<String, Object?> request);

  /// [request] is [RegisterModel.request].
  Future<AuthTokens> createAccount(Map<String, Object?> request);

  /// [request] is [SignInModel.request].
  Future<AuthTokens> signIn(Map<String, Object?> request);

  Future<void> requestPasswordReset(String email);

  Future<void> verifyPasswordLink(String token);

  /// [request] is [ResetPasswordModel.request].
  Future<AuthTokens?> resetPassword(Map<String, Object?> request);

  /// Sent with the guest's own token; [request] is [RegisterModel.request].
  Future<AuthTokens> upgradeGuest(Map<String, Object?> request);

  Future<void> logOut(String refreshToken);
}

final class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  const AccountRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<AuthTokens> createGuestAccount(Map<String, Object?> request) async =>
      GuestAccountModel.tokens(
        await _client.post(ApiEndpoints.guestAccount, data: request),
        now: DateTime.now(),
      );

  @override
  Future<AuthTokens> createAccount(Map<String, Object?> request) async =>
      RegisterModel.tokens(
        await _client.post(
          ApiEndpoints.register,
          data: request,
          options: ApiClient.publicOptions,
        ),
        now: DateTime.now(),
      );

  @override
  Future<AuthTokens> signIn(Map<String, Object?> request) async =>
      SignInModel.tokens(
        await _client.post(
          ApiEndpoints.login,
          data: request,
          options: ApiClient.publicOptions,
        ),
        now: DateTime.now(),
      );

  @override
  Future<void> requestPasswordReset(String email) => _client.post(
    ApiEndpoints.forgotPassword,
    data: {'email': email},
    options: ApiClient.publicOptions,
  );

  @override
  Future<void> verifyPasswordLink(String token) => _client.post(
    ApiEndpoints.verifyPasswordLink,
    data: {'token': token},
    options: ApiClient.publicOptions,
  );

  @override
  Future<AuthTokens?> resetPassword(Map<String, Object?> request) async =>
      ResetPasswordModel.tokens(
        await _client.post(
          ApiEndpoints.resetPassword,
          data: request,
          options: ApiClient.publicOptions,
        ),
        now: DateTime.now(),
      );

  @override
  Future<AuthTokens> upgradeGuest(Map<String, Object?> request) async =>
      RegisterModel.tokens(
        await _client.post(ApiEndpoints.upgradeGuest, data: request),
        now: DateTime.now(),
      );

  @override
  Future<void> logOut(String refreshToken) => _client.post(
    ApiEndpoints.logout,
    data: {'refreshToken': refreshToken},
    options: ApiClient.publicOptions,
  );
}

/// Mock mode (`env/mock.json`): the contract's examples from bundled assets
/// the tests also use. Deleted once each endpoint is connected.
final class AccountFakeDataSource implements AccountRemoteDataSource {
  const AccountFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 900),
  });

  static const asset = 'assets/mock/account/guest.json';
  static const registerAsset = 'assets/mock/account/register.json';

  /// Signing up with this email shows "this email already has an account".
  static const takenEmail = 'taken@example.com';

  /// Signing in: this pair works, [lockedEmail] is told to wait, anything
  /// else is wrong.
  static const signInEmail = 'user@example.com';
  static const signInPassword = 'password1';
  static const lockedEmail = 'locked@example.com';
  static const lockedFor = Duration(minutes: 5);

  /// A recovery link with this token is out of date; with
  /// [unreachableResetToken] it opens, and saving finds no connection; with
  /// [noSessionResetToken] the password changes but no session starts.
  static const expiredResetToken = 'expired';
  static const unreachableResetToken = 'offline';
  static const noSessionResetToken = 'no-session';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<AuthTokens> createGuestAccount(Map<String, Object?> request) async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return GuestAccountModel.tokens(body, now: DateTime.now());
  }

  @override
  Future<AuthTokens> createAccount(Map<String, Object?> request) async {
    await Future<void>.delayed(latency);
    if (request['email'] == takenEmail) {
      throw const ApiException(statusCode: ApiStatusCodes.conflict);
    }
    final body = jsonDecode(await _bundle.loadString(registerAsset));
    return RegisterModel.tokens(body, now: DateTime.now());
  }

  @override
  Future<AuthTokens> signIn(Map<String, Object?> request) async {
    await Future<void>.delayed(latency);
    if (request['email'] == lockedEmail) {
      throw const ApiException(
        statusCode: ApiStatusCodes.tooManyRequests,
        retryAfter: lockedFor,
      );
    }
    if (request['email'] != signInEmail ||
        request['password'] != signInPassword) {
      throw const ApiException(statusCode: ApiStatusCodes.unauthorized);
    }
    final body = jsonDecode(await _bundle.loadString(registerAsset));
    return SignInModel.tokens(body, now: DateTime.now());
  }

  /// Always sent, as the server answers for any email.
  @override
  Future<void> requestPasswordReset(String email) =>
      Future<void>.delayed(latency);

  @override
  Future<void> verifyPasswordLink(String token) async {
    await Future<void>.delayed(latency);
    if (token == expiredResetToken) {
      throw const ApiException(statusCode: ApiStatusCodes.gone);
    }
  }

  @override
  Future<AuthTokens?> resetPassword(Map<String, Object?> request) async {
    await Future<void>.delayed(latency);
    if (request['token'] == unreachableResetToken) {
      throw const NetworkException('connectionError');
    }
    if (request['token'] == noSessionResetToken) return null;
    final body = jsonDecode(await _bundle.loadString(registerAsset));
    return ResetPasswordModel.tokens(body, now: DateTime.now());
  }

  /// Answers like [createAccount]: the upgraded account is a member.
  @override
  Future<AuthTokens> upgradeGuest(Map<String, Object?> request) =>
      createAccount(request);

  @override
  Future<void> logOut(String refreshToken) => Future<void>.delayed(latency);
}
