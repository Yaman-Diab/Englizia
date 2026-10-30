import 'package:equatable/equatable.dart';

/// What "password changed" needs, handed over as route `extra`.
final class PasswordChangedArgs extends Equatable {
  const PasswordChangedArgs({required this.email, required this.signedIn});

  /// Fills sign-in when the learner has to sign in by hand; may be empty.
  final String email;

  /// The server started a session with the new password.
  final bool signedIn;

  @override
  List<Object?> get props => [email, signedIn];
}
