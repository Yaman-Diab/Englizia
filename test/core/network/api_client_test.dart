import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/app_headers_interceptor.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/api_fixtures.dart';
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

  group('the server envelope (real responses, test/fixtures/api)', () {
    test('returns data of a success', () async {
      adapter = FakeHttpAdapter(
        (_) => FakeResponse(200, body: apiFixture('system_ping_ok')),
      );

      final data = await buildClient(adapter).get('/api/v1/app/system/ping');

      expect(data, isA<Map<String, Object?>>());
      expect((data! as Map)['status'], 'ok');
    });

    test('leaves a plain body that merely has a data field alone', () async {
      adapter = FakeHttpAdapter(
        (_) => const FakeResponse(200, body: {'data': 1, 'other': 2}),
      );

      expect(await buildClient(adapter).get('/x'), {'data': 1, 'other': 2});
    });

    test('reads a validation failure with its field details', () async {
      adapter = FakeHttpAdapter(
        (_) =>
            FakeResponse(400, body: apiFixture('auth_login_validation_failed')),
      );

      await expectLater(
        buildClient(adapter).post('/api/v1/auth/login'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.code, 'code', ApiErrorCodes.validationFailed)
              .having(
                (e) => e.detail,
                'detail',
                'One or more fields are invalid.',
              )
              .having((e) => e.fieldCodes, 'fieldCodes', {
                'email': ['not_empty'],
                'password': ['not_empty'],
              })
              .having((e) => e.fieldErrors['email'], 'email message', [
                "'Email' must not be empty.",
              ])
              .having((e) => e.traceId, 'traceId', isNotEmpty),
        ),
      );
    });

    test('reads an error without details', () async {
      adapter = FakeHttpAdapter(
        (_) => FakeResponse(401, body: apiFixture('app_me_unauthenticated')),
      );

      await expectLater(
        buildClient(adapter).get('/api/v1/app/me'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.unauthenticated)
              .having((e) => e.fieldErrors, 'fieldErrors', isEmpty),
        ),
      );
    });
  });
}
