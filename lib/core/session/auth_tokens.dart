import 'package:equatable/equatable.dart';

/// Whose tokens these are (ADR 10): an anonymous [guest] account tied to
/// this phone, or a full [member] account that can sign in anywhere.
enum AccountKind { guest, member }

final class AuthTokens extends Equatable {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.kind = AccountKind.member,
  });

  final String accessToken;
  final String refreshToken;
  final AccountKind kind;

  /// A refreshed pair for the same account.
  AuthTokens renewed({required String accessToken, String? refreshToken}) =>
      AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        kind: kind,
      );

  @override
  List<Object?> get props => [accessToken, refreshToken, kind];

  // Tokens must never reach logs through string interpolation.
  @override
  String toString() => 'AuthTokens(${kind.name}, ***)';
}
