import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each audience gets its own v0.1 path', () {
    expect(onboardingStepsFor(TrackAudience.self), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.reason,
      OnboardingStep.saveProgress,
    ]);
    expect(onboardingStepsFor(TrackAudience.schoolStudent), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.grade,
      OnboardingStep.reason,
      OnboardingStep.saveProgress,
    ]);
    // Children get their profile instead of the reasons step.
    expect(onboardingStepsFor(TrackAudience.child), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.childProfile,
      OnboardingStep.saveProgress,
    ]);
  });

  test('before the audience is chosen the adult path is assumed', () {
    expect(onboardingStepsFor(null), onboardingStepsFor(TrackAudience.self));
  });

  test('position counts steps of the actual path, not a fixed total', () {
    expect(onboardingPosition(OnboardingStep.language), (current: 1, total: 4));
    expect(
      onboardingPosition(
        OnboardingStep.reason,
        audience: TrackAudience.schoolStudent,
      ),
      (current: 4, total: 5),
    );
  });

  test('the next step depends on who will learn', () {
    expect(
      onboardingNextStep(OnboardingStep.audience, audience: TrackAudience.self),
      OnboardingStep.reason,
    );
    expect(
      onboardingNextStep(
        OnboardingStep.audience,
        audience: TrackAudience.schoolStudent,
      ),
      OnboardingStep.grade,
    );
    expect(
      onboardingNextStep(
        OnboardingStep.audience,
        audience: TrackAudience.child,
      ),
      OnboardingStep.childProfile,
    );
    expect(onboardingNextStep(OnboardingStep.saveProgress), isNull);
  });
}
