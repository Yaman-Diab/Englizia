import 'package:equatable/equatable.dart';

/// Whose tokens these are (ADR 10): an anonymous [guest] account tied to
/// this phone, or a full [member] account that can sign in anywhere.
enum AccountKind { guest, member }

final class AuthTokens extends Equatable {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.kind = AccountKind.member,
    this.accessExpiresAt,
    this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final AccountKind kind;

  /// When the access token stops working (UTC); null when unknown. The app
  /// refreshes shortly before, instead of waiting for a 401.
  final DateTime? accessExpiresAt;

  /// When the refresh token stops working (UTC); null when unknown.
  final DateTime? refreshExpiresAt;

  /// Whether the access token expires within [margin] of [now].
  bool expiresSoon(DateTime now, {required Duration margin}) =>
      switch (accessExpiresAt) {
        final at? => !now.add(margin).isBefore(at),
        null => false,
      };

  /// A refreshed pair for the same account; a field the refresh did not
  /// return keeps its current value.
  AuthTokens renewed({
    required String accessToken,
    String? refreshToken,
    DateTime? accessExpiresAt,
    DateTime? refreshExpiresAt,
  }) => AuthTokens(
    accessToken: accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    kind: kind,
    accessExpiresAt: accessExpiresAt,
    refreshExpiresAt: refreshExpiresAt ?? this.refreshExpiresAt,
  );

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    kind,
    accessExpiresAt,
    refreshExpiresAt,
  ];

  // Tokens must never reach logs through string interpolation.
  @override
  String toString() => 'AuthTokens(${kind.name}, ***)';
}
