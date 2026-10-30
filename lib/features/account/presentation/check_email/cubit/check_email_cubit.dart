import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/mail/mail_app.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/wait_countdown.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class CheckEmailState extends Equatable {
  const CheckEmailState({
    required this.email,
    required this.now,
    required this.resendAt,
    this.sends = 1,
    this.resending = false,
    this.resent = 0,
    this.noMailApp = 0,
    this.failure,
  });

  final String email;

  /// The clock, ticking each second while waiting to resend.
  final DateTime now;

  /// When the link may be asked for again.
  final DateTime resendAt;

  /// How many links were asked for; each one makes the next wait longer.
  final int sends;
  final bool resending;

  /// Counts the links sent again; a change says so.
  final int resent;

  /// Counts the tries to open a mail app on a phone with none; a change
  /// says so.
  final int noMailApp;

  /// Why the last resend failed (connection, server), with a retry.
  final Failure? failure;

  Duration get waitLeft =>
      resendAt.isAfter(now) ? resendAt.difference(now) : Duration.zero;

  bool get waiting => waitLeft > Duration.zero;

  bool get canResend => !waiting && !resending;

  CheckEmailState copyWith({
    DateTime? now,
    DateTime? resendAt,
    int? sends,
    bool? resending,
    int? resent,
    int? noMailApp,
    Failure? Function()? failure,
  }) => CheckEmailState(
    email: email,
    now: now ?? this.now,
    resendAt: resendAt ?? this.resendAt,
    sends: sends ?? this.sends,
    resending: resending ?? this.resending,
    resent: resent ?? this.resent,
    noMailApp: noMailApp ?? this.noMailApp,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    email,
    now,
    resendAt,
    sends,
    resending,
    resent,
    noMailApp,
    failure,
  ];
}

/// "Check your email" (requirements v3.0 §5.2 step 2, design "Check
/// Email"): opens the mail app, and sends the link again after a wait that
/// grows each time. Like the step before, a resend says nothing about the
/// email: too many requests count as sent.
class CheckEmailCubit extends Cubit<CheckEmailState> {
  CheckEmailCubit(
    this._accounts,
    this._mailApp, {
    required String email,
    DateTime Function()? now,
  }) : _countdown = WaitCountdown(now: now),
       super(_first(email, (now ?? DateTime.now)())) {
    _wait(state.resendAt);
  }

  static CheckEmailState _first(String email, DateTime now) =>
      CheckEmailState(email: email, now: now, resendAt: now.add(waits.first));

  final AccountRepository _accounts;
  final MailApp _mailApp;
  final WaitCountdown _countdown;

  /// The wait before each resend, the last one repeating (S §5.2).
  static const waits = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  Future<void> openMailApp() async {
    final opened = await _mailApp.open();
    if (!opened && !isClosed) {
      emit(state.copyWith(noMailApp: state.noMailApp + 1));
    }
  }

  Future<void> resend() async {
    if (!state.canResend) return;
    emit(state.copyWith(resending: true, failure: () => null));
    final result = await _accounts.requestPasswordReset(state.email);
    if (isClosed) return;
    switch (result) {
      case Ok() || Err(failure: RateLimitFailure()):
        final now = _countdown.now();
        final next = waits[state.sends.clamp(0, waits.length - 1)];
        final resendAt = now.add(next);
        emit(
          state.copyWith(
            resending: false,
            sends: state.sends + 1,
            resent: state.resent + 1,
            now: now,
            resendAt: resendAt,
          ),
        );
        _wait(resendAt);
      case Err(:final failure):
        emit(state.copyWith(resending: false, failure: () => failure));
    }
  }

  void _wait(DateTime until) => _countdown.start(
    until,
    onTick: (now) => emit(state.copyWith(now: now)),
    onEnd: (now) => emit(state.copyWith(now: now)),
  );

  @override
  Future<void> close() {
    _countdown.cancel();
    return super.close();
  }
}
