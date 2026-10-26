import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/app_headers_interceptor.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;

  ApiClient buildClient(FakeHttpAdapter fake) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = fake
      ..interceptors.add(
        AppHeadersInterceptor(
          languageCode: () => 'ar',
          appVersion: '1.2.3',
          platform: 'android',
        ),
      );
    return ApiClient(dio);
  }

  test('returns the decoded body and sends the app headers', () async {
    adapter = FakeHttpAdapter((_) => const FakeResponse(200, body: {'id': 7}));

    final body = await buildClient(adapter).get('/tracks');

    expect(body, {'id': 7});
    final headers = adapter.requests.single.headers;
    expect(headers['Accept'], 'application/json');
    expect(headers['Accept-Language'], 'ar');
    expect(headers['X-App-Version'], '1.2.3');
    expect(headers['X-Platform'], 'android');
  });

  test('parses ASP.NET ProblemDetails into ApiException', () async {
    adapter = FakeHttpAdapter(
      (_) => const FakeResponse(
        400,
        body: {
          'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
          'title': 'One or more validation errors occurred.',
          'status': 400,
          'code': 'validation_failed',
          'errors': {
            'Email': ['The Email field is required.'],
            r'$.password': ['Too short.'],
          },
          'traceId': '00-0000-00',
        },
      ),
    );

    await expectLater(
      buildClient(adapter).post('/auth/register', data: {'email': ''}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.code, 'code', 'validation_failed')
            .having((e) => e.fieldErrors, 'fieldErrors', {
              'email': ['The Email field is required.'],
              'password': ['Too short.'],
            }),
      ),
    );
  });

  test('reads Retry-After on 429', () async {
    adapter = FakeHttpAdapter(
      (_) => const FakeResponse(
        429,
        headers: {
          'retry-after': ['30'],
        },
      ),
    );

    await expectLater(
      buildClient(adapter).get('/tracks'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      ),
    );
  });

  test('turns transport failures into NetworkException', () async {
    adapter = FakeHttpAdapter(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      ),
    );

    await expectLater(
      buildClient(adapter).get('/tracks'),
      throwsA(isA<NetworkException>()),
    );
  });

  group('unified envelope', () {
    test('returns data of an enveloped success', () async {
      adapter = FakeHttpAdapter(
        (_) => const FakeResponse(
          200,
          body: {
            'data': [
              {'id': 'trk_01'},
            ],
            'meta': null,
            'error': null,
          },
        ),
      );

      expect(await buildClient(adapter).get('/tracks'), [
        {'id': 'trk_01'},
      ]);
    });

    test('leaves a plain body that merely has a data field alone', () async {
      adapter = FakeHttpAdapter(
        (_) => const FakeResponse(200, body: {'data': 1, 'other': 2}),
      );

      expect(await buildClient(adapter).get('/x'), {'data': 1, 'other': 2});
    });

    test('reads the error object of an enveloped failure', () async {
      adapter = FakeHttpAdapter(
        (_) => const FakeResponse(
          422,
          body: {
            'data': null,
            'meta': null,
            'error': {
              'code': 'email_taken',
              'message': 'Email is taken',
              'fieldErrors': {
                'Email': ['Taken'],
              },
              'traceId': '00-abc',
            },
          },
        ),
      );

      await expectLater(
        buildClient(adapter).post('/auth/register'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 422)
              .having((e) => e.code, 'code', 'email_taken')
              .having((e) => e.detail, 'detail', 'Email is taken')
              .having((e) => e.fieldErrors, 'fieldErrors', {
                'email': ['Taken'],
              })
              .having((e) => e.traceId, 'traceId', '00-abc'),
        ),
      );
    });
  });
}
