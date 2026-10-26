/// Who the account is for, chosen on the "who will learn" step.
enum OnboardingAudience { self, child, schoolStudent }

/// Onboarding steps shipped in v0.1 (requirements v3.0 §4.2), in order.
/// Steps of later versions (child profile, goal, challenge, level, reminder)
/// are added here when built; until then they are skipped without a gap.
enum OnboardingStep { language, audience, grade, reason, saveProgress }

/// The steps of the path the learner is on. Before [audience] is known the
/// adult path is assumed, so the bar never jumps backwards for most learners.
List<OnboardingStep> onboardingStepsFor(OnboardingAudience? audience) => [
  OnboardingStep.language,
  OnboardingStep.audience,
  if (audience == OnboardingAudience.schoolStudent) OnboardingStep.grade,
  if (audience != OnboardingAudience.child) OnboardingStep.reason,
  OnboardingStep.saveProgress,
];

/// Position of [step] on its path, for the progress bar (1-based).
({int current, int total}) onboardingPosition(
  OnboardingStep step, {
  OnboardingAudience? audience,
}) {
  final steps = onboardingStepsFor(audience);
  return (current: steps.indexOf(step) + 1, total: steps.length);
}
