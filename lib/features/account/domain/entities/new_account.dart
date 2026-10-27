import 'package:equatable/equatable.dart';

/// What the email sign-up sends (requirements v3.0 §4.3).
final class NewAccount extends Equatable {
  const NewAccount({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;

  @override
  List<Object?> get props => [name, email, password];

  @override
  String toString() => 'NewAccount(***)';
}

/// The rules the form checks before sending; the server checks them again.
abstract final class AccountRules {
  /// S §4.3. ASSUMPTION(api): the server's own minimum is not in
  /// docs/api/openapi.json yet (docs/api/README.md, request 7).
  static const passwordMinLength = 8;

  /// ASSUMPTION(api): no limit in docs/api/openapi.json; long enough for a
  /// full name, short enough for every screen that shows it.
  static const nameMaxLength = 50;

  // Something@something.tld, as the designs check it.
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool isName(String value) => value.trim().isNotEmpty;

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static bool isPassword(String value) => value.length >= passwordMinLength;
}
