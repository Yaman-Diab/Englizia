import 'package:englizia/features/tracks/domain/entities/learning_track.dart';

/// Onboarding steps that are built (requirements v3.0 §4.2), in order. The
/// child profile is a v0.5 step built ahead of plan at the owner's request.
/// Steps of later versions (goal, challenge, level, reminder) are added here
/// when built; until then they are skipped without a gap.
enum OnboardingStep {
  language,
  audience,
  childProfile,
  grade,
  reason,
  saveProgress,
}

/// Ages offered for a child learner (requirements v3.0 §4.2).
const childAges = [5, 6, 7, 8, 9];

/// The steps of the path the learner is on. Before [audience] is known the
/// adult path is assumed, so the bar never jumps backwards for most learners.
List<OnboardingStep> onboardingStepsFor(TrackAudience? audience) => [
  OnboardingStep.language,
  OnboardingStep.audience,
  if (audience == TrackAudience.child) OnboardingStep.childProfile,
  if (audience == TrackAudience.schoolStudent) OnboardingStep.grade,
  if (audience != TrackAudience.child) OnboardingStep.reason,
  OnboardingStep.saveProgress,
];

/// Position of [step] on its path, for the progress bar (1-based).
({int current, int total}) onboardingPosition(
  OnboardingStep step, {
  TrackAudience? audience,
}) {
  final steps = onboardingStepsFor(audience);
  return (current: steps.indexOf(step) + 1, total: steps.length);
}

/// The step after [step] on the learner's path, or null at the end.
OnboardingStep? onboardingNextStep(
  OnboardingStep step, {
  TrackAudience? audience,
}) {
  final steps = onboardingStepsFor(audience);
  final next = steps.indexOf(step) + 1;
  return next < steps.length ? steps[next] : null;
}
