import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/domain/entities/password_link.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum NewPasswordPhase {
  /// The link is being checked: the field does not show yet.
  verifying,
  form,

  /// Out of date or used already: a new link is asked for.
  expired,
}

final class NewPasswordState extends Equatable {
  const NewPasswordState({
    required this.email,
    this.phase = NewPasswordPhase.verifying,
    this.password = '',
    this.saving = false,
    this.saved = false,
    this.session,
    this.refusals = 0,
    this.refused = false,
    this.failure,
  });

  final String email;
  final NewPasswordPhase phase;
  final String password;
  final bool saving;

  /// The password changed: the next step follows.
  final bool saved;

  /// The session the server started with it, if any.
  final AuthTokens? session;

  /// How many times the server refused the password; shakes the field.
  final int refusals;

  /// The server refused this password: the rule shows as an error until it
  /// is edited.
  final bool refused;

  /// Why the check or the save failed (connection, server), with a retry.
  final Failure? failure;

  bool get ruleMet => AccountRules.isPassword(password);

  bool get canSave =>
      phase == NewPasswordPhase.form &&
      ruleMet &&
      !refused &&
      !saving &&
      !saved;

  NewPasswordState copyWith({
    NewPasswordPhase? phase,
    String? password,
    bool? saving,
    bool? saved,
    AuthTokens? session,
    int? refusals,
    bool? refused,
    Failure? Function()? failure,
  }) => NewPasswordState(
    email: email,
    phase: phase ?? this.phase,
    password: password ?? this.password,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
    session: session ?? this.session,
    refusals: refusals ?? this.refusals,
    refused: refused ?? this.refused,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    email,
    phase,
    password,
    saving,
    saved,
    session,
    refusals,
    refused,
    failure,
  ];
}

/// "Set a new password" (requirements v3.0 §5.2 step 3, design "New
/// Password"): opened by the link in the email, which is checked before the
/// field shows. One out of date, used already or without a token asks for a
/// new one.
class NewPasswordCubit extends Cubit<NewPasswordState> {
  NewPasswordCubit(this._accounts, {required PasswordLink link})
    : _token = link.token,
      super(NewPasswordState(email: link.email));

  final AccountRepository _accounts;
  final String _token;

  Future<void> verify() async {
    if (_token.isEmpty) {
      emit(state.copyWith(phase: NewPasswordPhase.expired));
      return;
    }
    emit(state.copyWith(failure: () => null));
    final result = await _accounts.verifyPasswordLink(_token);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(phase: NewPasswordPhase.form));
      case Err(failure: LinkExpiredFailure()):
        emit(state.copyWith(phase: NewPasswordPhase.expired));
      case Err(:final failure):
        emit(state.copyWith(failure: () => failure));
    }
  }

  void changed(String value) {
    if (state.saving || state.saved) return;
    emit(state.copyWith(password: value, refused: false, failure: () => null));
  }

  Future<void> save() async {
    if (!state.canSave) return;
    emit(state.copyWith(saving: true, failure: () => null));
    final result = await _accounts.resetPassword(
      token: _token,
      password: state.password,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(saving: false, saved: true, session: value));
      case Err(failure: LinkExpiredFailure()):
        emit(state.copyWith(saving: false, phase: NewPasswordPhase.expired));
      case Err(failure: ValidationFailure()):
        emit(
          state.copyWith(
            saving: false,
            refused: true,
            refusals: state.refusals + 1,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(saving: false, failure: () => failure));
    }
  }
}
