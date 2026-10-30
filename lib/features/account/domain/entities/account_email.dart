import 'package:equatable/equatable.dart';

/// The account's email and whether it is confirmed. A guest has none.
final class AccountEmail extends Equatable {
  const AccountEmail({required this.email, required this.verified});

  final String? email;
  final bool verified;

  @override
  List<Object?> get props => [email, verified];
}
