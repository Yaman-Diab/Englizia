import 'dart:async';

import 'package:englizia/core/config/app_info.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/links/app_store.dart';
import 'package:englizia/core/links/external_link.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_state.dart';
import 'package:englizia/features/launch/presentation/splash/pages/splash_page.dart';
import 'package:englizia/features/settings/domain/entities/app_version.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The splash's states, for the dev page in mock mode: each plays the real
/// splash over a made-up opening, and closes once it would go on.
enum LaunchPreview { slow, offline, update, storeFails }

void previewLaunch(BuildContext context, LaunchPreview preview) {
  final store = sl<AppStore>();
  final cubit = SplashCubit(
    session: _Signed(out: preview == LaunchPreview.offline),
    settings: _Versions(
      preview == LaunchPreview.update || preview == LaunchPreview.storeFails
          ? const VersionPolicy(minimum: AppVersion(999))
          : VersionPolicy.none,
      wait: preview == LaunchPreview.slow
          ? const Duration(seconds: 6)
          : Duration.zero,
    ),
    connectivity: _Connection(online: preview != LaunchPreview.offline),
    app: sl<AppInfo>(),
    store: preview == LaunchPreview.storeFails
        ? AppStore(
            const _NothingOpens(),
            packageName: store.packageName,
            platform: store.platform,
          )
        : store,
  );
  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) => cubit..start(),
          child: BlocListener<SplashCubit, SplashState>(
            listenWhen: (_, state) => state.mode == SplashMode.done,
            listener: (context, _) => Navigator.of(context).pop(),
            child: const SplashPage(),
          ),
        ),
      ),
    ),
  );
}

final class _Signed extends AppSessionController {
  _Signed({required this.out}) : super(tokens: sl(), settings: sl());

  final bool out;

  @override
  SessionStatus get status =>
      out ? SessionStatus.signedOut : SessionStatus.member;
}

final class _Versions implements SettingsRepository {
  const _Versions(this.policy, {required this.wait});

  final VersionPolicy policy;
  final Duration wait;

  @override
  Future<Result<VersionPolicy>> getVersionPolicy({
    bool keptOnly = false,
  }) async {
    if (!keptOnly) await Future<void>.delayed(wait);
    return Ok(policy);
  }

  @override
  Future<Result<EffectiveSettings>> getSettings() =>
      sl<SettingsRepository>().getSettings();
}

/// Offline until the phone itself says otherwise.
final class _Connection implements ConnectivityService {
  const _Connection({required this.online});

  final bool online;

  @override
  Future<bool> isOnline() async =>
      online && await sl<ConnectivityService>().isOnline();

  @override
  Stream<bool> get onlineChanges =>
      online ? sl<ConnectivityService>().onlineChanges : const Stream.empty();
}

final class _NothingOpens implements ExternalLink {
  const _NothingOpens();

  @override
  Future<bool> open(Uri uri) async => false;
}
