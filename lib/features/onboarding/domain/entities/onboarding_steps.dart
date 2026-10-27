import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/features/onboarding/domain/entities/learning_reason.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:equatable/equatable.dart';

/// Onboarding steps that are built (requirements v3.0 §4.2), in order. The
/// child profile (v0.5), the level question (v0.2), the daily goal, the
/// streak challenge and the reminder time (v1.0) are built ahead of plan at
/// the owner's request.
enum OnboardingStep {
  language,
  audience,
  childProfile,
  grade,
  reason,
  goal,
  challenge,
  level,
  reminder,
  saveProgress,
}

/// Ages offered for a child learner (requirements v3.0 §4.2).
const childAges = [5, 6, 7, 8, 9];

/// The branch of onboarding the learner is on, and the answers given so far.
/// The track's entry method decides the branch (requirements §3.1), so a
/// track changed in the control panel changes the steps without a release.
/// The answers travel with it to "save progress", which shows them in "your
/// plan" and sends them with the new account (S §4.3, ADR 10).
final class OnboardingPath extends Equatable {
  const OnboardingPath({
    this.audience,
    this.trackId,
    this.trackTitle,
    this.entryMethod,
    this.childName,
    this.childAge,
    this.grade,
    this.reasons = const [],
    this.dailyGoalMinutes,
    this.challengeDays,
    this.startLevel,
    this.placementTest = false,
    this.reminder,
  });

  OnboardingPath.forTrack(LearningTrack track)
    : this(
        audience: track.audience,
        trackId: track.id,
        trackTitle: track.title,
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
  final LocalizedText? trackTitle;
  final TrackEntryMethod? entryMethod;

  /// The child path's profile.
  final String? childName;
  final int? childAge;

  /// The school student's grade: a level of the curriculum track.
  final TrackLevel? grade;
  final List<LearningReason> reasons;

  /// The goal chosen on the goal step, in minutes; null until then.
  final int? dailyGoalMinutes;

  /// The streak challenge chosen, in days; null until then.
  final int? challengeDays;

  /// Where a learner who skips the placement test starts (now or later).
  final TrackLevel? startLevel;

  /// The learner went on to take the placement test.
  final bool placementTest;

  /// The daily reminder's time; null for none (or not asked yet).
  final ReminderTime? reminder;

  /// This path with the given answers set; the others stay.
  OnboardingPath copyWith({
    String? childName,
    int? childAge,
    TrackLevel? grade,
    List<LearningReason>? reasons,
    int? dailyGoalMinutes,
    int? challengeDays,
    TrackLevel? startLevel,
    bool? placementTest,
    ReminderTime? reminder,
  }) => OnboardingPath(
    audience: audience,
    trackId: trackId,
    trackTitle: trackTitle,
    entryMethod: entryMethod,
    childName: childName ?? this.childName,
    childAge: childAge ?? this.childAge,
    grade: grade ?? this.grade,
    reasons: reasons ?? this.reasons,
    dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    challengeDays: challengeDays ?? this.challengeDays,
    startLevel: startLevel ?? this.startLevel,
    placementTest: placementTest ?? this.placementTest,
    reminder: reminder ?? this.reminder,
  );

  @override
  List<Object?> get props => [
    audience,
    trackId,
    trackTitle,
    entryMethod,
    childName,
    childAge,
    grade,
    reasons,
    dailyGoalMinutes,
    challengeDays,
    startLevel,
    placementTest,
    reminder,
  ];
}

/// The steps of [path], in order.
List<OnboardingStep> onboardingStepsFor(OnboardingPath path) => [
  OnboardingStep.language,
  OnboardingStep.audience,
  if (path.audience == TrackAudience.child) OnboardingStep.childProfile,
  if (path.entryMethod == TrackEntryMethod.gradeSelection) OnboardingStep.grade,
  if (path.audience != TrackAudience.child) ...[
    OnboardingStep.reason,
    OnboardingStep.goal,
    OnboardingStep.challenge,
  ],
  if (path.entryMethod == TrackEntryMethod.placementTest) OnboardingStep.level,
  OnboardingStep.reminder,
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
