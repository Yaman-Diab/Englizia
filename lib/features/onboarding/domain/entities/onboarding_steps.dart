import 'package:englizia/features/tracks/domain/entities/learning_track.dart';

/// Onboarding steps shipped in v0.1 (requirements v3.0 §4.2), in order.
/// Steps of later versions (child profile, goal, challenge, level, reminder)
/// are added here when built; until then they are skipped without a gap.
enum OnboardingStep { language, audience, grade, reason, saveProgress }

/// The steps of the path the learner is on. Before [audience] is known the
/// adult path is assumed, so the bar never jumps backwards for most learners.
List<OnboardingStep> onboardingStepsFor(TrackAudience? audience) => [
  OnboardingStep.language,
  OnboardingStep.audience,
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
