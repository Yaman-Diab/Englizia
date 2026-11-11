import 'package:englizia/core/session/auth_tokens.dart';
import 'package:equatable/equatable.dart';

/// A session from Google or Apple, which sign in and sign up in one step.
final class SocialSession extends Equatable {
  const SocialSession({required this.tokens, required this.isNewAccount});

  final AuthTokens tokens;

  /// The sign-in made the account, so it has no plan yet: onboarding's
  /// answers belong with it.
  final bool isNewAccount;

  @override
  List<Object?> get props => [tokens, isNewAccount];
}
