# Architecture

Clean Architecture, feature-first, Cubit for state. Decisions behind each part are in `docs/adr/`.

## Layers

```
lib/
├── main.dart          bootstrap: config check, error hooks, portrait lock, localization, DI, runApp, session bootstrap
├── app/               composition root — the only folder that may import features/
│   ├── app.dart       MaterialApp.router inside ScreenUtilInit; theme, locale, text-scale clamp, env banner
│   ├── di.dart        configureDependencies(): core + every feature (main and the DI test call it)
│   ├── router/        AppRoutes, route_policies (route → policy), createAppRouter
│   └── shell/         SplashPage; FoundationPage (temporary home until the Learn tab exists)
├── core/              shared kernel — imports nothing from app/ or features/
│   ├── config/        AppConfig (APP_ENV, BASE_URL from --dart-define-from-file)
│   ├── result/        Result<T> (Ok/Err) · guard()
│   ├── usecase/       UseCase<T, P> · NoParams
│   ├── error/         Failure (sealed) · FailureMapper
│   ├── l10n/          AppLocales · CurrentLanguage · FailureL10n (failure → translated text)
│   ├── logging/       AppLogger · Redactor · CrashReporter (no-op until a provider is chosen)
│   ├── network/       ApiClient · ApiException (server envelope) · NetworkException · TokenResponse · interceptors · DioFactory · JsonReader
│   ├── session/       AuthTokens · AppSessionController (GoRouter refreshListenable)
│   ├── storage/       TokenStorage (secure) · SettingsStorageService (SharedPreferences, non-sensitive)
│   ├── router/        RoutePolicy · AppRedirect
│   ├── settings/      SettingsCubit (theme mode)
│   ├── design_system/ palette · semantic colors · text styles · spacing · theme · widgets
│   └── di/            sl · setupCoreDependencies
└── features/<feature>/ domain · data · presentation (none yet)
```

Dependency direction inside a feature: `presentation → domain ← data`. Rules are enforced by `test/core/architecture_test.dart`.

## Data flow and errors

```
Page ─▶ Cubit ─▶ UseCase ─▶ Repository (domain contract)
                              ▲
             RepositoryImpl ──┘  guard(() => remote.call().toEntity())
                    │
             RemoteDataSource ─▶ ApiClient ─▶ Dio (headers → auth → debug log)
```

- Datasources return **models**; `RepositoryImpl` maps to entities inside `guard()`.
- `ApiClient` unwraps the server envelope `{statusCode, message, data, error, traceId}` (`docs/api/openapi.json`) and turns Dio errors into `ApiException` (non-2xx: `error.code` and per-field `error.details`, with ProblemDetails as a fallback) or `NetworkException` (no response).
- `guard()` → `FailureMapper.fromError()` → typed `Failure`, mapped **once**. Unexpected errors are logged with stack trace.
- Cubit state keeps the `Failure`; the page shows `failure.localizedMessage` and a retry action.
- Endpoint-specific meaning (e.g. 401 on login = wrong credentials) is handled in that repository before `guard` maps it.

## Session and auth

- `AppSessionController` status: `unknown → signedOut | guest | member` (ADR 10). Tokens carry their `AccountKind`, kept through refresh and secure storage. `bootstrap()` never throws; on first launch after install it clears the keystore (iOS keeps Keychain items after uninstall).
- `AuthInterceptor` attaches the bearer token, shares **one** refresh among concurrent 401s, retries each request once, and expires the session only when the server rejects the refresh token (offline keeps the session).
- `TokenRefreshService` uses a separate Dio without the auth interceptor and sets `Authorization` itself.
- Public endpoints set `extra[AuthInterceptor.skipAuthKey] = true`.

## Routing

