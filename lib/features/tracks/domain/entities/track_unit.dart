import 'package:englizia/core/l10n/localized_text.dart';
import 'package:equatable/equatable.dart';

/// A published unit of a level (server doc §6.6): what the learner meets
/// first after onboarding.
final class TrackUnit extends Equatable {
  const TrackUnit({
    required this.id,
    required this.order,
    required this.title,
    this.topic,
  });

  final String id;

  /// Display order within the level; the first unit is where a level starts.
  final int order;

  /// As the course writes it, usually English ("Unit 1: Back to School").
  final String title;

  /// What the unit is about, in the learner's language ("التحيات والتعارف").
  final LocalizedText? topic;

  @override
  List<Object?> get props => [id, order, title, topic];
}
