import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:englizia/features/tracks/domain/entities/track_unit.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';

LearningTrack fakeTrack(
  String id,
  TrackAudience? audience, {
  TrackEntryMethod entryMethod = TrackEntryMethod.directStart,
}) => LearningTrack(
  id: id,
  title: const LocalizedText(ar: 'مسار'),
  description: const LocalizedText(ar: ''),
  order: 0,
  entryMethod: entryMethod,
  audience: audience,
);

TrackLevel fakeGrade(int grade, {String group = 'الحلقة الأولى'}) => TrackLevel(
  id: 'g$grade',
  order: grade,
  name: LocalizedText(ar: 'الصف $grade', en: 'Grade $grade'),
  schoolGrade: grade,
  group: LocalizedText(ar: group, en: group),
);

/// Serves queued results in order, repeating the last one.
class FakeTrackRepository implements TrackRepository {
  FakeTrackRepository({
    this.tracks = const [Ok(<LearningTrack>[])],
    this.levels = const [Ok(<TrackLevel>[])],
    this.units = const [Ok(<TrackUnit>[])],
  });

  final List<Result<List<LearningTrack>>> tracks;
  final List<Result<List<TrackLevel>>> levels;
  final List<Result<List<TrackUnit>>> units;
  final unitRequests = <String>[];
  var trackCalls = 0;
  final levelRequests = <String>[];

  @override
  Future<Result<List<LearningTrack>>> getPublishedTracks() async =>
      tracks[(trackCalls++).clamp(0, tracks.length - 1)];

  @override
  Future<Result<List<TrackLevel>>> getLevels(String trackId) async {
    levelRequests.add(trackId);
    return levels[(levelRequests.length - 1).clamp(0, levels.length - 1)];
  }

  @override
  Future<Result<List<TrackUnit>>> getUnits(String levelId) async {
    unitRequests.add(levelId);
    return units[(unitRequests.length - 1).clamp(0, units.length - 1)];
  }
}
