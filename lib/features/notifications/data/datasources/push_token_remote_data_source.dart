import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';

abstract interface class PushTokenRemoteDataSource {
  /// Tells the server where to send this account's notifications on this
  /// phone. Sent again when the token changes or another account signs in.
  Future<void> register({
    required String token,
    required String? platform,
    required String? deviceId,
  });
}

final class PushTokenRemoteDataSourceImpl implements PushTokenRemoteDataSource {
  const PushTokenRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  // ASSUMPTION(api): `PUT /api/v1/app/me/push-token` with these fields,
  // answered `204`; the server forgets it with the device's session
  // (docs/api/notifications.md).
  @override
  Future<void> register({
    required String token,
    required String? platform,
    required String? deviceId,
  }) => _client.put(
    ApiEndpoints.pushToken,
    data: {'token': token, 'platform': platform, 'deviceId': deviceId},
  );
}

/// Mock mode (`env/mock.json`): kept, never sent.
final class PushTokenFakeDataSource implements PushTokenRemoteDataSource {
  String? registered;

  @override
  Future<void> register({
    required String token,
    required String? platform,
    required String? deviceId,
  }) async => registered = token;
}
