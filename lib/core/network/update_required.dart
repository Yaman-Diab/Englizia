import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:flutter/foundation.dart';

/// The server refused this app's version (`426 app.update_required`): it
/// checks `X-App-Version` on every `/app/` call against its minimum. Raised
/// once; the splash's update screen follows it (ADR 19).
final class UpdateRequiredSignal extends ChangeNotifier {
  bool _raised = false;

  bool get raised => _raised;

  void raise() {
    if (_raised) return;
    _raised = true;
    notifyListeners();
  }
}

/// Raises [UpdateRequiredSignal] on a `426`, whatever the request; the error
/// still reaches its caller as any other.
final class UpdateRequiredInterceptor extends Interceptor {
  UpdateRequiredInterceptor(this._signal);

  final UpdateRequiredSignal _signal;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == ApiStatusCodes.upgradeRequired) {
      _signal.raise();
    }
    handler.next(err);
  }
}
