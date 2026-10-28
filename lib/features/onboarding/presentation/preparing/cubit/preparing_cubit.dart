import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/preparing/cubit/preparing_state.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'preparing_state.dart';

/// "Preparing" after the account is created (requirements v3.0 §4.4,
/// design "Preparing"): three real steps, one after another — start the
/// session at the level or grade, load the first unit (or the placement
/// test), settle the daily goal. A step that fails waits for a retry, which
/// resumes from it.
class PreparingCubit extends Cubit<PreparingState> {
  PreparingCubit(
    this._session,
    this._tracks,
    this._placement,
    this._settings, {
    this.minimumStep = defaultMinimumStep,
  }) : super(const PreparingState());

  final AppSessionController _session;
  final TrackRepository _tracks;
  final PlacementRepository _placement;
  final SettingsRepository _settings;

  /// No step ends sooner, so the screen lasts at least 1.5 s and never just
  /// flashes by (design); real loading longer than that is not padded.
  final Duration minimumStep;
  static const defaultMinimumStep = Duration(milliseconds: 500);

  late OnboardingPath _path;
  late AuthTokens _account;
  bool _running = false;

  /// The steps of [path]'s branch.
  static List<PreparingStepKind> stepsFor(OnboardingPath path) => [
    if (path.placementTest)
      PreparingStepKind.plan
    else if (path.grade != null)
      PreparingStepKind.grade
    else
      PreparingStepKind.level,
    if (path.placementTest) PreparingStepKind.test else PreparingStepKind.unit,
    PreparingStepKind.goal,
  ];

  Future<void> start({
    required OnboardingPath path,
    required AuthTokens account,
  }) {
    _path = path;
    _account = account;
    emit(
      PreparingState(
        steps: [for (final kind in stepsFor(path)) PreparingStep(kind)],
        level: path.grade ?? path.startLevel,
      ),
    );
    return _runFrom(0);
  }

  /// Resumes from the step that failed.
  Future<void> retry() async {
    final failed = state.steps.indexWhere(
      (step) => step.status == PreparingStepStatus.failed,
    );
    if (failed >= 0) await _runFrom(failed);
  }

  Future<void> _runFrom(int first) async {
    if (_running) return;
    _running = true;
    try {
      for (var i = first; i < state.steps.length; i++) {
        emit(
          state
              .withStatus(i, PreparingStepStatus.running)
              .copyWith(failure: () => null),
        );
        final work = _perform(state.steps[i].kind);
        await Future<void>.delayed(minimumStep);
        final failure = await work;
        if (isClosed) return;
        if (failure != null) {
          emit(
            state
                .withStatus(i, PreparingStepStatus.failed)
                .copyWith(failure: () => failure),
          );
          return;
        }
        emit(state.withStatus(i, PreparingStepStatus.done));
      }
    } finally {
      _running = false;
    }
  }

  /// Does [kind]'s work and keeps what it found; the failure, if any.
  Future<Failure?> _perform(PreparingStepKind kind) async {
    switch (kind) {
      case PreparingStepKind.level ||
          PreparingStepKind.grade ||
          PreparingStepKind.plan:
        // Router: "preparing" stays open when the session starts.
        await _session.signIn(_account);
        if (kind == PreparingStepKind.level) return _settleLevel();
        return null;
      case PreparingStepKind.unit:
        final levelId = state.level?.id;
        if (levelId == null) return null;
        switch (await _tracks.getUnits(levelId)) {
          case Ok(:final value):
            if (value.firstOrNull case final unit?) {
              emit(state.copyWith(unit: unit));
            }
            return null;
          case Err(:final failure):
            return failure;
        }
      case PreparingStepKind.test:
        switch (await _placement.getSummary()) {
          case Ok(:final value):
            emit(state.copyWith(test: value));
            return null;
          case Err(:final failure):
            return failure;
        }
      case PreparingStepKind.goal:
        if (_path.dailyGoalMinutes case final minutes?) {
          emit(state.copyWith(goalMinutes: minutes));
          return null;
        }
        switch (await _settings.getSettings()) {
          case Ok(:final value):
            emit(state.copyWith(goalMinutes: value.dailyGoal.defaultMinutes));
            return null;
          case Err(:final failure):
            return failure;
        }
    }
  }

  /// A track without a level step starts at its first level.
  Future<Failure?> _settleLevel() async {
    final trackId = _path.trackId;
    if (state.level != null || trackId == null) return null;
    switch (await _tracks.getLevels(trackId)) {
      case Ok(:final value):
        if (value.firstOrNull case final level?) {
          emit(state.copyWith(level: level));
        }
        return null;
      case Err(:final failure):
        return failure;
    }
  }
}
