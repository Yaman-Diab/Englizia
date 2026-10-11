enum RoutePolicy {
  /// Anyone, including guests (splash, onboarding, legal pages).
  public,

  /// Only signed-out users (login, register); signed-in users go home.
  guestOnly,

  /// Signed-in users only; guests go to the login route.
  requiresLogin,
}
