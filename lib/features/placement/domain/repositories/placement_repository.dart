import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';

abstract interface class PlacementRepository {
  /// The published placement test, as introduced to the learner.
  Future<Result<PlacementSummary>> getSummary();

  /// Where this account stands with the test. With no connection, the last
  /// status this account got on this phone, its days brought up to date;
  /// `NetworkFailure` only when there is none.
  Future<Result<PlacementStatus>> getStatus();

  /// Throws away the unfinished test, so the questions begin a new one.
  Future<Result<void>> restartTest();

  /// Puts the test off: the learner starts from the track's first level, and
  /// the test stays available.
  Future<Result<void>> deferTest();
}
