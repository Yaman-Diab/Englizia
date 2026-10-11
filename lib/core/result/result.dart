import 'package:englizia/core/error/failure.dart';
import 'package:equatable/equatable.dart';

/// Outcome of a repository or use case call. Handle with `switch`:
///
/// ```dart
/// switch (result) {
///   case Ok(:final value): ...
///   case Err(:final failure): ...
/// }
/// ```
sealed class Result<T> extends Equatable {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  List<Object?> get props => [value];
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
