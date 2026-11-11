import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:equatable/equatable.dart';

/// What the splash shows (design Splash Form).
enum SplashMode {
  /// The guide and the name, while the session and the versions load.
  loading,

  /// Signed out without a connection: the first open needs one (state 04).
  offline,

  /// Older than the minimum version: no way on but the store (state 05).
  update,

  /// On to home or welcome.
  done,
}

final class SplashState extends Equatable {
  const SplashState({
    this.mode = SplashMode.loading,
    this.slow = false,
    this.retrying = false,
    this.storeFailed = false,
    this.storePage,
    this.need = UpdateNeed.none,
  });

  final SplashMode mode;

  /// Loading has taken over three seconds: «جاري التحميل…».
  final bool slow;

  /// A retry without a connection is checking again.
  final bool retrying;

  /// Neither the store nor its page opened (state 06).
  final bool storeFailed;

  /// The store's page to copy into a browser; none when unknown.
  final Uri? storePage;

  /// What this version must do about updating: a reminder on home when
  /// suggested.
  final UpdateNeed need;

  LaunchStatus get launch => switch (mode) {
    SplashMode.update => LaunchStatus.updateRequired,
    SplashMode.done => LaunchStatus.ready,
    SplashMode.loading || SplashMode.offline => LaunchStatus.starting,
  };

  SplashState copyWith({
    SplashMode? mode,
    bool? slow,
    bool? retrying,
    bool? storeFailed,
    Uri? Function()? storePage,
    UpdateNeed? need,
  }) => SplashState(
    mode: mode ?? this.mode,
    slow: slow ?? this.slow,
    retrying: retrying ?? this.retrying,
    storeFailed: storeFailed ?? this.storeFailed,
    storePage: storePage != null ? storePage() : this.storePage,
    need: need ?? this.need,
  );

  @override
  List<Object?> get props => [
    mode,
    slow,
    retrying,
    storeFailed,
    storePage,
    need,
  ];
}
