import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/home/domain/entities/home.dart';

abstract interface class HomeRepository {
  /// Home as last received on this phone, to show at once; null when there is
  /// none or it can't be read.
  HomeSnapshot? get keptHome;

  /// Fresh from the server. Any failure is an [Err]: the screen keeps showing
  /// [keptHome] itself.
  Future<Result<HomeSnapshot>> getHome();

  /// The opening (M1) already played on the learner's day [dayKey].
  bool openingShownOn(String dayKey);

  Future<void> setOpeningShown(String dayKey);

  /// The one-time notices already shown on this phone.
  Set<String> get seenEvents;

  /// Keeps the last 20.
  Future<void> markEventSeen(String id);
}
