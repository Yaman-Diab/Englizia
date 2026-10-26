import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each audience gets its own v0.1 path', () {
    expect(onboardingStepsFor(OnboardingAudience.self), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.reason,
      OnboardingStep.saveProgress,
    ]);
    expect(onboardingStepsFor(OnboardingAudience.schoolStudent), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.grade,
      OnboardingStep.reason,
      OnboardingStep.saveProgress,
    ]);
    // Children skip the reasons step (and their profile step is v0.5).
    expect(onboardingStepsFor(OnboardingAudience.child), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.saveProgress,
    ]);
  });

  test('before the audience is chosen the adult path is assumed', () {
    expect(
      onboardingStepsFor(null),
      onboardingStepsFor(OnboardingAudience.self),
    );
  });

  test('position counts steps of the actual path, not a fixed total', () {
    expect(onboardingPosition(OnboardingStep.language), (current: 1, total: 4));
    expect(
      onboardingPosition(
        OnboardingStep.reason,
        audience: OnboardingAudience.schoolStudent,
      ),
      (current: 4, total: 5),
    );
  });
}
