import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/domain/repositories/home_repository.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_state.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:englizia/features/home/presentation/home/cubit/home_state.dart';

/// What home cheers with a sound (silent for now, D-037).
enum HomeCheer { goal, unit, level }

/// The «تعلّم» tab (S §6.1, design "Home Archipelago"): what was kept shows at
/// once, then the server's; the phone's own completions and resume points win
/// over it; a return from a lesson says what to celebrate.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(
    this._home,
    this._profiles,
    this._lessons,
    this._connectivity,
    this._sounds, {
    ClipPlayer? player,
    DateTime Function()? now,
  }) : _voice = ClipPlayback(player ?? SilentClipPlayer()),
       _now = now ?? DateTime.now,
       super(HomeState(now: (now ?? DateTime.now)()));

  final HomeRepository _home;
  final ProfileRepository _profiles;
  final LessonRepository _lessons;
  final ConnectivityService _connectivity;
  final SoundPlayer _sounds;

  /// The kids' greeting and unit names (silent for now, D-050).
  final ClipPlayback _voice;
  final DateTime Function() _now;
  StreamSubscription<bool>? _changes;
  Timer? _clock;

  /// A page covers home ([left]), or a return is being compared: what shows
  /// stays as drawn, so the return's moment plays on it, and a refresh's
  /// answer is [_held] for the return.
  var _away = false;
  var _returning = 0;
  HomeSnapshot? _held;

  bool get _holding => (_away || _returning > 0) && state.home != null;

  /// The return being compared: another one meanwhile joins it.
  Future<void>? _comparing;

  /// Home's fetches so far, so a late answer knows a newer one started.
  var _fetches = 0;

  /// How long a return waits for the server before celebrating what the
  /// phone knows.
  static const returnWait = Duration(seconds: 2);

  /// The clock's tick, for the greeting, the risk and the day's end.
  static const tick = Duration(minutes: 1);

  Future<void> start() async {
    final track = _profiles.keptProfile?.active;
    final kept = _home.keptHome;
    final now = _now();
    emit(
      state.copyWith(
        now: now,
        trackTitle: () => track?.title,
        kidsHint: track?.audience == TrackAudience.child,
        seenEvents: _home.seenEvents,
        openingDue: !_home.openingShownOn(_dayKey(now, kept)),
      ),
    );
    if (kept != null) {
      emit(state.copyWith(load: LoadStatus.ready, home: _merged(kept)));
    }
    _changes ??= _connectivity.onlineChanges.listen((online) {
      if (isClosed) return;
      emit(state.copyWith(online: online));
      if (online) unawaited(refresh());
    });
    _clock ??= Timer.periodic(tick, (_) => _tick());
    final online = await _connectivity.isOnline();
    if (isClosed) return;
    emit(state.copyWith(online: online));
    await refresh();
  }

  /// Fetches home again; true when it came. Shown data stays when it fails:
  /// [byUser] says «تعذّر التحديث», an automatic one without a connection
  /// shows the offline strip.
  Future<bool> refresh({bool byUser = false}) async {
    emit(
      state.copyWith(
        refreshing: true,
        load: state.home == null ? LoadStatus.loading : null,
        failure: state.home == null ? () => null : null,
      ),
    );
    final result = await _fetch();
    if (isClosed) return false;
    switch (result) {
      case Ok(:final value) when _holding:
        _held = value;
        emit(
          state.copyWith(
            refreshing: false,
            offlineFetch: false,
            refreshFailed: false,
          ),
        );
        return true;
      case Ok(:final value):
        _show(value);
        return true;
      case Err(:final failure):
        if (state.home == null) {
          emit(
            state.copyWith(
              refreshing: false,
              load: LoadStatus.failure,
              failure: () => failure,
            ),
          );
        } else {
          emit(
            state.copyWith(
              refreshing: false,
              refreshFailed: byUser ? true : null,
              offlineFetch: !byUser && failure is NetworkFailure ? true : null,
            ),
          );
        }
        return false;
    }
  }

  /// A page covers home now (a lesson, a unit): what shows stays as it was
  /// drawn until [returned] compares with it; a refresh meanwhile keeps
  /// its answer for then.
  void left() => _away = true;

  /// Back on the screen from a page over it: what changed meanwhile, and
  /// what to celebrate. Waits [returnWait] for the server, then trusts the
  /// home last fetched, with the phone's; a later answer still shows, with
  /// nothing to celebrate. One return is compared at a time: another one
  /// meanwhile joins it, so a moment plays once.
  Future<void> returned() {
    _away = false;
    return _comparing ??= _compare().whenComplete(() => _comparing = null);
  }

  Future<void> _compare() async {
    final before = state.home;
    if (before == null) {
      _held = null;
      await refresh();
      return;
    }
    _returning++;
    final fetch = _fetch();
    final number = _fetches;
    var late = false;
    final Result<HomeSnapshot> result;
    try {
      result = await fetch.timeout(
        returnWait,
        onTimeout: () {
          late = true;
          return const Err(UnknownFailure());
        },
      );
    } finally {
      _returning--;
    }
    if (isClosed) return;
    final fetched = switch (result) {
      Ok(:final value) => value,
      Err() => _held,
    };
    _held = null;
    final after = _merged(fetched ?? before);
    final moment = HomeRules.diff(before, after);
    final levelDone = moment is UnitDoneMoment && moment.levelDone;
    emit(
      state.copyWith(
        load: LoadStatus.ready,
        failure: () => null,
        home: after,
        moment: moment == null ? null : () => moment,
        momentId: moment == null ? null : state.momentId + 1,
        levelJustDone: levelDone ? true : null,
        offlineFetch: switch (result) {
          Ok() => false,
          Err(failure: NetworkFailure()) => true,
          Err() => null,
        },
        refreshFailed: result is Ok ? false : null,
      ),
    );
    if (fetched != null) _preload(after);
    if (late) unawaited(_lateAnswer(fetch, number));
  }

  /// A return's answer that came after [returnWait]: shown as a refresh's
  /// would be, unless a newer fetch has started since.
  Future<void> _lateAnswer(
    Future<Result<HomeSnapshot>> fetch,
    int number,
  ) async {
    final result = await fetch;
    if (isClosed || number != _fetches) return;
    if (result case Ok(:final value)) {
      if (_holding) {
        _held = value;
      } else {
        _show(value);
      }
    }
  }

  Future<Result<HomeSnapshot>> _fetch() {
    _fetches++;
    return _home.getHome();
  }

  /// The opening has played: not again today.
  void openingPlayed() {
    unawaited(_home.setOpeningShown(_dayKey(state.now, state.home)));
    emit(state.copyWith(openingDue: false));
  }

  void momentPlayed() => emit(state.copyWith(moment: () => null));

  /// A one-time notice closed: never shown again here.
  Future<void> closeEvent(String id) async {
    emit(state.copyWith(seenEvents: {...state.seenEvents, id}));
    await _home.markEventSeen(id);
  }

  void dismissRefreshFailure() => emit(state.copyWith(refreshFailed: false));

  /// Makes [track] the active one, then loads its home. The opening doesn't
  /// play again for it.
  Future<Failure?> switchTrack(ProfileTrack track) async {
    emit(state.copyWith(switching: true));
    final switched = await _profiles.switchTrack(track.enrollmentId);
    if (isClosed) return null;
    if (switched case Err(:final failure)) {
      emit(state.copyWith(switching: false));
      return failure;
    }
    final result = await _fetch();
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        _show(value);
        emit(
          state.copyWith(
            switching: false,
            switches: state.switches + 1,
            switchedTo: () => track.title,
            trackTitle: () => track.title,
            levelJustDone: false,
          ),
        );
        return null;
      case Err(:final failure):
        emit(state.copyWith(switching: false));
        return failure;
    }
  }

  /// «ابدأ B1»: the next level, then its home.
  Future<Failure?> startNextLevel() async {
    final home = state.home;
    final next = home?.level.next;
    if (home == null || next == null) return null;
    final result = await _profiles.changeLevel(home.enrollment.id, next.id);
    if (isClosed) return null;
    if (result case Err(:final failure)) return failure;
    emit(state.copyWith(levelJustDone: false));
    await refresh();
    return null;
  }

  void cheer(HomeCheer cheer) => unawaited(
    _sounds.play(switch (cheer) {
      HomeCheer.goal => AppSound.goalReached,
      HomeCheer.unit || HomeCheer.level => AppSound.achievement,
    }),
  );

  /// Kids: «استمع» says the greeting, once the server sends its recording
  /// (D36).
  Future<void> sayGreeting() => _say(state.home?.learner.greetingAudioUrl);

  /// Kids: today's unit says its name (M14).
  Future<void> sayUnit() => _say(state.home?.currentUnit?.titleAudioUrl);

  Future<void> _say(String? url) async {
    if (url == null || isClosed) return;
    await _voice.start(url, onEnd: () {});
  }

  /// [home] with what the phone knows, on the learner's day (A30).
  HomeSnapshot _merged(HomeSnapshot home) =>
      HomeRules.asOf(home.withPhone(_lessons.onPhone), state.now);

  void _show(HomeSnapshot fresh) {
    final home = _merged(fresh);
    emit(
      state.copyWith(
        load: LoadStatus.ready,
        failure: () => null,
        home: home,
        refreshing: false,
        offlineFetch: false,
        refreshFailed: false,
      ),
    );
    _preload(home);
  }

  /// The current lesson, so «تابع» opens offline too.
  void _preload(HomeSnapshot home) {
    final unit = home.currentUnit;
    if (unit == null) return;
    final index = unit.currentLesson;
    if (index >= unit.lessons.length) return;
    unawaited(_lessons.getLesson(unit.lessons[index].id));
  }

  /// A new learner's day rolls today over on the phone at once (A30), then
  /// asks the server.
  void _tick() {
    if (isClosed) return;
    final home = state.home;
    final before = _dayKey(state.now, home);
    final now = _now();
    final newDay = _dayKey(now, home) != before;
    emit(
      state.copyWith(
        now: now,
        home: newDay && home != null ? HomeRules.asOf(home, now) : null,
      ),
    );
    if (newDay) unawaited(refresh());
  }

  static String _dayKey(DateTime now, HomeSnapshot? home) {
    final start = home?.week?.dayStart ?? '';
    return HomeRules.dayKey(
      now,
      start.isEmpty ? HomeRules.defaultDayStart : start,
    );
  }

  @override
  Future<void> close() {
    _voice.stop();
    _clock?.cancel();
    unawaited(_changes?.cancel());
    return super.close();
  }
}
