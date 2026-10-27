/// Who may open a route, by session status (ADR 10).
enum RoutePolicy {
  /// Anyone (splash, legal pages).
  public,

  /// Only without any account (welcome, onboarding); a guest or a member
  /// goes home.
  signedOutOnly,

  /// Without a full account (sign-in, sign-up): signed out, or a guest
  /// about to create an account; a member goes home.
  withoutAccount,

  /// With a guest or member account (the app itself); signed out goes to
  /// the welcome screen.
  requiresSession,
}
