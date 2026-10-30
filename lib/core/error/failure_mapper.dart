import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/network_exception.dart';

/// Maps any thrown error to a [Failure], exactly once (called by `guard`).
///
/// Expected API/network errors become breadcrumbs; anything else is logged
/// as an error with its stack trace.
abstract final class FailureMapper {
  static Failure fromError(Object error, [StackTrace? stackTrace]) {
    switch (error) {
      case ApiException():
        AppLogger.info('API ${error.statusCode} code=${error.code}');
        return fromApiException(error);
      case NetworkException():
        AppLogger.info('Network unavailable: ${error.reason}');
        return const NetworkFailure();
      case DioException():
        final converted = ApiClient.convertDioException(error);
        if (converted is DioException) {
          AppLogger.error(error, stackTrace, 'Unmapped Dio error');
          return const UnknownFailure();
        }
        return fromError(converted, stackTrace);
      default:
        AppLogger.error(error, stackTrace, 'Unexpected error');
        return const UnknownFailure();
    }
  }

  static Failure fromApiException(ApiException e) {
    final code = e.code;
    final message = e.detail ?? e.title;
    return switch (e.statusCode) {
      ApiStatusCodes.badRequest ||
      ApiStatusCodes.unprocessableEntity => ValidationFailure(
        fieldErrors: e.fieldErrors,
        fieldCodes: e.fieldCodes,
        code: code,
        serverMessage: message,
      ),
      ApiStatusCodes.unauthorized => UnauthorizedFailure(
        code: code,
        serverMessage: message,
      ),
      ApiStatusCodes.forbidden => ForbiddenFailure(
        code: code,
        serverMessage: message,
      ),
      ApiStatusCodes.notFound => NotFoundFailure(
        code: code,
        serverMessage: message,
      ),
      ApiStatusCodes.conflict => ConflictFailure(
        code: code,
        serverMessage: message,
      ),
      ApiStatusCodes.gone => LinkExpiredFailure(
        code: code,
        serverMessage: message,
      ),
      ApiStatusCodes.tooManyRequests => RateLimitFailure(
        retryAfter: e.retryAfter,
        code: code,
        serverMessage: message,
      ),
      // 5xx and any status the app has no specific handling for.
      _ => ServerFailure(
        statusCode: e.statusCode,
        code: code,
        serverMessage: message,
      ),
    };
  }
}
