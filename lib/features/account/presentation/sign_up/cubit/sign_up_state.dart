import 'package:englizia/core/error/failure.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:equatable/equatable.dart';

/// The form's fields, in focus order.
enum SignUpField { name, email, password }

final class SignUpState extends Equatable {
  const SignUpState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.checked = const {},
    this.refused = const {},
    this.shakes = const {},
    this.sending = false,
    this.created = false,
    this.emailTaken = false,
    this.failure,
  });

  final String name;
  final String email;
  final String password;

  /// Fields whose errors may show: left once, or sent. Editing a field takes
  /// it out again, so its error never shows while typing (S §4.3).
  final Set<SignUpField> checked;

  /// Fields the server refused, wrong until edited.
  final Set<SignUpField> refused;

  /// How many times each field was refused on send; a change shakes it.
  final Map<SignUpField, int> shakes;

  final bool sending;

  /// The account exists and its session is starting.
  final bool created;

  /// The email already has an account: offer to sign in instead.
  final bool emailTaken;

  /// Why the last send failed (connection, server), shown with a retry.
  final Failure? failure;

  bool get filled =>
      name.trim().isNotEmpty && email.trim().isNotEmpty && password.isNotEmpty;

  bool get canSubmit => filled && !sending;

  /// The fields that would stop a send, in focus order.
  List<SignUpField> get invalid => [
    if (!AccountRules.isName(name) || refused.contains(SignUpField.name))
      SignUpField.name,
    if (!AccountRules.isEmail(email) || refused.contains(SignUpField.email))
      SignUpField.email,
    if (!AccountRules.isPassword(password) ||
        refused.contains(SignUpField.password))
      SignUpField.password,
  ];

  /// Whether [field] shows its error now.
  bool showsError(SignUpField field) =>
      refused.contains(field) ||
      checked.contains(field) &&
          valueOf(field).isNotEmpty &&
          invalid.contains(field);

  String valueOf(SignUpField field) => switch (field) {
    SignUpField.name => name,
    SignUpField.email => email,
    SignUpField.password => password,
  };

  NewAccount get account =>
      NewAccount(name: name, email: email, password: password);

  SignUpState copyWith({
    String? name,
    String? email,
    String? password,
    Set<SignUpField>? checked,
    Set<SignUpField>? refused,
    Map<SignUpField, int>? shakes,
    bool? sending,
    bool? created,
    bool? emailTaken,
    Failure? Function()? failure,
  }) => SignUpState(
    name: name ?? this.name,
    email: email ?? this.email,
    password: password ?? this.password,
    checked: checked ?? this.checked,
    refused: refused ?? this.refused,
    shakes: shakes ?? this.shakes,
    sending: sending ?? this.sending,
    created: created ?? this.created,
    emailTaken: emailTaken ?? this.emailTaken,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    name,
    email,
    password,
    checked,
    refused,
    shakes,
    sending,
    created,
    emailTaken,
    failure,
  ];
}
