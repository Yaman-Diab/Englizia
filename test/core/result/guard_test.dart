import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/error/failure_mapper.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guard', () {
    test('wraps a value in Ok', () async {
      expect(await guard(() async => 42), const Ok(42));
    });

    test('maps thrown errors to Err', () async {
      final result = await guard<int>(
        () async => throw const NetworkException('offline'),
      );
      expect(result, const Err<int>(NetworkFailure()));
    });

    test('maps programming errors to UnknownFailure', () async {
      final result = await guard<int>(() async => throw StateError('bug'));
      expect(result, const Err<int>(UnknownFailure()));
    });
  });

  group('FailureMapper', () {
    Failure map(int status) =>
        FailureMapper.fromApiException(ApiException(statusCode: status));

    test('maps every handled status to its failure type', () {
      expect(map(400), isA<ValidationFailure>());
      expect(map(422), isA<ValidationFailure>());
      expect(map(401), isA<UnauthorizedFailure>());
      expect(map(403), isA<ForbiddenFailure>());
      expect(map(404), isA<NotFoundFailure>());
      expect(map(409), isA<ConflictFailure>());
      expect(map(429), isA<RateLimitFailure>());
      expect(map(500), isA<ServerFailure>());
      expect(map(503), isA<ServerFailure>());
    });

    test('keeps field errors and the business code', () {
      final failure = FailureMapper.fromApiException(
        const ApiException(
          statusCode: 422,
          code: 'email_taken',
          fieldErrors: {
            'email': ['Already used.'],
          },
        ),
      );
      expect(failure, isA<ValidationFailure>());
      failure as ValidationFailure;
      expect(failure.code, 'email_taken');
      expect(failure.firstErrorFor('email'), 'Already used.');
    });

    test('maps raw Dio timeouts to NetworkFailure', () {
      final failure = FailureMapper.fromError(
        DioException.connectionTimeout(
          timeout: const Duration(seconds: 20),
          requestOptions: RequestOptions(path: '/x'),
        ),
      );
      expect(failure, const NetworkFailure());
    });
  });
}
