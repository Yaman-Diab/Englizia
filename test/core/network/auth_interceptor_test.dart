import 'package:dio/dio.dart';
import 'package:englizia/core/network/auth_interceptor.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';

void main() {
  const oldTokens = AuthTokens(accessToken: 'old', refreshToken: 'r1');
  const newTokens = AuthTokens(accessToken: 'new', refreshToken: 'r2');

  late FakeTokenStorage storage;
  late int expiredCalls;

  setUp(() {
    storage = FakeTokenStorage(oldTokens);
    expiredCalls = 0;
  });

  Dio buildDio(FakeHttpAdapter adapter, FakeTokenRefresher refresher) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        tokens: storage,
        refresher: refresher,
        retry: dio.fetch<Object?>,
        onSessionExpired: () async => expiredCalls++,
      ),
    );
    return dio;
  }

  /// Accepts only the new token, like a server after the old one expired.
  FakeHttpAdapter acceptsOnlyNewToken() => FakeHttpAdapter(
    (options) => options.headers['Authorization'] == 'Bearer new'
        ? const FakeResponse(200, body: {'ok': true})
        : const FakeResponse(401),
  );

  test('attaches the bearer token, except for skipAuth requests', () async {
    final adapter = FakeHttpAdapter((_) => const FakeResponse(200));
    final dio = buildDio(adapter, FakeTokenRefresher((_) async => newTokens));

    await dio.get<Object?>('/me');
    await dio.post<Object?>(
      '/login',
      options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
    );

    expect(adapter.requests[0].headers['Authorization'], 'Bearer old');
    expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
  });

  test('on 401 refreshes once, stores the new pair and retries', () async {
    final adapter = acceptsOnlyNewToken();
    final refresher = FakeTokenRefresher((_) async => newTokens);
    final dio = buildDio(adapter, refresher);

    final response = await dio.get<Object?>('/lessons');

    expect(response.statusCode, 200);
    expect(refresher.calls, 1);
    expect(storage.tokens, newTokens);
    expect(adapter.requests.map((r) => r.headers['Authorization']), [
      'Bearer old',
      'Bearer new',
    ]);
    expect(expiredCalls, 0);
  });

  test('concurrent 401s share a single refresh', () async {
    final refresher = FakeTokenRefresher((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return newTokens;
    });
    final dio = buildDio(acceptsOnlyNewToken(), refresher);

    final responses = await Future.wait([
      dio.get<Object?>('/a'),
      dio.get<Object?>('/b'),
      dio.get<Object?>('/c'),
    ]);

    expect(responses.map((r) => r.statusCode), [200, 200, 200]);
    expect(refresher.calls, 1);
  });

  FakeTokenRefresher refresherFailingWith(int status) => FakeTokenRefresher(
    (_) => Future.error(
      DioException(
        requestOptions: RequestOptions(path: '/refresh'),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/refresh'),
          statusCode: status,
        ),
        type: DioExceptionType.badResponse,
      ),
    ),
  );

  for (final status in [400, 401, 403]) {
    test('a $status from the refresh endpoint expires the session', () async {
      final dio = buildDio(
        FakeHttpAdapter((_) => const FakeResponse(401)),
        refresherFailingWith(status),
      );

      await expectLater(
        dio.get<Object?>('/lessons'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(expiredCalls, 1);
    });
  }

  for (final status in [429, 500, 502, 503]) {
    test('a $status from the refresh endpoint keeps the session', () async {
      final dio = buildDio(
        FakeHttpAdapter((_) => const FakeResponse(401)),
        refresherFailingWith(status),
      );

      await expectLater(
        dio.get<Object?>('/lessons'),
        throwsA(isA<DioException>()),
      );
      expect(expiredCalls, 0);
      expect(storage.tokens, oldTokens);
    });
  }

  test('a malformed refresh response keeps the session', () async {
    final refresher = FakeTokenRefresher(
      (_) => Future.error(const FormatException('no access token')),
    );
    final dio = buildDio(
      FakeHttpAdapter((_) => const FakeResponse(401)),
      refresher,
    );

    await expectLater(
      dio.get<Object?>('/lessons'),
      throwsA(isA<DioException>()),
    );
    expect(expiredCalls, 0);
    expect(storage.tokens, oldTokens);
  });

  test('an unreachable refresh endpoint keeps the session', () async {
    final refresher = FakeTokenRefresher(
      (_) => Future.error(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/refresh'),
          reason: 'offline',
        ),
      ),
    );
    final dio = buildDio(
      FakeHttpAdapter((_) => const FakeResponse(401)),
      refresher,
    );

    await expectLater(
      dio.get<Object?>('/lessons'),
      throwsA(isA<DioException>()),
    );
    expect(expiredCalls, 0);
    expect(storage.tokens, oldTokens);
  });

  test('a retried request that fails again is not refreshed again', () async {
    final refresher = FakeTokenRefresher((_) async => newTokens);
    final dio = buildDio(
      FakeHttpAdapter((_) => const FakeResponse(401)),
      refresher,
    );

    await expectLater(
      dio.get<Object?>('/lessons'),
      throwsA(isA<DioException>()),
    );
    expect(refresher.calls, 1);
  });
}
