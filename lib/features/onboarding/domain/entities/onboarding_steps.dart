import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:equatable/equatable.dart';

/// Onboarding steps that are built (requirements v3.0 §4.2), in order. The
/// child profile (v0.5) and the level question (v0.2) are built ahead of plan
/// at the owner's request. Steps of later versions (goal, challenge,
/// reminder) are added here when built; until then they are skipped without
/// a gap.
enum OnboardingStep {
  language,
  audience,
  childProfile,
  grade,
  reason,
  level,
  saveProgress,
}

/// Ages offered for a child learner (requirements v3.0 §4.2).
const childAges = [5, 6, 7, 8, 9];

/// The branch of onboarding the learner is on: who it is for, and the track
/// chosen for them with its entry method. The entry method decides the
/// branch (requirements §3.1), so a track changed in the control panel
/// changes the steps without a release.
final class OnboardingPath extends Equatable {
  const OnboardingPath({this.audience, this.trackId, this.entryMethod});

  OnboardingPath.forTrack(LearningTrack track)
    : this(
        audience: track.audience,
        trackId: track.id,
        entryMethod: track.entryMethod,
      );

  /// Before the learner says who will learn: an adult entering by the
  /// placement test, the most common path (requirements §3.2), so the bar
  /// rarely jumps backwards.
  static const assumed = OnboardingPath(
    audience: TrackAudience.self,
    entryMethod: TrackEntryMethod.placementTest,
  );

  final TrackAudience? audience;
  final String? trackId;
  final TrackEntryMethod? entryMethod;

  @override
  List<Object?> get props => [audience, trackId, entryMethod];
}

/// The steps of [path], in order.
List<OnboardingStep> onboardingStepsFor(OnboardingPath path) => [
  OnboardingStep.language,
  OnboardingStep.audience,
  if (path.audience == TrackAudience.child) OnboardingStep.childProfile,
  if (path.entryMethod == TrackEntryMethod.gradeSelection) OnboardingStep.grade,
  if (path.audience != TrackAudience.child) OnboardingStep.reason,
  if (path.entryMethod == TrackEntryMethod.placementTest) OnboardingStep.level,
  OnboardingStep.saveProgress,
];

/// Position of [step] on [path], for the progress bar (1-based).
({int current, int total}) onboardingPosition(
  OnboardingStep step, {
  OnboardingPath path = OnboardingPath.assumed,
}) {
  final steps = onboardingStepsFor(path);
  return (current: steps.indexOf(step) + 1, total: steps.length);
}

/// The step after [step] on [path], or null at the end.
OnboardingStep? onboardingNextStep(
  OnboardingStep step, {
  OnboardingPath path = OnboardingPath.assumed,
}) {
  final steps = onboardingStepsFor(path);
  final next = steps.indexOf(step) + 1;
  return next < steps.length ? steps[next] : null;
}
