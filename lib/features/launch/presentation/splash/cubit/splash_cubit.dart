import 'dart:async';

import 'package:englizia/core/config/app_info.dart';
import 'package:englizia/core/links/app_store.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_state.dart';
import 'package:englizia/features/settings/domain/entities/app_version.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The app's opening (student doc §4.1, ADR 19): waits for the session and
/// the server's versions, then stops a version too old to run, holds a
/// signed-out first open until there is a connection, or lets the app on.
/// It lasts as long as the loading does, and once the splash shows, until
/// its intro has played ([introStarted], [introShown]): the guide is never
/// cut off. An app opened on a link, without the splash, doesn't wait.
class SplashCubit extends Cubit<SplashState> {
  SplashCubit({
    required AppSessionController session,
    required SettingsRepository settings,
    required ConnectivityService connectivity,
    required AppInfo app,
    required AppStore store,
  }) : _session = session,
       _settings = settings,
       _connectivity = connectivity,
       _app = app,
       _store = store,
       super(const SplashState());

  final AppSessionController _session;
  final SettingsRepository _settings;
  final ConnectivityService _connectivity;
  final AppInfo _app;
  final AppStore _store;

  static const slowAfter = Duration(seconds: 3);

  /// How long the versions may take before the kept ones decide, so a weak
  /// connection doesn't hold the learner here.
  // ASSUMPTION(design): no limit given; the slow indicator shows meanwhile.
  static const versionsWait = Duration(seconds: 8);

  /// A retry that finds no connection at once still shows it tried.
  static const retryAtLeast = Duration(milliseconds: 600);

  Timer? _slow;
  StreamSubscription<bool>? _online;
  var _started = false;
  var _introPlaying = false;
  SplashMode? _decided;
  Uri? _updateUrl;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _slow = Timer(slowAfter, () {
      if (!isClosed && state.mode == SplashMode.loading) {
        emit(state.copyWith(slow: true));
      }
    });
    await _sessionKnown();
    await _decide();
  }

  /// The splash shows and plays its intro.
  void introStarted() => _introPlaying = true;

  /// The intro has played (at once under reduce motion).
  void introShown() {
    _introPlaying = false;
    _show();
  }

  /// «إعادة المحاولة» without a connection.
  Future<void> retry() async {
    if (state.retrying || state.mode != SplashMode.offline) return;
    emit(state.copyWith(retrying: true));
    await Future.wait([_decide(), Future<void>.delayed(retryAtLeast)]);
    if (!isClosed) emit(state.copyWith(retrying: false));
  }

  /// «تحديث الآن»: the store, else its page, else the page to copy.
  Future<void> openStore() async {
    final opened = await _store.open(_updateUrl);
    if (isClosed) return;
    emit(
      state.copyWith(
        storeFailed: !opened,
        storePage: () => _store.webPage(_updateUrl),
      ),
    );
  }

  Future<void> _sessionKnown() async {
    if (_session.status != SessionStatus.unknown) return;
    final known = Completer<void>();
    void listener() {
      if (_session.status != SessionStatus.unknown && !known.isCompleted) {
        known.complete();
      }
    }

    _session.addListener(listener);
    await known.future;
    _session.removeListener(listener);
  }

  Future<void> _decide() async {
    final online = await _connectivity.isOnline();
    final policy = await _versions(online: online);
    if (isClosed) return;
    _updateUrl = policy.updateUrl;
    final need = policy.needOf(AppVersion.tryParse(_app.version));
    final firstOpenOffline =
        !online && _session.status == SessionStatus.signedOut;
    final decided = _decided = switch (need) {
      UpdateNeed.required => SplashMode.update,
      _ when firstOpenOffline => SplashMode.offline,
      _ => SplashMode.done,
    };
    if (decided == SplashMode.offline) {
      _online ??= _connectivity.onlineChanges.listen((online) {
        if (online && state.mode == SplashMode.offline && !state.retrying) {
          unawaited(_decide());
        }
      });
    } else {
      unawaited(_online?.cancel());
      _online = null;
    }
    emit(state.copyWith(need: need));
    _show();
  }

  /// The server's versions, else the ones kept from an earlier open; none
  /// known lets the app on.
  Future<VersionPolicy> _versions({required bool online}) async {
    Future<Result<VersionPolicy>> kept() =>
        _settings.getVersionPolicy(keptOnly: true);
    final result = online
        ? await _settings.getVersionPolicy().timeout(
            versionsWait,
            onTimeout: kept,
          )
        : await kept();
    return switch (result) {
      Ok(:final value) => value,
      Err() => VersionPolicy.none,
    };
  }

  void _show() {
    final decided = _decided;
    if (decided == null || _introPlaying || isClosed) return;
    _slow?.cancel();
    emit(state.copyWith(mode: decided, slow: false));
  }

  @override
  Future<void> close() async {
    _slow?.cancel();
    await _online?.cancel();
    return super.close();
  }
}
