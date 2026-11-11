# 19. The opening and the version gate

Status: Accepted · Date: 2026-11-10

## Context
The splash (student doc §4.1) must follow the system's splash without a flash, last only as long as loading does, hold a first open without a connection, and stop a version older than the server's minimum (v0.1). From v1.0 a version older than the recommended one gets a reminder (server doc §19.2). The designs (`Splash Form`, `App Update`) make the forced update state 05 of the splash itself, with no move between them, and the reminder a sheet on home.

## Decision
- **Versions in the effective settings.** The server's minimum and recommended version and the store page for each platform are proposed as the settings' `appVersion` group (docs/api/settings.md), so the app needs one call on open. `VersionPolicy.needOf` (settings domain) decides: older than the minimum → required, older than the recommended → suggested, else none. A value that isn't valid is left out alone. The group is read even when another one is incomplete, and the phone keeps its platform's entry: an open without a connection still stops a version too old to run. With no connection and nothing kept, nothing stops the app.
- **One app-scoped `SplashCubit`** (`features/launch`), created by `App` and provided above the router. It waits for the session and the versions (at most 8s, then the kept ones), and decides: the update screen, a signed-out first open without a connection, or on. Once the splash page shows it also waits for the page's intro, so the guide is never cut off; an app opened on a link, without the splash, doesn't wait.
- **The router reads it.** `AppRedirect` takes a `LaunchStatus`: while starting, the splash holds as for an unknown session; when the update is required, every route leads back to the splash, public ones too. The router refreshes on the session and on the cubit's launch status.
- **The store.** `AppStore` (`core/links`) opens Google Play's app (`market://`) first, then the server's page; when neither opens, the page to copy is shown: the server's, else Google Play's web page from the package name. iOS knows only the server's, as only it knows the App Store ID.
- **The reminder** is composed by the router on home's tab, never inside home: once home has settled (its data, opening and celebrations) and isn't a child's, `remindToUpdate` shows the sheet if the version is behind, nothing covers home, and it hasn't shown today. Showing it counts for the day, so «لاحقًا», a swipe and the scrim all put it off to the next.
- **The system splash draws the page's first frame.** Android 12+ (`values-v31`, `values-night-v31`) and the older launch background draw the guide in a 160dp circle on the app's background, light and dark: the page's 200dp circle and 140dp guide at the intro's .8. The guide's image is rendered from `Mascot` by `tool/splash/render_splash_icon_test.dart`, so it follows the guide.

## Consequences
- The forced update and the offline first open are the splash's states, not routes: nothing to deep-link past.
- A change of versions in the panel reaches an app already open only on its next open (STATUS D-109).
- iOS still shows Flutter's white launch screen before the page (STATUS D-107).
