import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/notifications/data/datasources/push_token_remote_data_source.dart';
import 'package:englizia/features/notifications/domain/repositories/push_token_repository.dart';

final class PushTokenRepositoryImpl implements PushTokenRepository {
  const PushTokenRepositoryImpl(
    this._remote, {
    required this.devicePlatform,
    required this.deviceId,
  });

  final PushTokenRemoteDataSource _remote;

  /// The server's `DevicePlatform` for this phone.
  final String? devicePlatform;

  /// The id the server gave this phone, if it gave one.
  final String? Function() deviceId;

  @override
  Future<Result<void>> register(String token) => guard(
    () => _remote.register(
      token: token,
      platform: devicePlatform,
      deviceId: deviceId(),
    ),
  );
}
