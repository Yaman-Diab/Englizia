import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/router/route_policy.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policies = {
    '/splash': RoutePolicy.public,
    '/': RoutePolicy.public,
    '/login': RoutePolicy.guestOnly,
    '/profile': RoutePolicy.requiresLogin,
  };

  String? resolve(SessionStatus status, String location) => AppRedirect(
    status: () => status,
    policyFor: (pattern) => policies[pattern] ?? RoutePolicy.requiresLogin,
    splashLocation: '/splash',
    homeLocation: '/',
    loginLocation: '/login',
  ).resolve(location: location, routePattern: location);

  test('holds on splash until the session is known', () {
    expect(resolve(SessionStatus.unknown, '/splash'), isNull);
    expect(resolve(SessionStatus.unknown, '/profile'), '/splash');
  });

  test('leaves splash once the session is known', () {
    expect(resolve(SessionStatus.guest, '/splash'), '/');
    expect(resolve(SessionStatus.authenticated, '/splash'), '/');
  });

  test('guards requiresLogin routes', () {
    expect(resolve(SessionStatus.guest, '/profile'), '/login');
    expect(resolve(SessionStatus.authenticated, '/profile'), isNull);
  });

  test('sends signed-in users away from guestOnly routes', () {
    expect(resolve(SessionStatus.authenticated, '/login'), '/');
    expect(resolve(SessionStatus.guest, '/login'), isNull);
  });

  test('unlisted routes require login (least privilege)', () {
    expect(resolve(SessionStatus.guest, '/unknown'), '/login');
  });
}
