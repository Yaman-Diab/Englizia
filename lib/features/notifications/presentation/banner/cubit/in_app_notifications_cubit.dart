import 'package:englizia/core/notifications/push_message.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class InAppNotificationsState extends Equatable {
  const InAppNotificationsState({
    this.showing,
    this.serial = 0,
    this.meDot = false,
  });

  /// The banner on screen, or none.
  final PushMessage? showing;

  /// Counts the banners shown, so a newer one replaces the one on screen
  /// even when they are alike.
  final int serial;

  /// A teacher's reply came during a lesson: «أنا» carries a dot.
  final bool meDot;

  InAppNotificationsState copyWith({
    PushMessage? Function()? showing,
    int? serial,
    bool? meDot,
  }) => InAppNotificationsState(
    showing: showing != null ? showing() : this.showing,
    serial: serial ?? this.serial,
    meDot: meDot ?? this.meDot,
  );

  @override
  List<Object?> get props => [showing, serial, meDot];
}

/// Notifications that arrive while the app is open (design
/// "Notifications"): one banner at a time, a newer one in its place. None
/// while the learner is learning: a teacher's reply then leaves a dot on
/// «أنا», and a reminder is dropped, as they are learning already.
class InAppNotificationsCubit extends Cubit<InAppNotificationsState> {
  InAppNotificationsCubit(this._storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(InAppNotificationsState(meDot: _storage.meDot));

  final SettingsStorageService _storage;
  final DateTime Function() _now;

  String get _today {
    final day = _now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  /// [learning]: a lesson, a test, the microphone, onboarding or the
  /// reminders' prompt is on screen.
  Future<void> arrived(PushMessage message, {required bool learning}) async {
    if (learning) {
      if (message.kind == PushKind.teacherReply && !state.meDot) {
        emit(state.copyWith(meDot: true));
        await _storage.setMeDot(on: true);
      }
      return;
    }
    if (message.kind == PushKind.dailyGoal &&
        _storage.goalBannerOffDay == _today) {
      return;
    }
    emit(state.copyWith(showing: () => message, serial: state.serial + 1));
  }

  /// The banner [serial] has gone; a newer one stays.
  void dismissed(int serial) {
    if (serial == state.serial && state.showing != null) {
      emit(state.copyWith(showing: () => null));
    }
  }

  /// «لاحقًا» on the goal's banner: no more of them in the app today.
  Future<void> later() => _storage.setGoalBannerOffDay(_today);

  /// «أنا» opened, or the reply itself: the dot has done its work.
  Future<void> seenMe() async {
    if (!state.meDot) return;
    emit(state.copyWith(meDot: false));
    await _storage.setMeDot(on: false);
  }
}
