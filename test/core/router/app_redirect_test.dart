import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/router/route_policy.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policies = {
    '/splash': RoutePolicy.public,
    '/about': RoutePolicy.public,
    '/welcome': RoutePolicy.guestOnly,
    '/sign-in': RoutePolicy.guestOnly,
    '/': RoutePolicy.requiresLogin,
  };

  String? resolve(SessionStatus status, String location) => AppRedirect(
    status: () => status,
    policyFor: (pattern) => policies[pattern] ?? RoutePolicy.requiresLogin,
    splashLocation: '/splash',
    homeLocation: '/',
    guestHomeLocation: '/welcome',
  ).resolve(location: location, routePattern: location);

  test('holds on splash until the session is known', () {
    expect(resolve(SessionStatus.unknown, '/splash'), isNull);
    expect(resolve(SessionStatus.unknown, '/'), '/splash');
  });

  test('leaves splash for home when signed in, welcome otherwise', () {
    expect(resolve(SessionStatus.authenticated, '/splash'), '/');
    expect(resolve(SessionStatus.guest, '/splash'), '/welcome');
  });

  test('sends guests from requiresLogin routes to welcome', () {
    expect(resolve(SessionStatus.guest, '/'), '/welcome');
    expect(resolve(SessionStatus.authenticated, '/'), isNull);
  });

  test('sends signed-in users away from guestOnly routes', () {
    expect(resolve(SessionStatus.authenticated, '/welcome'), '/');
    expect(resolve(SessionStatus.authenticated, '/sign-in'), '/');
    expect(resolve(SessionStatus.guest, '/sign-in'), isNull);
  });

  test('public routes are open to everyone', () {
    expect(resolve(SessionStatus.guest, '/about'), isNull);
    expect(resolve(SessionStatus.authenticated, '/about'), isNull);
  });

  test('unlisted routes require login (least privilege)', () {
    expect(resolve(SessionStatus.guest, '/unknown'), '/welcome');
  });
}
