import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';

abstract interface class ProfileRepository {
  /// The profile as last seen on this phone, to show at once.
  Profile? get keptProfile;

  Future<Result<Profile>> getProfile();

  Future<Result<void>> rename(String name);

  /// Makes another joined track the active one; each keeps its progress.
  Future<Result<void>> switchTrack(String enrollmentId);

  /// Another level of the same track: an Emar learner's grade.
  Future<Result<void>> changeLevel(String enrollmentId, String levelId);

  /// True the first time «أنا» is seen on [day]: the band and the numbers
  /// move only then.
  bool firstViewOn(DateTime day);
}
