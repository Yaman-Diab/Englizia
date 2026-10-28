import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class SaveProgressState extends Equatable {
  const SaveProgressState({
    this.online = true,
    this.creatingGuest = false,
    this.guestSession,
    this.failure,
  });

  /// Every way to save needs a connection; without it the buttons wait.
  final bool online;

  /// The guest account is being created.
  final bool creatingGuest;

  /// The new guest's session, handed to the next screen, which starts it.
  final AuthTokens? guestSession;

  /// Why the last attempt failed, shown with a retry until the next one.
  final Failure? failure;

  bool get busy => creatingGuest || guestSession != null;

  SaveProgressState copyWith({
    bool? online,
    bool? creatingGuest,
    AuthTokens? guestSession,
    Failure? Function()? failure,
  }) => SaveProgressState(
    online: online ?? this.online,
    creatingGuest: creatingGuest ?? this.creatingGuest,
    guestSession: guestSession ?? this.guestSession,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [online, creatingGuest, guestSession, failure];
}

/// "Save your progress" (requirements v3.0 §4.2–4.3, ADR 10): create an
/// account, or carry on as a guest of this phone. Continuing as a guest
/// creates the guest account with the onboarding answers and hands its
/// session on (`SaveProgressState.guestSession`) to be started next.
class SaveProgressCubit extends Cubit<SaveProgressState> {
  SaveProgressCubit(this._accounts, this._connectivity)
    : super(const SaveProgressState());

  final AccountRepository _accounts;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connection;

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

  @override
  Future<void> close() async {
    await _connection?.cancel();
    return super.close();
  }
}
