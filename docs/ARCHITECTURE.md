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
│   ├── network/       ApiClient · ApiException (ProblemDetails) · NetworkException · interceptors · DioFactory · JsonReader
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
- `ApiClient` turns Dio errors into `ApiException` (non-2xx, parsed from ASP.NET ProblemDetails) or `NetworkException` (no response).
- `guard()` → `FailureMapper.fromError()` → typed `Failure`, mapped **once**. Unexpected errors are logged with stack trace.
- Cubit state keeps the `Failure`; the page shows `failure.localizedMessage` and a retry action.
- Endpoint-specific meaning (e.g. 401 on login = wrong credentials) is handled in that repository before `guard` maps it.

## Session and auth

- `AppSessionController` status: `unknown → guest | authenticated`. `bootstrap()` never throws; on first launch after install it clears the keystore (iOS keeps Keychain items after uninstall).
- `AuthInterceptor` attaches the bearer token, shares **one** refresh among concurrent 401s, retries each request once, and expires the session only when the server rejects the refresh token (offline keeps the session).
- `TokenRefreshService` uses a separate Dio without the auth interceptor and sets `Authorization` itself.
- Public endpoints set `extra[AuthInterceptor.skipAuthKey] = true`.

## Routing

- `route_policies.dart` maps each route pattern to `public`, `guestOnly` or `requiresLogin`; unlisted routes require login.
- `AppRedirect`: splash until the session is known, then the policy decides. The router listens to the session, so sign-in/out re-routes automatically.
- Tabs (Learn / Practice / Speak / Me; kids: Learn / My words / Me) will use `StatefulShellRoute` when the first tab lands.

## Design system

- Tokens from "الهوية البصرية v2": `context.colors` (`AppSemanticColors`) with a `ToneColors` triple per role — `fill` (icons, borders, progress), `text` (≥4.5:1), `surface` (light background) — plus neutrals and reader tokens (karaoke highlight, sentence band, tappable underline, selected word, captions).
- `context.texts` (`AppTextStyles`): display 28/34, title 22/30, reading 20/36, body 16/26, caption 13/20, button 16; weights 400/600; Arabic running text ≥ 1.7 line height. Sizes use `.sp` (design size 375×812).
- `context.scheme` for Material widgets; component themes are set in `AppTheme` so widgets don't repeat overrides.
- `test/core/design_system/theme_test.dart` pins identity values and checks WCAG contrast in light and dark.
- Fonts: Readex Pro (UI, Arabic + Latin) and Andika (kids). Not bundled yet — see `assets/fonts/README.md`.

## Localization

- easy_localization, `assets/translations/{ar,en}.json`, flat snake_case keys prefixed by feature.
- Device language decides at first launch; Arabic is the fallback. The onboarding language step will set it explicitly.
- Latin digits everywhere (scores, XP, CEFR codes stay consistent across both languages).
- `Accept-Language` follows the UI language via `CurrentLanguage`.
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
