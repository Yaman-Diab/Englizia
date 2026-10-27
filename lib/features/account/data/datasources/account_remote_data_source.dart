import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/models/guest_account_model.dart';
import 'package:flutter/services.dart';

abstract interface class AccountRemoteDataSource {
  /// [request] is [GuestAccountModel.request].
  Future<AuthTokens> createGuestAccount(Map<String, Object?> request);
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
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled
/// asset the tests also use. Deleted once the endpoint is confirmed.
final class AccountFakeDataSource implements AccountRemoteDataSource {
  const AccountFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 900),
  });

  static const asset = 'assets/mock/account/guest.json';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<AuthTokens> createGuestAccount(Map<String, Object?> request) async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return GuestAccountModel.tokens(body, now: DateTime.now());
  }
}
