import 'package:englizia/core/router/route_policy.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Route guard: splash until the session is known, then the policy of the
/// matched route decides. Policies come from `app/router/route_policies.dart`.
final class AppRedirect {
  const AppRedirect({
    required SessionStatus Function() status,
    required RoutePolicy Function(String routePattern) policyFor,
    required this.splashLocation,
    required this.homeLocation,
    required this.loginLocation,
  }) : _status = status,
       _policyFor = policyFor;

  final SessionStatus Function() _status;
  final RoutePolicy Function(String routePattern) _policyFor;
  final String splashLocation;
  final String homeLocation;
  final String loginLocation;

  String? call(BuildContext context, GoRouterState state) => resolve(
    location: state.matchedLocation,
    routePattern: state.fullPath ?? state.matchedLocation,
  );

  String? resolve({required String location, required String routePattern}) {
    final status = _status();
    final atSplash = location == splashLocation;
    if (status == SessionStatus.unknown) {
      return atSplash ? null : splashLocation;
    }
    if (atSplash) return homeLocation;

    final signedIn = status == SessionStatus.authenticated;
    final target = switch (_policyFor(routePattern)) {
      RoutePolicy.public => null,
      RoutePolicy.guestOnly => signedIn ? homeLocation : null,
      RoutePolicy.requiresLogin => signedIn ? null : loginLocation,
    };
    return target == location ? null : target;
  }
}
