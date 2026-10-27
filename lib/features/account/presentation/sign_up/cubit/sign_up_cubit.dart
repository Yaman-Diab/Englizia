import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/account/presentation/sign_up/cubit/sign_up_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'sign_up_state.dart';

/// Email sign-up (requirements v3.0 §4.3, design "Create Account"): checks
/// each field when it is left or sent, creates the account, and starts its
/// session, which takes the learner out of onboarding.
class SignUpCubit extends Cubit<SignUpState> {
  SignUpCubit(this._accounts, this._session) : super(const SignUpState());

  final AccountRepository _accounts;
  final AppSessionController _session;

  /// Server field names (`RegisterRequest`) to the form's.
  static const _serverFields = {
    'displayName': SignUpField.name,
    'email': SignUpField.email,
    'password': SignUpField.password,
  };

  void changed(SignUpField field, String value) {
    if (state.sending || state.valueOf(field) == value) return;
    final edited = state.copyWith(
      checked: {...state.checked}..remove(field),
      refused: {...state.refused}..remove(field),
      emailTaken: field == SignUpField.email ? false : null,
    );
    emit(switch (field) {
      SignUpField.name => edited.copyWith(name: value),
      SignUpField.email => edited.copyWith(email: value),
      SignUpField.password => edited.copyWith(password: value),
    });
  }

  /// The learner moved on from [field]: its error may show now.
  void left(SignUpField field) {
    if (state.checked.contains(field)) return;
    emit(state.copyWith(checked: {...state.checked, field}));
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    final checkedAll = state.copyWith(
      checked: SignUpField.values.toSet(),
      failure: () => null,
    );
    final invalid = checkedAll.invalid;
    if (invalid.isNotEmpty) {
      emit(checkedAll.copyWith(shakes: _shaken(invalid)));
      return;
    }
    emit(checkedAll.copyWith(sending: true, emailTaken: false));
    final result = await _accounts.createAccount(state.account);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(created: true));
        // The router leaves onboarding as soon as the session starts.
        await _session.signIn(value);
      case Err(failure: ConflictFailure()):
        emit(state.copyWith(sending: false, emailTaken: true));
      case Err(failure: final ValidationFailure failure)
          when _refusedBy(failure).isNotEmpty:
        final refused = _refusedBy(failure);
        emit(
          state.copyWith(
            sending: false,
            refused: refused,
            shakes: _shaken(refused),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(sending: false, failure: () => failure));
    }
  }

  Set<SignUpField> _refusedBy(ValidationFailure failure) => {
    for (final name in {
      ...failure.fieldCodes.keys,
      ...failure.fieldErrors.keys,
    })
      ?_serverFields[name],
  };

  Map<SignUpField, int> _shaken(Iterable<SignUpField> fields) => {
    ...state.shakes,
    for (final field in fields) field: (state.shakes[field] ?? 0) + 1,
  };
}
