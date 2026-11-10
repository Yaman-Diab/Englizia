import 'package:englizia/core/router/route_policy.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Where the app's opening stands (the splash screen's work).
enum LaunchStatus {
  /// Still on the splash: loading, or waiting for a first connection.
  starting,

  /// Too old to run (ADR 19): the splash's update screen, and nothing else.
  updateRequired,

  /// Open: the routes' policies decide.
  ready,
}

/// Route guard: splash until the session is known and the opening is done
/// (a public route needs neither, and a link that opened one would be lost),
/// then the policy of the matched route decides. An app too old to run stays
/// on the splash whatever the route. Policies come from `app/router/route_policies.dart`.
/// Guests and members land on [homeLocation]; signed-out users on
/// [signedOutLocation], the entry to onboarding and sign-in.
final class AppRedirect {
  const AppRedirect({
    required SessionStatus Function() status,
    required RoutePolicy Function(String routePattern) policyFor,
    LaunchStatus Function()? launch,
    required this.splashLocation,
    required this.homeLocation,
    required this.signedOutLocation,
  }) : _status = status,
       _policyFor = policyFor,
       _launch = launch;

  final SessionStatus Function() _status;
  final LaunchStatus Function()? _launch;
  final RoutePolicy Function(String routePattern) _policyFor;
  final String splashLocation;
  final String homeLocation;
  final String signedOutLocation;

  String? call(BuildContext context, GoRouterState state) => resolve(
    location: state.matchedLocation,
    routePattern: state.fullPath ?? state.matchedLocation,
  );

  String? resolve({required String location, required String routePattern}) {
    final status = _status();
    final launch = _launch?.call() ?? LaunchStatus.ready;
    final atSplash = location == splashLocation;
    if (launch == LaunchStatus.updateRequired) {
      return atSplash ? null : splashLocation;
    }
    if (status == SessionStatus.unknown || launch == LaunchStatus.starting) {
      return atSplash || _policyFor(routePattern) == RoutePolicy.public
          ? null
          : splashLocation;
    }
    final hasSession = status != SessionStatus.signedOut;
    if (atSplash) return hasSession ? homeLocation : signedOutLocation;

    final target = switch (_policyFor(routePattern)) {
      RoutePolicy.public => null,
      RoutePolicy.signedOutOnly => hasSession ? homeLocation : null,
      RoutePolicy.withoutAccount =>
        status == SessionStatus.member ? homeLocation : null,
      RoutePolicy.requiresSession => hasSession ? null : signedOutLocation,
    };
    return target == location ? null : target;
  }
}
