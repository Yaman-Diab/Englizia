import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/router/route_policy.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policies = {
    '/splash': RoutePolicy.public,
    '/about': RoutePolicy.public,
    '/welcome': RoutePolicy.signedOutOnly,
    '/onboarding/goal': RoutePolicy.signedOutOnly,
    '/sign-in': RoutePolicy.withoutAccount,
    '/': RoutePolicy.requiresSession,
  };

  String? resolve(
    SessionStatus status,
    String location, {
    LaunchStatus launch = LaunchStatus.ready,
  }) => AppRedirect(
    status: () => status,
    launch: () => launch,
    policyFor: (pattern) => policies[pattern] ?? RoutePolicy.requiresSession,
    splashLocation: '/splash',
    homeLocation: '/',
    signedOutLocation: '/welcome',
  ).resolve(location: location, routePattern: location);

  test('holds everyone on the splash until the session is known', () {
    expect(resolve(SessionStatus.unknown, '/splash'), isNull);
    expect(resolve(SessionStatus.unknown, '/'), '/splash');
  });

  test('a public route does not wait, so a link that opened it is kept', () {
    expect(resolve(SessionStatus.unknown, '/about'), isNull);
    expect(resolve(SessionStatus.signedOut, '/about'), isNull);
  });

  test('leaves the splash for home with an account, else welcome', () {
    expect(resolve(SessionStatus.member, '/splash'), '/');
    expect(resolve(SessionStatus.guest, '/splash'), '/');
    expect(resolve(SessionStatus.signedOut, '/splash'), '/welcome');
  });

  test('the app needs a guest or member account', () {
    expect(resolve(SessionStatus.signedOut, '/'), '/welcome');
    expect(resolve(SessionStatus.guest, '/'), isNull);
    expect(resolve(SessionStatus.member, '/'), isNull);
  });

  test('welcome and onboarding are for those without any account', () {
    expect(resolve(SessionStatus.signedOut, '/onboarding/goal'), isNull);
    expect(resolve(SessionStatus.guest, '/onboarding/goal'), '/');
    expect(resolve(SessionStatus.member, '/welcome'), '/');
  });

  test('a guest may still sign in or create an account; a member not', () {
    expect(resolve(SessionStatus.signedOut, '/sign-in'), isNull);
    expect(resolve(SessionStatus.guest, '/sign-in'), isNull);
    expect(resolve(SessionStatus.member, '/sign-in'), '/');
  });

  test('public routes are open to all', () {
    for (final status in [
      SessionStatus.signedOut,
      SessionStatus.guest,
      SessionStatus.member,
    ]) {
      expect(resolve(status, '/about'), isNull);
    }
  });

  test('unlisted routes need a session', () {
    expect(resolve(SessionStatus.signedOut, '/unknown'), '/welcome');
    expect(resolve(SessionStatus.guest, '/unknown'), isNull);
  });

  test('the opening holds the app on the splash, as an unknown session', () {
    const starting = LaunchStatus.starting;
    expect(resolve(SessionStatus.member, '/splash', launch: starting), isNull);
    expect(resolve(SessionStatus.member, '/', launch: starting), '/splash');
    expect(
      resolve(SessionStatus.signedOut, '/about', launch: starting),
      isNull,
    );
  });

  test('an app too old to run stays on the splash, public routes too', () {
    const update = LaunchStatus.updateRequired;
    for (final status in SessionStatus.values) {
      expect(resolve(status, '/splash', launch: update), isNull);
      expect(resolve(status, '/', launch: update), '/splash');
      expect(resolve(status, '/about', launch: update), '/splash');
      expect(resolve(status, '/welcome', launch: update), '/splash');
    }
  });
}
