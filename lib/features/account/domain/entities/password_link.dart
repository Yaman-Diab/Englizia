import 'package:equatable/equatable.dart';

/// What the link in a recovery email carries (docs/api/auth.md).
final class PasswordLink extends Equatable {
  const PasswordLink({required this.token, required this.email});

  /// Empty when the link came without one: treated as out of date.
  final String token;

  /// Whose password this is; empty when the link came without one.
  final String email;

  @override
  List<Object?> get props => [token, email];

  // The token opens the account: it must never reach logs.
  @override
  String toString() => 'PasswordLink(***)';
}
