import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:equatable/equatable.dart';

/// What "preparing" needs, handed over as route `extra` (it carries the
/// session): the learner's answers, the new account's session, which
/// preparing starts, and the learner's name, empty when there is none.
final class PreparingArgs extends Equatable {
  const PreparingArgs({
    required this.path,
    required this.session,
    this.name = '',
  });

  final OnboardingPath path;
  final AuthTokens session;
  final String name;

  @override
  List<Object?> get props => [path, session, name];
}
