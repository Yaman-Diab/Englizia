import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/state/wait_countdown.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class SignInState extends Equatable {
  const SignInState({
    required this.now,
    this.email = '',
    this.password = '',
    this.sending = false,
    this.wrongTries = 0,
    this.wrongCredentials = false,
    this.lockedUntil,
    this.failure,
    this.session,
  });

  final String email;
  final String password;
  final bool sending;

  /// Counts refused sign-ins; a change shakes the password field.
  final int wrongTries;

  /// The last try was refused: one message whether or not the email has an
  /// account, so the screen never tells which emails are registered.
  final bool wrongCredentials;

  /// Too many tries: signing in waits until then (the server's wait).
  final DateTime? lockedUntil;

  /// The clock, ticking each second while locked.
  final DateTime now;

  /// Why the last try failed otherwise (connection, server), with a retry.
  final Failure? failure;

  /// The signed-in session, handed to the router. Null until then.
  final AuthTokens? session;

  bool get filled => email.trim().isNotEmpty && password.isNotEmpty;

  /// What is left of the wait; zero when not locked.
  Duration get waitLeft => switch (lockedUntil) {
    final until? when until.isAfter(now) => until.difference(now),
    _ => Duration.zero,
  };

  bool get locked => waitLeft > Duration.zero;

  bool get canSubmit => filled && !sending && !locked;

  SignInState copyWith({
    String? email,
    String? password,
    bool? sending,
    int? wrongTries,
    bool? wrongCredentials,
    DateTime? Function()? lockedUntil,
    DateTime? now,
    Failure? Function()? failure,
    AuthTokens? session,
  }) => SignInState(
    email: email ?? this.email,
    password: password ?? this.password,
    sending: sending ?? this.sending,
    wrongTries: wrongTries ?? this.wrongTries,
    wrongCredentials: wrongCredentials ?? this.wrongCredentials,
    lockedUntil: lockedUntil != null ? lockedUntil() : this.lockedUntil,
    now: now ?? this.now,
    failure: failure != null ? failure() : this.failure,
    session: session ?? this.session,
  );

  @override
  List<Object?> get props => [
    email,
    password,
    sending,
    wrongTries,
    wrongCredentials,
    lockedUntil,
    now,
    failure,
    session,
  ];
}

/// Sign-in with email (requirements v3.0 §5.1, design "Login v2"). Wrong
/// credentials keep the email and clear the password; too many tries wait
/// the server's time, counted down here; a failed connection keeps both
/// for a retry. The session is handed on (`SignInState.session`).
class SignInCubit extends Cubit<SignInState> {
  SignInCubit(this._accounts, {String email = '', DateTime Function()? now})
    : _countdown = WaitCountdown(now: now),
      super(SignInState(email: email, now: (now ?? DateTime.now)()));

  final AccountRepository _accounts;
  final WaitCountdown _countdown;

  /// When the server asks to wait but does not say how long.
  // ASSUMPTION(api): `Retry-After` on 429 is requested (docs/api/README.md,
  // request 8); the design's five minutes until then.
  static const defaultWait = Duration(minutes: 5);

  void emailChanged(String value) {
    if (!state.sending) emit(state.copyWith(email: value));
  }

  void passwordChanged(String value) {
    if (!state.sending) emit(state.copyWith(password: value));
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(
      state.copyWith(
        sending: true,
        wrongCredentials: false,
        failure: () => null,
      ),
    );
    final result = await _accounts.signIn(
      email: state.email,
      password: state.password,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(sending: false, session: value));
      case Err(failure: UnauthorizedFailure()):
        emit(
          state.copyWith(
            sending: false,
            password: '',
            wrongCredentials: true,
            wrongTries: state.wrongTries + 1,
          ),
        );
      case Err(failure: RateLimitFailure(:final retryAfter)):
        final now = _countdown.now();
        final until = now.add(retryAfter ?? defaultWait);
        emit(
          state.copyWith(
            sending: false,
            password: '',
            now: now,
            lockedUntil: () => until,
          ),
        );
        _countdown.start(
          until,
          onTick: (now) => emit(state.copyWith(now: now)),
          onEnd: (now) =>
              emit(state.copyWith(now: now, lockedUntil: () => null)),
        );
      case Err(:final failure):
        emit(state.copyWith(sending: false, failure: () => failure));
    }
  }

  @override
  Future<void> close() {
    _countdown.cancel();
    return super.close();
  }
}
