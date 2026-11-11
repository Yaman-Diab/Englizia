import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/entities/social_session.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class SaveProgressState extends Equatable {
  const SaveProgressState({
    this.online = true,
    this.creatingGuest = false,
    this.guestSession,
    this.signingInWithGoogle = false,
    this.googleSession,
    this.failure,
  });

  /// Every way to save needs a connection; without it the buttons wait.
  final bool online;

  /// The guest account is being created.
  final bool creatingGuest;

  /// The new guest's session, handed to the next screen, which starts it.
  final AuthTokens? guestSession;

  /// Google's sheet is open, or the server is answering.
  final bool signingInWithGoogle;

  /// The session Google gave, handed on: a new account's goes to "preparing",
  /// one that existed already just signs in.
  final SocialSession? googleSession;

  /// Why the last attempt failed, shown with a retry until the next one.
  final Failure? failure;

  bool get busy =>
      creatingGuest ||
      guestSession != null ||
      signingInWithGoogle ||
      googleSession != null;

  SaveProgressState copyWith({
    bool? online,
    bool? creatingGuest,
    AuthTokens? guestSession,
    bool? signingInWithGoogle,
    SocialSession? googleSession,
    Failure? Function()? failure,
  }) => SaveProgressState(
    online: online ?? this.online,
    creatingGuest: creatingGuest ?? this.creatingGuest,
    guestSession: guestSession ?? this.guestSession,
    signingInWithGoogle: signingInWithGoogle ?? this.signingInWithGoogle,
    googleSession: googleSession ?? this.googleSession,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    online,
    creatingGuest,
    guestSession,
    signingInWithGoogle,
    googleSession,
    failure,
  ];
}

/// "Save your progress" (requirements v3.0 §4.2–4.3, ADR 10): create an
/// account, or carry on as a guest of this phone. Continuing as a guest
/// creates the guest account with the onboarding answers and hands its
/// session on (`SaveProgressState.guestSession`) to be started next. Google
/// makes the account in one step, or signs in to the one it has
/// (`SaveProgressState.googleSession`).
class SaveProgressCubit extends Cubit<SaveProgressState> {
  SaveProgressCubit(this._accounts, this._connectivity)
    : super(const SaveProgressState());

  final AccountRepository _accounts;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connection;

  /// The try that failed, to repeat.
  Future<void> Function()? _lastTry;

  /// Starts following the connection.
  Future<void> start() async {
    _connection ??= _connectivity.onlineChanges.listen(
      (online) => emit(state.copyWith(online: online)),
    );
    final online = await _connectivity.isOnline();
    if (!isClosed) emit(state.copyWith(online: online));
  }

  Future<void> continueAsGuest({
    required OnboardingPath answers,
    required String languageCode,
    required int utcOffsetMinutes,
  }) async {
    if (state.busy) return;
    _lastTry = () => continueAsGuest(
      answers: answers,
      languageCode: languageCode,
      utcOffsetMinutes: utcOffsetMinutes,
    );
    emit(state.copyWith(creatingGuest: true, failure: () => null));
    final result = await _accounts.createGuestAccount(
      answers: answers,
      languageCode: languageCode,
      utcOffsetMinutes: utcOffsetMinutes,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(guestSession: value));
      case Err(:final failure):
        emit(state.copyWith(creatingGuest: false, failure: () => failure));
    }
  }

  /// Opens Google's sheet; closing it changes nothing.
  Future<void> continueWithGoogle() async {
    if (state.busy) return;
    _lastTry = continueWithGoogle;
    emit(state.copyWith(signingInWithGoogle: true, failure: () => null));
    final result = await _accounts.signInWithGoogle();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value?):
        emit(state.copyWith(googleSession: value));
      case Ok():
        emit(state.copyWith(signingInWithGoogle: false));
      case Err(:final failure):
        emit(
          state.copyWith(signingInWithGoogle: false, failure: () => failure),
        );
    }
  }

  /// Repeats the try that failed, by the same way.
  Future<void> retry() async => _lastTry?.call();

  @override
  Future<void> close() async {
    await _connection?.cancel();
    return super.close();
  }
}
