import 'package:englizia/core/l10n/localized_text.dart';
import 'package:equatable/equatable.dart';

/// A published level (or grade, or book) of a track, as configured in the
/// control panel (server doc §6.6).
final class TrackLevel extends Equatable {
  const TrackLevel({
    required this.id,
    required this.order,
    required this.name,
    this.schoolGrade,
    this.group,
  });

  final String id;

  /// Display order; the first level is where a direct start begins.
  final int order;

  /// Shown name, e.g. "الصف السابع" or "A2 · ما قبل المتوسط".
  final LocalizedText name;

  /// 1–12 for school-curriculum tracks, otherwise null.
  final int? schoolGrade;

  /// Display group such as "الحلقة الأولى"; null when the track has none.
  final LocalizedText? group;

  @override
  List<Object?> get props => [id, order, name, schoolGrade, group];
}
