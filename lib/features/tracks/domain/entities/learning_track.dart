import 'package:englizia/core/l10n/localized_text.dart';
import 'package:equatable/equatable.dart';

/// Who a track is suggested for on the onboarding "who will learn" step,
/// set per track in the control panel (server doc §5.2).
enum TrackAudience { self, child, schoolStudent }

/// How a learner enters the track (server doc §5.2).
enum TrackEntryMethod { placementTest, gradeSelection, directStart }

/// A published track as the app sees it. Tracks come from the server only:
/// a new one must never need a code change.
final class LearningTrack extends Equatable {
  const LearningTrack({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.entryMethod,
    this.audience,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText description;

  /// Display order set in the control panel.
  final int order;

  /// Null when the track is not suggested during onboarding.
  final TrackAudience? audience;
  final TrackEntryMethod entryMethod;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    order,
    audience,
    entryMethod,
  ];
}
