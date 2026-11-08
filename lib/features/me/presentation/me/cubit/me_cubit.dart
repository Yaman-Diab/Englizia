import 'dart:math';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class MeState extends Equatable {
  const MeState({
    this.load = LoadStatus.loading,
    this.failure,
    this.profile,
    this.guest = false,
    this.firstView = false,
    this.published,
    this.levels,
    this.switching = false,
    this.switched,
    this.switches = 0,
    this.gate = 47,
    this.parentOpen = false,
  });

  final LoadStatus load;
  final Failure? failure;
  final Profile? profile;
  final bool guest;

  /// The day's first view: the band and the numbers move.
  final bool firstView;

  /// The published tracks, for «أضف مسارًا».
  final List<LearningTrack>? published;

  /// The active track's levels, for «تغيير الصف».
  final List<TrackLevel>? levels;
  final bool switching;

  /// What the learner just moved to: «انتقلت إلى …», told [switches] times.
  final String? switched;
  final int switches;

  /// Kids: the number the parent has to type, and whether they did.
  final int gate;
  final bool parentOpen;

  MeState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    Profile? profile,
    bool? guest,
    bool? firstView,
    List<LearningTrack>? published,
    List<TrackLevel>? levels,
    bool? switching,
    String? switched,
    int? switches,
    int? gate,
    bool? parentOpen,
  }) => MeState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    profile: profile ?? this.profile,
    guest: guest ?? this.guest,
    firstView: firstView ?? this.firstView,
    published: published ?? this.published,
    levels: levels ?? this.levels,
    switching: switching ?? this.switching,
    switched: switched ?? this.switched,
    switches: switches ?? this.switches,
    gate: gate ?? this.gate,
    parentOpen: parentOpen ?? this.parentOpen,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    profile,
    guest,
    firstView,
    published,
    levels,
    switching,
    switched,
    switches,
    gate,
    parentOpen,
  ];
}

/// «أنا» (S §19.1, §13.5; design "Me v2"): who the learner is, their tracks
/// and what they have done, with the name, the track and the grade to change.
/// Kids reach the parent's part through a number to type.
class MeCubit extends Cubit<MeState> {
  MeCubit(
    this._profiles,
    this._tracks, {
    required bool Function() isGuest,
    DateTime Function()? now,
    Random? random,
  }) : _isGuest = isGuest,
       _now = now ?? DateTime.now,
       _random = random ?? Random(),
       super(const MeState()) {
    emit(state.copyWith(gate: _nextGate()));
  }

  final ProfileRepository _profiles;
  final TrackRepository _tracks;
  final bool Function() _isGuest;
  final DateTime Function() _now;
  final Random _random;

  Future<void> start() async {
    emit(
      state.copyWith(
        guest: _isGuest(),
        firstView: _profiles.firstViewOn(_now()),
      ),
    );
    if (_profiles.keptProfile case final kept?) {
      emit(state.copyWith(load: LoadStatus.ready, profile: kept));
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (state.profile == null) {
      emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    }
    final result = await _profiles.getProfile();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            failure: () => null,
            profile: value,
            guest: _isGuest(),
          ),
        );
      case Err(:final failure):
        if (state.profile == null) {
          emit(
            state.copyWith(load: LoadStatus.failure, failure: () => failure),
          );
        }
    }
  }

  /// The failure, if it couldn't be saved.
  Future<Failure?> rename(String name) async {
    final profile = state.profile;
    final trimmed = name.trim();
    if (profile == null || trimmed.isEmpty || trimmed == profile.name) {
      return null;
    }
    emit(state.copyWith(profile: profile.copyWith(name: trimmed)));
    final result = await _profiles.rename(trimmed);
    if (isClosed) return null;
    if (result case Err(:final failure)) {
      emit(state.copyWith(profile: profile));
      return failure;
    }
    return null;
  }

  Future<Failure?> switchTrack(ProfileTrack track) async {
    final profile = state.profile;
    if (profile == null || track.active || state.switching) return null;
    emit(
      state.copyWith(
        switching: true,
        profile: profile.copyWith(
          tracks: [
            for (final each in profile.tracks)
              each.withActive(active: each.enrollmentId == track.enrollmentId),
          ],
        ),
      ),
    );
    final result = await _profiles.switchTrack(track.enrollmentId);
    if (isClosed) return null;
    return _afterChange(result, before: profile, told: () => track.title);
  }

  Future<Failure?> changeLevel(TrackLevel level) async {
    final profile = state.profile;
    final active = profile?.active;
    if (profile == null || active == null || state.switching) return null;
    if (level.id == active.levelId) return null;
    emit(state.copyWith(switching: true));
    final result = await _profiles.changeLevel(active.enrollmentId, level.id);
    if (isClosed) return null;
    return _afterChange(
      result,
      before: profile,
      told: () => state.profile?.active?.levelName ?? '',
    );
  }

  Future<Failure?> _afterChange(
    Result<void> result, {
    required Profile before,
    required String Function() told,
  }) async {
    switch (result) {
      case Ok():
        await refresh();
        if (isClosed) return null;
        emit(
          state.copyWith(
            switching: false,
            switched: told(),
            switches: state.switches + 1,
            levels: const [],
          ),
        );
        return null;
      case Err(:final failure):
        emit(state.copyWith(switching: false, profile: before));
        return failure;
    }
  }

  /// «أضف مسارًا» lists what is published.
  Future<void> loadPublished() async {
    final result = await _tracks.getPublishedTracks();
    if (isClosed) return;
    if (result case Ok(:final value)) emit(state.copyWith(published: value));
  }

  /// «تغيير الصف» lists the active track's grades.
  Future<void> loadLevels() async {
    final trackId = state.profile?.active?.trackId;
    if (trackId == null) return;
    final result = await _tracks.getLevels(trackId);
    if (isClosed) return;
    if (result case Ok(:final value)) emit(state.copyWith(levels: value));
  }

  /// Kids: the parent typed [answer]. Either way the next question differs.
  bool tryGate(String answer) {
    final right = int.tryParse(normalDigits(answer)) == state.gate;
    emit(state.copyWith(parentOpen: right, gate: _nextGate()));
    return right;
  }

  void lockParent() => emit(state.copyWith(parentOpen: false));

  /// A two-digit number with both its digits, so it reads as two words.
  int _nextGate() {
    while (true) {
      final number = 21 + _random.nextInt(79);
      if (number % 10 != 0 && number != state.gate) return number;
    }
  }

  /// Arabic-Indic and Persian digits as ASCII ones; anything else dropped.
  static String normalDigits(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        out.writeCharCode(rune);
      } else if (rune >= 0x660 && rune <= 0x669) {
        out.writeCharCode(0x30 + rune - 0x660);
      } else if (rune >= 0x6F0 && rune <= 0x6F9) {
        out.writeCharCode(0x30 + rune - 0x6F0);
      }
    }
    return out.toString();
  }
}
