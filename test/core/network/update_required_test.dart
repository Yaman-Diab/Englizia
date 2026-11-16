import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/update_required.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/api_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  late UpdateRequiredSignal signal;
  late ApiClient client;

  void answer(int status, Object? body) {
    signal = UpdateRequiredSignal();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = FakeHttpAdapter(
        (_) => FakeResponse(status, body: body),
      )
      ..interceptors.add(UpdateRequiredInterceptor(signal));
    client = ApiClient(dio);
  }

  test('the server\'s 426 raises it, and still fails the call', () async {
    answer(426, apiFixture('app_update_required'));
    var told = 0;
    signal.addListener(() => told++);

    final result = await guard(() => client.get('/api/v1/app/tracks'));

    expect(signal.raised, isTrue);
    expect(told, 1);
    final failure = (result as dynamic).failure as Failure;
    expect(failure.code, ApiErrorCodes.updateRequired);

    // Once is enough.
    await guard(() => client.get('/api/v1/app/tracks'));
    expect(told, 1);
  });

  test('any other refusal leaves it alone', () async {
    answer(401, apiFixture('app_me_unauthenticated'));
    await guard(() => client.get('/api/v1/app/me'));
    expect(signal.raised, isFalse);
  });
}
