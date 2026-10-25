import 'package:englizia/core/router/route_policy.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Route guard: splash until the session is known, then the policy of the
/// matched route decides. Policies come from `app/router/route_policies.dart`.
/// Signed-in users land on [homeLocation]; everyone else on
/// [guestHomeLocation], the entry to onboarding and sign-in.
final class AppRedirect {
  const AppRedirect({
    required SessionStatus Function() status,
    required RoutePolicy Function(String routePattern) policyFor,
    required this.splashLocation,
    required this.homeLocation,
    required this.guestHomeLocation,
  }) : _status = status,
       _policyFor = policyFor;

  final SessionStatus Function() _status;
  final RoutePolicy Function(String routePattern) _policyFor;
  final String splashLocation;
  final String homeLocation;
  final String guestHomeLocation;

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
    final signedIn = status == SessionStatus.authenticated;
    if (atSplash) return signedIn ? homeLocation : guestHomeLocation;

    final target = switch (_policyFor(routePattern)) {
      RoutePolicy.public => null,
      RoutePolicy.guestOnly => signedIn ? homeLocation : null,
      RoutePolicy.requiresLogin => signedIn ? null : guestHomeLocation,
    };
    return target == location ? null : target;
  }
}
