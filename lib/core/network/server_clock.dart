import 'dart:io';

import 'package:dio/dio.dart';

/// The server's clock as the phone last heard it: the server says its time
/// in `serverTime` (the ping, a unit test's result), and the phone's own
/// clock only counts on from there. A wait the server sets (a test's next
/// try) is counted on it, so a phone set to the wrong time waits as long as
/// any other. Before the first answer, and in mock mode, it is the phone's
/// clock.
final class ServerClock {
  ServerClock({DateTime Function()? phone}) : _phone = phone ?? DateTime.now;

  final DateTime Function() _phone;
  Duration _ahead = Duration.zero;
  bool _told = false;

  DateTime now() => _phone().add(_ahead);

  /// The server says it is [time] now (`serverTime`).
  void read(DateTime time) {
    _told = true;
    _ahead = time.difference(_phone());
  }

  /// An answer's `Date` header: a stand-in until the server has said its
  /// time itself. The contract doesn't promise it is the API's own clock (a
  /// proxy writes it), so it never replaces a `serverTime`.
  void guess(DateTime time) {
    if (!_told) _ahead = time.difference(_phone());
  }
}

/// Gives [ServerClock] each answer's `Date`, a refusal's too, as a stand-in.
final class ServerClockInterceptor extends Interceptor {
  ServerClockInterceptor(this._clock);

  final ServerClock _clock;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _read(response.headers);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _read(err.response?.headers);
    handler.next(err);
  }

  void _read(Headers? headers) {
    final date = headers?.value(HttpHeaders.dateHeader);
    if (date == null) return;
    try {
      _clock.guess(HttpDate.parse(date));
    } on Exception {
      // A date that can't be read sets nothing.
    }
  }
}
