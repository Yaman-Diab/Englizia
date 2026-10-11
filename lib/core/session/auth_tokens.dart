import 'package:equatable/equatable.dart';

final class AuthTokens extends Equatable {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  List<Object?> get props => [accessToken, refreshToken];

  // Tokens must never reach logs through string interpolation.
  @override
  String toString() => 'AuthTokens(***)';
}
