import 'package:englizia/core/result/result.dart';

abstract interface class PushTokenRepository {
  /// Sends this phone's notification address for the signed-in account.
  Future<Result<void>> register(String token);
}
