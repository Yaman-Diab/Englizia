import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class AccountState extends Equatable {
  const AccountState({required this.status, this.signingOut = false});

  final SessionStatus status;
  final bool signingOut;

  bool get isGuest => status == SessionStatus.guest;

  @override
  List<Object?> get props => [status, signingOut];
}

/// Who is signed in, and signing out (ADR 10). The server is told first,
/// but never waited on: signing out always works, even offline. A guest
/// who signs out loses the account, so the page warns first.
class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._session, this._accounts)
    : super(AccountState(status: _session.status)) {
    _session.addListener(_follow);
  }

  final AppSessionController _session;
  final AccountRepository _accounts;

  Future<void> signOut() async {
    if (state.signingOut) return;
    emit(AccountState(status: state.status, signingOut: true));
    await _accounts.logOut();
    // The router leaves the app for the welcome screen.
    await _session.signOut();
  }

  void _follow() {
    if (!isClosed) {
      emit(AccountState(status: _session.status, signingOut: state.signingOut));
    }
  }

  @override
  Future<void> close() {
    _session.removeListener(_follow);
    return super.close();
  }
}
