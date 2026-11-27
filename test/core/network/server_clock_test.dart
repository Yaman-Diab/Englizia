import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/server_clock.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/api_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  // A phone set a year and some hours wrong.
  var phone = DateTime.utc(2025, 3, 1, 4);
  late ServerClock clock;
  late ApiClient client;

  void answer(int status, Object? body, {String? date}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = FakeHttpAdapter(
        (_) => FakeResponse(
          status,
          body: body,
          headers: {
            if (date != null) 'date': [date],
          },
        ),
      )
      ..interceptors.add(ServerClockInterceptor(clock));
    client = ApiClient(dio);
  }

  setUp(() {
    phone = DateTime.utc(2025, 3, 1, 4);
    clock = ServerClock(phone: () => phone);
  });

  test('before any answer it is the phone’s clock', () {
    expect(clock.now(), phone);
  });

  test(
    'until then an answer’s Date stands in, and the phone counts on',
    () async {
      answer(
        200,
        apiFixture('system_ping_ok'),
        date: 'Thu, 26 Nov 2026 09:38:19 GMT',
      );
      await client.get('/api/v1/app/system/ping');

      expect(clock.now(), DateTime.utc(2026, 11, 26, 9, 38, 19));

      phone = phone.add(const Duration(minutes: 10));
      expect(clock.now(), DateTime.utc(2026, 11, 26, 9, 48, 19));
    },
  );

  test('a refusal’s Date stands in too', () async {
    answer(
      422,
      apiFixture('app_unit_test_retry_not_yet'),
      date: 'Thu, 26 Nov 2026 09:38:18 GMT',
    );
    await guard(() => client.post('/api/v1/app/unit-tests/t/submissions'));

    expect(clock.now(), DateTime.utc(2026, 11, 26, 9, 38, 18));
  });

  test('no Date, or one that can’t be read, sets nothing', () async {
    answer(200, apiFixture('system_ping_ok'));
    await client.get('/api/v1/app/system/ping');
    expect(clock.now(), phone);

    answer(200, apiFixture('system_ping_ok'), date: 'yesterday');
    await client.get('/api/v1/app/system/ping');
    expect(clock.now(), phone);
  });

  test('the server’s own word is taken as it is', () {
    clock.read(DateTime.utc(2026, 11, 26, 9, 37, 40, 634));
    expect(clock.now(), DateTime.utc(2026, 11, 26, 9, 37, 40, 634));
  });

  test('once the server has said its time, a Date never replaces it', () async {
    clock.read(DateTime.utc(2026, 11, 26, 9, 37, 40, 634));

    // A proxy's clock, a minute off.
    answer(
      200,
      apiFixture('system_ping_ok'),
      date: 'Thu, 26 Nov 2026 09:38:40 GMT',
    );
    await client.get('/api/v1/app/system/ping');

    expect(clock.now(), DateTime.utc(2026, 11, 26, 9, 37, 40, 634));
  });
}
