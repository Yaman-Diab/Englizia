import 'dart:io';

import 'package:dio/dio.dart';

/// The server's clock as the phone last heard it. Every answer says what
/// time the server has (`Date`, and `serverTime` where a body carries one);
/// the phone's own clock only counts on from there. A wait the server sets
/// (a test's next try) is counted on it, so a phone set to the wrong time
/// waits as long as any other. Before the first answer, and in mock mode, it
/// is the phone's clock.
final class ServerClock {
  ServerClock({DateTime Function()? phone}) : _phone = phone ?? DateTime.now;

  final DateTime Function() _phone;
  Duration _ahead = Duration.zero;

  DateTime now() => _phone().add(_ahead);

  /// The server says it is [time] now.
  void read(DateTime time) => _ahead = time.difference(_phone());
}

/// Sets [ServerClock] by each answer's `Date`, a refusal's too.
// ASSUMPTION(api): `Date` is the API's own clock; on the dev server it is
// the second of the body's `serverTime` (docs/api/README.md).
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
      _clock.read(HttpDate.parse(date));
    } on Exception {
      // A date that can't be read sets nothing.
    }
  }
}
