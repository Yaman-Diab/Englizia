import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.email = '',
    this.checked = false,
    this.sending = false,
    this.sent = false,
    this.failure,
  });

  final String email;

  /// The field was left or sent: its error may show. Editing clears it, so
  /// the error never shows while typing.
  final bool checked;
  final bool sending;

  /// The link is on its way (or would be): the next step follows.
  final bool sent;

  /// Why the request failed (connection, server), with a retry.
  final Failure? failure;

  bool get emailValid => AccountRules.isEmail(email);

  bool get showsError => checked && email.trim().isNotEmpty && !emailValid;

  bool get canSubmit => emailValid && !sending && !sent;

  ForgotPasswordState copyWith({
    String? email,
    bool? checked,
    bool? sending,
    bool? sent,
    Failure? Function()? failure,
  }) => ForgotPasswordState(
    email: email ?? this.email,
    checked: checked ?? this.checked,
    sending: sending ?? this.sending,
    sent: sent ?? this.sent,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [email, checked, sending, sent, failure];
}

/// "Forgot your password?" (requirements v3.0 §5.2 step 1, design "Forgot
/// Password"): asks for the link to set a new password. The next step comes
/// whether or not the email has an account, and also when the server says
/// too many requests, so the screen never tells which emails are
/// registered.
class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit(this._accounts, {String email = ''})
    : super(ForgotPasswordState(email: email));

  final AccountRepository _accounts;

  void changed(String value) {
    if (state.sending || state.sent) return;
    emit(state.copyWith(email: value, checked: false));
  }

  /// The field was left.
  void left() {
    if (!state.checked) emit(state.copyWith(checked: true));
  }

  /// Back from the next step, to change the email or send again.
  void reopened() => emit(state.copyWith(sent: false));

  Future<void> submit() async {
    if (!state.emailValid) {
      emit(state.copyWith(checked: true));
      return;
    }
    if (!state.canSubmit) return;
    emit(state.copyWith(sending: true, checked: true, failure: () => null));
    final result = await _accounts.requestPasswordReset(state.email);
    if (isClosed) return;
    switch (result) {
      case Ok() || Err(failure: RateLimitFailure()):
        emit(state.copyWith(sending: false, sent: true));
      case Err(:final failure):
        emit(state.copyWith(sending: false, failure: () => failure));
    }
  }
}
