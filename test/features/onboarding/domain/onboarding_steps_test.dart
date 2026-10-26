import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const general = OnboardingPath(
    audience: TrackAudience.self,
    trackId: 'general',
    entryMethod: TrackEntryMethod.placementTest,
  );
  const emar = OnboardingPath(
    audience: TrackAudience.schoolStudent,
    trackId: 'emar',
    entryMethod: TrackEntryMethod.gradeSelection,
  );
  const kids = OnboardingPath(
    audience: TrackAudience.child,
    trackId: 'kids',
    entryMethod: TrackEntryMethod.directStart,
  );

  test('the entry method decides the grade and level steps', () {
    expect(onboardingStepsFor(general), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.reason,
      OnboardingStep.level,
      OnboardingStep.saveProgress,
    ]);
    expect(onboardingStepsFor(emar), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.grade,
      OnboardingStep.reason,
      OnboardingStep.saveProgress,
    ]);
  });

  test('children get their profile instead of reasons', () {
    expect(onboardingStepsFor(kids), [
      OnboardingStep.language,
      OnboardingStep.audience,
      OnboardingStep.childProfile,
      OnboardingStep.saveProgress,
    ]);
  });

  test('a track switched to a direct start in the panel drops the level '
      'question', () {
    expect(
      onboardingStepsFor(
        const OnboardingPath(
          audience: TrackAudience.self,
          entryMethod: TrackEntryMethod.directStart,
        ),
      ),
      isNot(contains(OnboardingStep.level)),
    );
  });

  test('before the choice the common adult path is assumed', () {
    expect(
      onboardingStepsFor(OnboardingPath.assumed),
      onboardingStepsFor(general),
    );
    expect(onboardingPosition(OnboardingStep.language), (current: 1, total: 5));
  });

  test('position counts the steps of the actual path', () {
    expect(onboardingPosition(OnboardingStep.reason, path: emar), (
      current: 4,
      total: 5,
    ));
    expect(onboardingPosition(OnboardingStep.childProfile, path: kids), (
      current: 3,
      total: 4,
    ));
  });

  test('the next step follows the path', () {
    expect(
      onboardingNextStep(OnboardingStep.audience, path: general),
      OnboardingStep.reason,
    );
    expect(
      onboardingNextStep(OnboardingStep.audience, path: emar),
      OnboardingStep.grade,
    );
    expect(
      onboardingNextStep(OnboardingStep.audience, path: kids),
      OnboardingStep.childProfile,
    );
    expect(
      onboardingNextStep(OnboardingStep.reason, path: general),
      OnboardingStep.level,
    );
    expect(
      onboardingNextStep(OnboardingStep.reason, path: emar),
      OnboardingStep.saveProgress,
    );
    expect(onboardingNextStep(OnboardingStep.saveProgress), isNull);
  });

  test('a path is built from a track', () {
    const track = LearningTrack(
      id: 'emar',
      title: LocalizedText(ar: 'إيمار'),
      description: LocalizedText(ar: ''),
      order: 1,
      entryMethod: TrackEntryMethod.gradeSelection,
      audience: TrackAudience.schoolStudent,
    );
    expect(OnboardingPath.forTrack(track), emar);
  });
}