- `route_policies.dart` maps each route pattern to `public`, `signedOutOnly` (welcome, onboarding), `withoutAccount` (sign-in, sign-up; open to guests) or `requiresSession` (the app; guests and members); unlisted routes need a session.
- `AppRedirect`: splash until the session is known, then guests and members go home and signed-out users to the welcome screen; after that the policy decides. The router listens to the session, so creating a guest account, signing in or out re-routes automatically.
- A new account (guest or member) is not started by the screen that creates it: its session is handed to "preparing" (or, on the child path, the kids' welcome) as `PreparingArgs` in route `extra`, which starts it. That route is `public`, so it stays open when the session starts; the router's refresh drops `extra`, so the router keeps the arguments in memory until the learner leaves preparing.
- The guard checks the route at the bottom of the stack, not one pushed over it: a pushed screen whose session changes navigates itself (a guest's upgrade from sign-up goes home).
- Tabs (Learn / Practice / Speak / Me; kids: Learn / My words / Me) will use `StatefulShellRoute` when the first tab lands.

## Design system

- Tokens from "الهوية البصرية v2": `context.colors` (`AppSemanticColors`) with a `ToneColors` triple per role — `fill` (icons, borders, progress), `text` (≥4.5:1), `surface` (light background) — plus neutrals and reader tokens (karaoke highlight, sentence band, tappable underline, selected word, captions).
- `context.texts` (`AppTextStyles`): display 28/34, title 22/30, reading 20/36, body 16/26, caption 13/20 (+ `captionStrong`), button 16; weights 400/600; Arabic running text ≥ 1.7 line height. Sizes use `.sp` (design size 375×812).
- `context.scheme` for Material widgets; component themes are set in `AppTheme` so widgets don't repeat overrides.
- **Waiting looks the same everywhere:** `AppSpinner` (a faint ring with a turning quarter arc, from the account designs) is the only progress mark. A busy button is `AppButton(isLoading: true)`: it keeps its size and full color, takes no taps, and its label crossfades into the spinner in the label's color; a button built another way wraps its label in `ButtonLoadingLabel`. Pages and sections wait with `AppStateView.loading()`. No `CircularProgressIndicator`, no "loading…" text in buttons.
- Forms use `AppTextField` (label above, icon, focus halo, a `FieldMessage` under it with a mark per tone, `Shake` when a send is refused). A failed action shows `showFailureSnackBar` (error band, retry), which keeps what was typed.
- `design_system/icons/` — `AppIcon` / `AppIconView`: the designs' own line icons as SVG (via `flutter_svg`, flutter.dev, 160/160 points); Material icons stay for generic controls. An icon is added when its screen is built.
- `core/network/connectivity_service.dart` — `ConnectivityService` (online now, changes): connectivity_plus behind an interface; tests use `FakeConnectivityService`.
- `core/audio/` — `AppSound`, the `SoundPlayer` interface (silent for now, ADR 9) and `DeviceVolume` (whether the phone is muted: `PlatformDeviceVolume` on `volume_controller`, never failing its caller; STATUS D-046).
- `motion/` — `AppMotion` (`app_motion.dart`), page transitions, `Entrance` and the entrance choreography (ADR 7). `AppMotion`: durations, curves, distances and scales for every animation (adapted from transitions.dev, no blur). `AppMotion.resolve(context, duration)` returns zero when the platform disables animations; decorative motion checks `AppMotion.reduceMotion(context)`.
- Page transitions come from `AppTheme.pageTransitionsTheme`: Android `AppPageTransitionsBuilder` (fade + 30px slide from the end side, 250ms, in place under reduce motion); iOS/macOS keep the native Cupertino transition with edge-swipe back. Tabs and session entry get their own transitions with those features (ADR 7).
- `test/core/design_system/theme_test.dart` pins identity values and checks WCAG contrast in light and dark.
- Fonts: Readex Pro (UI, Arabic + Latin) and Andika (kids) through `google_fonts`, loaded from bundled files in `assets/fonts/` (runtime fetching off). Each weight is its own family, so weights come from roles (`bodyStrong`, `captionStrong`), never `copyWith(fontWeight:)`.

## Localization

- easy_localization, `assets/translations/{ar,en}.json`, flat snake_case keys prefixed by feature.
- Device language decides at first launch; Arabic is the fallback. The onboarding language step will set it explicitly.
- Latin digits everywhere (scores, XP, CEFR codes stay consistent across both languages).
- Directional layout only: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `BorderRadiusDirectional`, `TextAlign.start/end`; icons that point somewhere use `matchTextDirection`. `architecture_test` rejects the physical left/right APIs anywhere in `lib/`. English content inside the Arabic UI (the reader) may still set `TextDirection.ltr`.
- `Accept-Language` follows the UI language via `CurrentLanguage`; `test/app/app_test.dart` switches the language on screen and checks the header the app's Dio sends.
- `test/localization/localization_test.dart`: parity, placeholders, unused/missing keys, hardcoded text.

## Environments

`env/{dev,staging,prod,mock}.json` + gitignored `env/local.json`. `AppConfig.validate()` fails fast without `APP_ENV`/`BASE_URL`. Non-prod builds show an environment banner. `mock` is reserved for fixture-backed datasources registered in `configureDependencies()` when `AppConfig.isMock`.

## Testing

| Layer | Where | Tool |
|---|---|---|
| Network, interceptors, parsing | `test/core/network/` | `FakeHttpAdapter` |
| Session, router guard, settings | `test/core/` | fakes, `bloc_test` |
| Theme | `test/core/design_system/` | contrast math, ScreenUtil |
| Whole app boot | `test/app/` | `pumpLocalized`, 375 and 320 widths, AR + EN, a11y guidelines |
| DI | `test/di/` | `configureDependencies()` |
| Rules | `architecture_test`, `localization_test` | file scans |
| Screens | `test/features/<feature>/` | `testLayouts` (every locale × 375/320 × light/dark), `settleEntrance` to play an entrance, `FakeTrackRepository` and other shared fakes in `test/helpers/` |
