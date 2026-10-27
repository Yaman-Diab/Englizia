import 'package:equatable/equatable.dart';

/// Typed failure returned by repositories inside `Err`.
///
/// Presentation turns it into text with `FailureL10n` (core/l10n), so this
/// layer stays free of localization.
sealed class Failure extends Equatable {
  const Failure({this.code, this.serverMessage});

  /// Stable machine code for business errors, when the backend sends one.
  final String? code;

  /// Backend message as received. Not shown to users unless the backend
  /// confirms it localizes messages via `Accept-Language`.
  final String? serverMessage;

  @override
  List<Object?> get props => [code, serverMessage];
}

/// No response: offline, DNS, timeout, TLS.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.code, super.serverMessage});
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.code, super.serverMessage});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.code, super.serverMessage});
}

final class ConflictFailure extends Failure {
  const ConflictFailure({super.code, super.serverMessage});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({
    this.fieldErrors = const {},
    this.fieldCodes = const {},
    super.code,
    super.serverMessage,
  });

  /// Field name (camelCase) → the server's messages (for logs).
  final Map<String, List<String>> fieldErrors;

  /// Field name (camelCase) → stable codes (`not_empty`, …): forms show
  /// their own text by code.
  final Map<String, List<String>> fieldCodes;

  String? firstErrorFor(String field) => fieldErrors[field]?.firstOrNull;

  String? firstCodeFor(String field) => fieldCodes[field]?.firstOrNull;

  @override
  List<Object?> get props => [...super.props, fieldErrors, fieldCodes];
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure({this.retryAfter, super.code, super.serverMessage});

  final Duration? retryAfter;

  @override
  List<Object?> get props => [...super.props, retryAfter];
}

final class ServerFailure extends Failure {
  const ServerFailure({this.statusCode, super.code, super.serverMessage});

  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// Anything unexpected (parsing, programming errors). Always logged with stack.
final class UnknownFailure extends Failure {
  const UnknownFailure();
}
