# Flutter Playbook — Architecture, Conventions, Git/GitHub, Release

> Reference document. **Do not load it every session** — `CLAUDE.md` points here.
> Distilled from a production-style Flutter app (12 features, ~32k lines, 567 tests, Clean
> Architecture, Arabic-first) **plus** the corrections found by a full audit of that app.
> Where the old project did something wrong, this playbook already contains the fix.
>
> Sections: 1 Day-0 setup · 2 Architecture · 3 Recurring files (starter kit) · 4 Naming &
> style · 5 State & errors · 6 Networking · 7 Design system · 8 Localization & RTL ·
> 9 Testing · 10 Git & GitHub · 11 Environments & release · 12 Production essentials ·
> 13 Docs & AI workflow · 14 Hard-won lessons · 15 Templates

> **Englizia scope.** This playbook is a general reference, distilled from a project whose
> backend was Laravel. Where it differs from Englizia, the accepted ADRs in `docs/adr/` and
> the current code win (current state: `docs/ARCHITECTURE.md`). For errors in particular:
> - **Error bodies:** the server envelope's `error: {code, details: [{field, code, message}]}`
>   parsed by `ApiException` (ProblemDetails as a fallback), not Laravel `message`/`errors` —
>   ADR 2, `docs/api/README.md`.
> - **Failures:** `Failure` is sealed and carries no user message (only `code`,
>   `serverMessage`); Cubit state keeps the `Failure` and pages show
>   `failure.localizedMessage` — ADR 1, ADR 2.
> - **`guard()`** lives in `core/result/guard.dart` and leaves logging to `FailureMapper`
>   (breadcrumbs for API/network errors, error + stack for unexpected ones) — ADR 2.

---

## 1. Day-0 setup checklist (in this order)

1. **Create with the real org and only the platforms you ship**
   `flutter create --org com.<yourdomain> --platforms=android,ios <app_name>`
   The application ID is permanent once published — never ship `com.example.*`.
2. **Pin Flutter**: `fvm use <version>` → commit `.fvmrc`. Same version in CI.
3. **Repo**: private by default for client work. Add `LICENSE` (or a proprietary notice),
   description, topics. Protect `main` (require PR + CI, block force-push).
4. **Root files** from §15: `.gitignore` additions, `.gitattributes`, `analysis_options.yaml`,
   `env/*.json`, `.vscode/launch.json`, `.github/workflows/ci.yml`,
   `.github/pull_request_template.md`, `.github/dependabot.yml`, `lefthook.yml`,
   `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `docs/`.
5. **Copy the starter kit** (`lib/core`, `lib/app` skeleton, `test/helpers`) — §3.
6. **Rename template leftovers**: pubspec `description`, localized app name
   (Android `values/strings.xml` + `values-ar/strings.xml`, iOS `InfoPlist.strings`),
   icons + splash generated from one source (`flutter_launcher_icons`, `flutter_native_splash`).
7. **Decide typography for both scripts** (an Arabic+Latin family with every weight you use).
8. **Lock orientation** to portrait unless landscape is designed (Dart + Manifest + Info.plist).
9. **Release signing** (§11) and `RELEASE.md` before the first test build leaves your machine.
10. **Crash reporting + global error handlers** (§12) before the first tester gets a build.
11. **Do one iOS build in week one** — permissions/purpose strings break silently otherwise.
12. **Agree the API contract** with the backend (OpenAPI if possible) and commit it under `docs/api/`.

---

## 2. Architecture

Clean Architecture, feature-first, Cubit for state.

```
lib/
├── main.dart                 bootstrap only: bindings, config validation, error hooks, DI, runApp
├── app/                      composition root — may import features/
│   ├── app.dart              MaterialApp.router (theme, locale, text-scale scope)
│   ├── di.dart               configureDependencies(): core + every feature (used by main AND tests)
│   └── router/
│       ├── app_router.dart   GoRouter + StatefulShellRoute (imports feature pages)
│       └── route_policies.dart  route → {public | signedOutOnly | withoutAccount | requiresSession}
├── core/                     shared kernel — imports NOTHING from app/ or features/
└── features/<feature>/
    ├── <feature>_injection.dart      void register<Feature>Dependencies(GetIt sl)
    ├── domain/
    │   ├── entities/                 final class X extends Equatable (no JSON keys)
    │   ├── repositories/             abstract class XRepository → Future<Result<T>>
    │   └── usecases/                 XUseCase implements UseCase<T, XParams>
    ├── data/
    │   ├── datasources/              XRemoteDataSource (+Impl) — only place that knows endpoints
    │   ├── models/                   XModel.fromJson / toJson / toEntity()
    │   └── repositories/             XRepositoryImpl — guard() + toEntity()
    └── presentation/<screen>/
        ├── cubit/                    <screen>_cubit.dart + <screen>_state.dart
        ├── pages/
        └── widgets/
```

**Why `lib/app/`:** in the old project the router lived in `core/` and imported 24 files from
all features, so `core/` could not be copied into a new project. The composition root belongs
outside `core/`. Enforce it with a test that fails if any file under `lib/core/` contains
`features/` or `app/` in an import.

**Data pattern — pick ONE and keep it:** the datasource returns **Models**; the
`RepositoryImpl` calls `toEntity()` inside `guard()`. (The old project drifted into two
patterns: some models wrapped an entity directly. Don't.)

**Cross-feature rules**
- Feature A may use feature B's *domain* (entity/use case) only through B's public API.
  When a type gets a **second** consumer, promote it to `core/` before it is copied.
- Widgets used by two features move to `core/design_system/widgets/` immediately.

**Interactive sheets/dialogs get their own small factory Cubit** (e.g. `ReportCubit`
provided inside the sheet). Calling `sl<UseCase>()` + `setState` from widgets makes the flow
untestable — `sl<>()` belongs only in `BlocProvider.create` and the composition root.

---

## 3. Recurring files — the starter kit

`G` = generic, copy as-is · `A` = adapt values · `B` = backend-specific, only if your backend needs it.

### `lib/core/`
| Path | Kind | Purpose |
|---|---|---|
| `config/app_config.dart` | G | `String.fromEnvironment('APP_ENV' / 'BASE_URL')` + `validate()` that throws if empty |
| `result/result.dart` | G | `sealed class Result<T>`: `Ok<T>` / `Err<T>`; add `guard()` here |
| `usecase/usecase.dart` | G | `abstract class UseCase<T, P>` + `NoParams` |
| `error/failure.dart` | G | `sealed class Failure`: Network, Auth, Validation(fieldErrors), RateLimit, Server, Unknown |
| `error/failure_mapper.dart` | A | `FailureMapper.fromError(e)` — status/code → Failure. Logs non-API errors with stack |
| `logging/app_logger.dart` | G | debug console in dev, crash-reporter breadcrumbs in release, PII redaction |
| `network/api_client.dart` | G | single `request()` over Dio → `ApiException` |
| `network/dio_factory.dart` | A | main Dio + refresh Dio, AuthInterceptor, **debug-only redacting** logger, app-version headers |
| `network/auth_interceptor.dart` | G | attach Bearer, one shared refresh on 401, one retry, then logout |
| `network/token_refresh_service.dart` | A | refresh call — **sets its own Authorization header** (see §14) |
| `network/api_exception.dart` | G | parses Laravel-style `message` / `errors` (Englizia: the server envelope — `docs/api/README.md`) |
| `network/api_status_codes.dart` | G | named status constants |
| `network/api_endpoints.dart` | A | endpoint paths, one-line comments only |
| `network/json_reader.dart` | G | ONE extension for defensive JSON reads (`readInt`, `readString`, `readMap`, `firstOf`) |
| `network/api_media.dart` | B | media `file_url` / `file_path → {base}/storage/{path}` (Laravel public disk) |
| `network/api_envelope.dart` | B | **only** if the backend returns failures with HTTP 200 |
| `di/service_locator.dart` | G | `final sl = GetIt.instance; setupCoreDependencies()` |
| `router/app_redirect.dart` | G | splash → onboarding → auth → policy guard (driven by `route_policies`) |
| `router/route_args.dart` | G | typed args for `extra` |
| `session/app_session_controller.dart` | G | `ChangeNotifier` as GoRouter `refreshListenable`; bootstrap with try/catch → signed-out fallback |
| `session/session_manager.dart` | G | re-entrancy guard around logout-on-401 |
| `storage/secure_storage_service.dart` | G | token + session (flutter_secure_storage); writes wrapped in try/catch |
| `storage/settings_storage_service.dart` | G | non-sensitive prefs (SharedPreferences) |
| `settings/` | G | `SettingsCubit` (themeMode, textScale) + `TextScaleScope` (clamped) |
| `design_system/app_palette.dart` | A | raw hex — never used in widgets |
| `design_system/app_semantic_colors.dart` | A | `ThemeExtension`, role tokens, light/dark, `copyWith` + `lerp` |
| `design_system/app_text_styles.dart` | A | **role-based** type scale (M3 roles), built inside `ScreenUtilInit` |
| `design_system/app_spacing.dart` | G | `AppSpacing`, `AppRadius`, `AppShadows` |
| `design_system/app_theme.dart` | A | full `ColorScheme` + component themes (appBar, bottomSheet, card, input, navigationBar) |
| `design_system/app_theme_context.dart` | G | `context.colors` / `context.texts` / `context.scheme` |
| `design_system/app_validators.dart` | A | field validators + max lengths (see §14) |
| `design_system/widgets/` | G | AppButton (on `FilledButton`), AppCard, AppSectionHeader, AppStateView, AppProgressBar, AppNetworkImage (cached), ConfirmSheet, ImageSourceSheet, CustomTextFormField, PasswordTextFormField |
| `media/image_picker_service.dart` | G | pick → crop → compress (strip EXIF), no BuildContext; `retrieveLostData()` on Android |
| `location/location_service.dart` | G | geolocator + reverse geocoding, typed exceptions |
| `permissions/app_permission_service.dart` | G | `openSystemSettings()` |
| `format/` | G | amount/date formatters (dates converted to **local** time) |

### `lib/app/`, `lib/main.dart`
| Path | Purpose |
|---|---|
| `main.dart` | ensure bindings → `AppConfig.validate()` → error hooks → `configureDependencies()` → `runApp` → `session.bootstrap()` |
| `app/app.dart` | `MaterialApp.router`, `theme/darkTheme/themeMode`, locale delegates, `builder: TextScaleScope` |
| `app/di.dart` | `configureDependencies()` — **the same function** is called by the DI test |
| `app/router/` | router + route policies |

### `test/`
| Path | Purpose |
|---|---|
| `helpers/fake_http_adapter.dart` | records `RequestOptions`, returns canned `ResponseBody` |
| `helpers/pump_app.dart` | wraps ScreenUtilInit + theme + localization + viewport (default 375×812, also 320) |
| `helpers/mocks.dart` | one `Mock` per repository/use-case contract |
| `fixtures/api/*.json` | sanitized real responses — parsed by model/contract tests |
| `di/di_test.dart` | calls `configureDependencies()` and resolves every Cubit |
| `localization/localization_test.dart` | key parity, missing/unused/duplicate/empty, `{args}` parity, hardcoded-text scan |
| `core/architecture_test.dart` | fails if `core/` imports `features/` or `app/`; if `domain/` imports Flutter/Dio |
| `core/design_system/theme_test.dart` | token values pinned, `.sp` scales, WCAG contrast light + dark |

### Repo root
`.fvmrc` · `.gitignore` · `.gitattributes` · `analysis_options.yaml` · `env/{dev,staging,prod}.json`
(+ `env/example.json`, `env/local.json` gitignored) · `.vscode/launch.json` · `lefthook.yml` ·
`.github/{workflows/ci.yml, pull_request_template.md, dependabot.yml}` · `README.md` ·
`CHANGELOG.md` · `RELEASE.md` · `LICENSE` · `CLAUDE.md` · `docs/{ARCHITECTURE.md, PLAYBOOK.md, api/, adr/}` ·
`.claude/{settings.json, commands/}`. Templates in §15.

---

## 4. Naming & code style

**Naming**
| Thing | Convention |
|---|---|
| Files / folders | `snake_case.dart`; collections plural (`complaints/`), singletons singular (`profile/`) |
| Entity | `Complaint` — `final class ... extends Equatable` |
| Enum from API | `enum X { a, b, unknown; final String wireValue; static X fromApi(String?) }` — unknown = least privilege |
| Repository | `XRepository` (domain) / `XRepositoryImpl` (data) |
| Datasource | `XRemoteDataSource` / `XRemoteDataSourceImpl` — **always the same file layout** |
| Model | `XModel.fromJson` / `toJson` / `toEntity()` |
| Use case | `x_usecase.dart` → `XUseCase` + `XParams` (Equatable, or a Dart record) |
| Cubit / State | `XCubit extends Cubit<XState>`, `final class XState extends Equatable`, `enum XStatus` |
| DI | `register<Feature>Dependencies(GetIt sl)` |
| Routes | `AppRoutes.camelCase` constants, kebab-case paths, sub-screens nested (`/profile/settings`) |
| Translation keys | flat `snake_case`, prefixed by feature (`complaint_submit_title`) |
| Branches | `feat/<scope>-<slug>`, `fix/…`, `chore/…`, `refactor/…` |

**Style**
- Dart 3: `sealed`, `final class`, switch expressions, pattern matching on `Result`, records for small value bundles (but give a record a **named class** once it appears in more than one file).
- `const` everywhere possible; `prefer_final_locals`.
- Package imports **or** relative imports — choose one (lint-enforced).
- File soft limit ~300 lines; `build()` ~60–80 lines; >150 lines is a review blocker → extract private widgets per visual section.
- No banner separator comments (`// ------`). Let file names and class names speak.
- Comments: current *why* in 1–3 lines, English. Bug stories → commits/PRs; decisions → ADRs.
- Grep-able assumption tag: `// ASSUMPTION(api): <what> — confirm in docs/api/<area>.md`.

---

## 5. State management & error handling

**Cubit template**
```dart
Future<void> load() async {
  emit(state.copyWith(status: XStatus.loading));
  final result = await _getX(const NoParams());
  if (isClosed) return;
  switch (result) {
    case Ok(:final value):
      emit(state.copyWith(status: XStatus.ready, items: value));
    case Err(:final failure):
      emit(state.copyWith(status: XStatus.error, errorMessage: failure.message));
  }
}
```
- `errorMessage` is cleared by `copyWith` unless passed (stale errors otherwise survive reloads).
- Englizia: the state keeps `Failure? failure` instead of `errorMessage` (same clearing rule) and the page renders `failure.localizedMessage` — ADR 1.
- Parallel section loading: each section keeps its own status; one failing section never blanks the screen.
- Forms: `canSubmit` includes `!isSubmitting`; buttons disabled with a null `onPressed` (not `AbsorbPointer`).
- Long forms: guard back/swipe with `PopScope` + "discard changes?" sheet.

**Repository template**
```dart
@override
Future<Result<List<Complaint>>> getMine() =>
    guard(() async => (await _remote.getMine()).map((m) => m.toEntity()).toList());
```
```dart
// core/result/result.dart
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } catch (error, stackTrace) {
    AppLogger.error(error, stackTrace);
    return Err(FailureMapper.fromError(error));
  }
}
```
- Englizia: `guard()` is in `core/result/guard.dart` and does not log itself; `FailureMapper.fromError(error, stackTrace)` logs once — ADR 2.
- Every `catch` keeps the stack trace. Nothing is swallowed silently — at minimum it is logged.
- Endpoint-specific semantics (e.g. 401 on **login** = wrong credentials, not expired session) are handled in that repository **before** the generic mapper.
- Consider letting `Failure` carry a type/key and translating in presentation; keeps `core/error` free of `easy_localization`.

---

## 6. Networking

- One Dio for the app (+ one bare Dio for token refresh). Interceptor order: auth → (debug-only) logger.
- **Headers on every request**: `Accept`, `Accept-Language: <current locale>`, `X-App-Version`, `X-Platform`.
- **Timeouts**: short (≈20 s) for JSON; **per-request** long/zero `sendTimeout` + `onSendProgress` for multipart uploads. Compress/cap video before upload.
- **Refresh**: the refresh Dio has no interceptors → it must set `Authorization: Bearer <current>` itself. Pin this with a test that asserts the header.
- **Logout** calls the server (best effort, short timeout) **then** clears local state.
- **Signed-out users never call protected endpoints** — a 401 triggers logout logic. Guests hold a guest account's tokens (ADR 10) and call them like members.
- **JSON**: one `json_reader.dart` extension (or `json_serializable`/`freezed`); never re-implement `_asInt` per model. Turn on `strict-casts`.
- **Contract**: real responses saved as sanitized fixtures; a renamed backend field must fail a test, not silently show `0`.
- **Pagination** from the first list; no N+1 per-item enrichment calls — ask the backend for aggregated fields. If unavoidable, limit to visible items and cache.
- **Images**: `AppNetworkImage` over `cached_network_image` with `memCacheWidth` based on rendered size.
- **App version gate**: `GET /api/app/config` → `min_supported_version`; router shows a blocking update screen below it. Ask the backend to keep deprecated routes alive one release cycle.
- **API versioning**: prefer `/api/v1/...` if you can influence the backend.

---

## 7. Design system

| Rule | Detail |
|---|---|
| No raw color | No `Color(0x…)`/`Colors.*` in widgets (allow `Colors.transparent`). Test greps `lib/features`. |
| Role tokens | `textPrimary`, `surface`, `notice…` — never physical names (`black`). |
| Role type scale | `context.texts.titleMedium`, `bodySmall`… (M3 roles). Color via `.copyWith(color: context.colors.x)`. No raw `TextStyle(fontSize:)` in features. |
| Spacing tokens | `AppSpacing.md` etc. No magic paddings. |
| Component themes | Define `appBarTheme`, `bottomSheetTheme`, `cardTheme`, `inputDecorationTheme`, `navigationBarTheme` (label size that fits 5 tabs at 320dp in both languages) — so widgets don't repeat overrides. |
| Full `ColorScheme` | Material widgets derive dozens of colors from it. |
| Built inside `ScreenUtilInit` | `.sp` must be computed against the real screen. |
| Fonts | One Arabic+Latin family; declare every weight used (`weight: 500`…), or a variable font. |
| Buttons | Build on `FilledButton`/`OutlinedButton` (semantics, focus, ripple), not `GestureDetector`. |
| Accessibility | ≥48dp tap targets (don't scale them with `.w`), tooltips/labels on icon buttons, test with `meetsGuideline(androidTapTargetGuideline)` and `labeledTapTargetGuideline`. |
| Skeletons | Only for first load of network content; wrap the real widget with fake data when possible; shimmer colors from tokens; build only inside the `isFirstLoad` branch. |

---

## 8. Localization & RTL

- `easy_localization`, `assets/translations/{ar,en}.json`, flat snake_case keys, `namedArgs`.
- **No `startLocale` override** — let the device locale decide; `fallbackLocale` = your primary audience language.
- **Plurals**: `'items_count'.plural(n)` with `zero/one/two/few/many/other` in Arabic. Never "1 items".
- **Literal keys only** before `.tr()` (the scanner test needs them). To choose between keys, pass a `String Function()` translator, not a key name.
- **Numbers & dates**: decide once (Latin digits everywhere, or locale digits everywhere). Convert UTC → local before display. One date formatter.
- **RTL**: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`. Use the *forward* icon (`chevron_right`) and let `matchTextDirection` flip it — never swap icons manually.
- App name localized on both platforms; iOS `CFBundleLocalizations` = `ar, en`.
- Send `Accept-Language`; ask the backend to localize validation messages and return stable machine `code`s for business errors. Never show raw backend English to Arabic users.

---

## 9. Testing

**Strategy (value-first, not count-first)**
| Layer | Tool | What to test |
|---|---|---|
| Models | fixtures + `test()` | real (sanitized) responses parse; missing/odd fields degrade safely |
| Datasources / repos | `FakeHttpAdapter` | request **shape** (path, method, body field names, headers) and error → Failure |
| Interceptors / refresh / guards | `FakeHttpAdapter` | every branch (401 → refresh → retry, refresh fail → logout) |
| Cubits | `bloc_test` + `mocktail` | state sequences, races (stale refresh overwriting optimistic update) |
| Widgets | `pump_app` at 375 **and** 320 width | no `takeException()`, AR + EN, light + dark, a11y guidelines |
| DI | `configureDependencies()` | every Cubit resolves |
| Localization | scanner test | parity, unused, missing, args, hardcoded text |
| Architecture | import scanner | layer rules hold |
| Integration | `integration_test/` | one happy path (login → home → main action) against a fake API |

- One-line delegating use cases don't need their own tests — test the Cubit that calls them.
- `Params` classes used in `verify()` must have value equality (Equatable or records).
- `pumpAndSettle` hangs with infinite animations (shimmer, spinners) → use `pump()`.
- One `EasyLocalization` mount per test file (second mounts can silently render nothing).
- Coverage floor in CI, ratcheted upward (aim ~80% on domain/data).

---

## 10. Git & GitHub

**Flow: GitHub Flow, even solo**
1. `main` is always releasable and **protected**: PR required, CI required, no force-push.
2. Every change on a short-lived branch (`feat/complaints-submit`). Push daily — never keep work only on one disk, never leave WIP uncommitted overnight (a `wip:` commit on a branch, squashed later, is free backup).
3. Open a PR even when alone: CI runs, you review your own diff once, the description is the change log. Squash-merge with a Conventional Commit title.
4. **One logical change per commit**, roughly <400 changed lines; never mix feat/fix/refactor. If the header needs a comma-separated list, it is several commits. Use `git add -p`.
5. Follow-up fixes get their own subject (or `git commit --fixup` + `rebase --autosquash` before sharing).

**Commits** — Conventional Commits with scope and a body that explains *why*:
```
fix(auth): send bearer token on refresh request

The refresh Dio has no interceptors, so the header was never attached and
every token expiry logged the user out. Adds a test asserting the header.
```
Enforce with a `commit-msg` hook (lefthook + regex, or commitlint).

**Versioning & releases**
- SemVer. Pre-release work at `0.x`; MINOR per feature, PATCH per fix.
- Bump `+build` on every distributed build; tag `vX.Y.Z` on the same commit.
- `CHANGELOG.md` (Keep a Changelog) — or generate it + GitHub Releases with **release-please** from your Conventional Commits.

**Repo hygiene**
- Client/team repos **private by default**. Portfolio → separate sanitized showcase repo, with client approval.
- `LICENSE` (or "All rights reserved"), description, topics, real README with screenshots.
- No real personal data anywhere (tests, docs, fixtures). Once pushed, deleting is not enough — history keeps it.
- Use your GitHub `noreply` email for commits on public repos; enable SSH commit signing.
- Secrets: never in git; GitHub secret scanning + push protection on; optional `gitleaks` hook.
- Decide an AI co-author trailer policy per client and apply it consistently.
- Keep project documents (contract, user stories, ERD) **inside** the repo under `docs/` — files outside git have no history and are invisible to CI and reviewers.

**Automation**
- `ci.yml` on PR + push to main: pub get → format check → analyze → test + coverage.
- `dependabot.yml` for `pub` and `github-actions`.
- `lefthook`: pre-commit (format, analyze), pre-push (tests).

---

## 11. Environments & release

**Environments — never edit source to switch backend**
```
env/dev.json        {"APP_ENV": "dev",     "BASE_URL": "https://dev.example.com"}
env/staging.json    {"APP_ENV": "staging", "BASE_URL": "https://staging.example.com"}
env/prod.json       {"APP_ENV": "prod",    "BASE_URL": "https://api.example.com"}
env/local.json      (gitignored) personal tunnels, e.g. ngrok
env/example.json    committed template
```
`flutter run --dart-define-from-file=env/dev.json`. `AppConfig.validate()` fails fast at startup
if `BASE_URL` is empty. Show a small env badge in non-prod builds.
⚠️ `--dart-define` values are compiled into the binary — **never put real secrets there**.
Add Android flavors / iOS schemes only when you need side-by-side installs or different app IDs/icons.

**Mock mode** (`env/mock.json` → `APP_ENV=mock`): `configureDependencies()` registers fake
datasources that read `test/fixtures/api/*.json` instead of the real Dio ones.
Englizia: the fakes read `assets/mock/<feature>/*.json` (fixtures under `test/` are not bundled),
and the tests parse those same files; `test/fixtures/api/` holds real responses once they exist. You can then
develop, demo to a client, and record screenshots without depending on a teammate's server
or an ngrok tunnel. Same fixtures power the tests.

**Scaffolding**: don't hand-write the 10–30 files of a feature. Use a `mason` brick
(`mason make feature --name complaints`) or a `.claude/commands/new-feature.md` command that
generates domain/data/presentation/injection + test skeletons from §2.

**Release (put the exact commands in `RELEASE.md`)**
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define-from-file=env/prod.json --build-number=<N>
flutter build ipa --release --obfuscate --split-debug-info=build/symbols \
  --dart-define-from-file=env/prod.json --build-number=<N>
```
- Android release signing via `key.properties` (gitignored) — template in §15. Keystore backed up off-repo; enroll in Play App Signing.
- Upload the `build/symbols` to your crash reporter.
- Automate later: tag-triggered GitHub Actions workflow with signing secrets in GitHub Secrets.

**Store compliance checklist (before the first upload)**
- [ ] Real application ID / bundle ID; release-signed; version bumped.
- [ ] In-app **account deletion** (Apple 5.1.1(v), Google Play policy) + web deletion URL for Play.
- [ ] Privacy Policy + Terms reachable in-app (and before sign-up); consent recorded server-side.
- [ ] Every permission has an accurate, localized purpose string — **including `NSMicrophoneUsageDescription` if you record video**.
- [ ] Play **Data safety** form matches what you actually collect (IDs, location, media).
- [ ] Open-source licenses screen (`showLicensePage`).
- [ ] Icons/splash for both platforms; app name localized.
- [ ] `android:allowBackup="false"` (or backup rules excluding secure storage).
- [ ] Screens showing ID documents: consider screenshot protection.

---

## 12. Production essentials

| Concern | Minimum |
|---|---|
| Crash reporting | Sentry (`sentry_flutter`) or Firebase Crashlytics, enabled for staging/prod, symbols uploaded. |
| Global handlers | `FlutterError.onError`, `PlatformDispatcher.instance.onError`, release `ErrorWidget.builder`; `bootstrap()` in try/catch with signed-out fallback. |
| Logging | `AppLogger` only. `print` banned (`avoid_print: error`). Dio logger only `if (kDebugMode)` and redacting `Authorization`, `password*`, `token`, national ID, phone numbers. `GoRouter(debugLogDiagnostics: kDebugMode)`. |
| Security | flutter_secure_storage for tokens; no PII in SharedPreferences; HTTPS only (no cleartext in release); clear secure storage on first launch after reinstall (iOS Keychain survives uninstall); delete temp media (ID photos) after upload and on logout; optional certificate pinning once the prod domain is stable. |
| Platform | portrait lock; `image_picker.retrieveLostData()` on Android; Android 13 `POST_NOTIFICATIONS` if push. |
| Network resilience | timeouts per request type, friendly offline message, retry button on every error state. |
| Analytics | optional, consent-gated, no PII, behind an `AnalyticsService` interface (no-op default). |
| Push | only when there is a real endpoint; send FCM token after login and on refresh. Don't ship UI (e.g. a bell) that does nothing — hide it or mark it "coming soon". |

---

## 13. Docs & AI workflow

**Structure**
```
CLAUDE.md               ≤150 lines: summary, commands, layers, non-negotiables, DoD, pointers
README.md               humans: pitch, screenshots, features, stack, setup, env, tests, release link
CHANGELOG.md            Keep a Changelog
RELEASE.md              exact build/sign/upload steps
docs/ARCHITECTURE.md    layers, DI, Result/Failure, state, theme, i18n
docs/PLAYBOOK.md        this file
docs/api/<area>.md      endpoint | method | body | status (confirmed/assumed) | fixture link
docs/api/openapi.yaml   preferred: exported by the backend (Scribe / l5-swagger)
docs/adr/NNNN-*.md      one decision per file: Context · Decision · Consequences · Status
```

**Rules**
- Docs describe the **current state**. When something changes, edit/delete the old statement in the same commit. No append-only logs.
- Volatile numbers (test count, key count) never go in docs.
- A doc for AI agents is not a changelog. Every KB in `CLAUDE.md` is paid in every session and every sub-agent.
- English for repo text (cheaper in tokens than Arabic, readable by any collaborator/client). Arabic stays in `ar.json` and stakeholder-facing product docs.

**Claude Code project config** (`.claude/`)
- `settings.json`: `permissions.allow` for safe read-only commands (`flutter analyze`, `flutter test`, `dart format`, `git status/diff/log`).
- Hooks: `PostToolUse` on Edit/Write → `dart format <file>`; `Stop` → `flutter analyze` + localization test, blocking on failure.
- `commands/new-feature.md`: scaffolds domain/data/presentation/injection from §2.
- `commands/sync-docs.md`: compares the diff with `CLAUDE.md`/`docs/` and updates stale statements.

---

## 14. Hard-won lessons (each one cost real debugging time)

**Layout**
- `flutter_test` default width is 800 logical px → `RenderFlex overflow` never appears unless you pin 375/320.
- `Row(crossAxisAlignment: stretch)` inside a vertical `ListView` throws (infinite height) → `IntrinsicHeight`.
- Horizontal `ListView` inside a fixed-height `SizedBox` stretches every item to full height → `SingleChildScrollView(horizontal) + Row`.
- `Flexible` on both sides of a row splits 50/50 → interactive control keeps its size, the label ellipsizes.
- Material defaults can be too big for your design (`NavigationBar` label used `labelMedium` 14sp → wrapped in 3 of 5 tabs). Measure with `tester.getSize` across 320–428 widths; binary-search the safe value.
- Reading an `InheritedWidget` (`context.locale`, `Theme.of`, `MediaQuery`) in `initState` crashes on device → use `didChangeDependencies`/`build`.

**State & screens**
- A section **announces its state** (empty/error card with retry); it never disappears. Several empty sections together otherwise look like a broken page.
- Silent background refresh must not race an optimistic update — sequence them.
- Bottom sheet swipe-to-dismiss bypasses `PopScope`; track picker values outside the sheet state.
- The screen that *grants* a permission (e.g. identity verification) must not be guarded by that permission.

**Backend integration**
- Never trust a guessed field name; confirm with a real response or the backend source. Save it as a fixture.
- Same concept can arrive under different shapes between endpoints (`category` object vs `category_id`, `location` vs `pin`, `file_url` vs `file_path`). Centralize the reader as soon as it repeats.
- A field can be an **object**, not a scalar (`my_vote: {value: true, ...}`); a naive bool parser silently inverts UI state.
- Don't send query params you don't need (`type=news` hid every announcement).
- Multipart arrays may need explicit indexes (`media[0]`, `media[1]`), not `media[]`.
- Every status code you can receive needs a translated message (`409` leaked raw English).
- A static flag (`is_votable`) ≠ live state (`voting_status == 'active'`). Use the computed field.
- `INTERNET` permission must be in the **main** Android manifest — debug builds hide its absence.
- Major package versions break APIs (`geocoding` 5, `file_picker` 12) — read the changelog before upgrading.

**Field limits**
| Field | Max | Why |
|---|---|---|
| email | 254 | RFC 5321 |
| password (new) | 64 | bcrypt silently truncates at 72 bytes |
| name | 50 | longest real names ~35 chars |
| **login password** | none | an existing password may predate the policy — a cap locks the owner out |

---

## 15. Templates

### `analysis_options.yaml`
```yaml
include: package:flutter_lints/flutter.yaml   # or: package:very_good_analysis/analysis_options.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    avoid_print: error
    unawaited_futures: warning
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - always_declare_return_types
    - always_use_package_imports
    - avoid_dynamic_calls
    - avoid_print
    - cancel_subscriptions
    - close_sinks
    - directives_ordering
    - prefer_const_constructors
    - prefer_final_locals
    - prefer_single_quotes
    - unawaited_futures
    - use_super_parameters
```

### `.gitignore` (append to the Flutter template)
```gitignore
# Environments & secrets
.env*
!.env.example
env/local.json
*.jks
*.keystore
*.p12
*.mobileprovision
key.properties
**/google-services.json
**/GoogleService-Info.plist

# Tooling
.fvm/flutter_sdk
coverage/
.claude/settings.local.json
```

### `.gitattributes`
```gitattributes
* text=auto eol=lf
*.bat text eol=crlf
*.cmd text eol=crlf
*.png binary
*.jpg binary
*.jpeg binary
*.webp binary
*.gif binary
*.ttf binary
*.otf binary
*.jks binary
*.keystore binary
```
After adding it to an existing repo: `git add --renormalize .`

### `lib/core/config/app_config.dart`
```dart
abstract final class AppConfig {
  static const appEnv = String.fromEnvironment('APP_ENV');
  static const baseUrl = String.fromEnvironment('BASE_URL');

  static const jsonTimeout = Duration(seconds: 20);

  static bool get isProd => appEnv == 'prod';

  static void validate() {
    if (baseUrl.isEmpty) {
      throw StateError(
        'BASE_URL is missing. Run with --dart-define-from-file=env/<env>.json',
      );
    }
  }
}
```

### `.vscode/launch.json`
```json
{
  "version": "0.2.0",
  "configurations": [
    { "name": "dev", "type": "dart", "request": "launch", "program": "lib/main.dart",
      "args": ["--dart-define-from-file=env/dev.json"] },
    { "name": "staging", "type": "dart", "request": "launch", "program": "lib/main.dart",
      "args": ["--dart-define-from-file=env/staging.json"] },
    { "name": "local", "type": "dart", "request": "launch", "program": "lib/main.dart",
      "args": ["--dart-define-from-file=env/local.json"] }
  ]
}
```

### `lib/main.dart` (shape)
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error(error, stack);
    return true;
  };

  await EasyLocalization.ensureInitialized();
  await configureDependencies();

  runApp(const App());
  await sl<AppSessionController>().bootstrap(); // try/catch inside → signed-out fallback
}
```

### Android release signing (`android/app/build.gradle.kts`)
```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) load(FileInputStream(file))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### `.github/workflows/ci.yml`
```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.41.6   # keep in sync with .fvmrc
          cache: true
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed lib test
      - run: flutter analyze --fatal-infos
      - run: flutter test --coverage
```

### `.github/dependabot.yml`
```yaml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### `.github/pull_request_template.md`
```markdown
## What

## Why

## How it was verified
- [ ] `flutter analyze --fatal-infos` clean
- [ ] `flutter test` green
- [ ] Ran on a device (Android / iOS)
- [ ] Arabic (RTL) + English, light + dark, 320dp width

## Screenshots

## Also updated
- [ ] translations (ar + en)   - [ ] docs / ADR   - [ ] fixtures   - [ ] CHANGELOG
```

### `lefthook.yml`
```yaml
pre-commit:
  parallel: true
  commands:
    format:
      glob: "*.dart"
      run: dart format --output=none --set-exit-if-changed {staged_files}
    analyze:
      run: flutter analyze --no-pub

commit-msg:
  commands:
    conventional:
      run: >
        head -n1 {1} | grep -qE '^(feat|fix|refactor|chore|docs|test|perf|build|ci|style|revert)(\([a-z0-9,_-]+\))?!?: .+'
        || (echo "Commit subject must follow Conventional Commits" && exit 1)

pre-push:
  commands:
    test:
      run: flutter test
```

### `core/network/json_reader.dart`
```dart
extension JsonReader on Map<String, Object?> {
  int? readInt(String key) => switch (this[key]) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v) ?? double.tryParse(v)?.toInt(),
        _ => null,
      };

  double? readDouble(String key) => switch (this[key]) {
        num v => v.toDouble(),
        String v => double.tryParse(v),
        _ => null,
      };

  bool? readBool(String key) => switch (this[key]) {
        bool v => v,
        num v => v != 0,
        String v => v == 'true' || v == '1',
        _ => null,
      };

  String? readString(String key) => switch (this[key]) {
        String v when v.trim().isNotEmpty => v,
        _ => null,
      };

  Map<String, Object?>? readMap(String key) => switch (this[key]) {
        Map<String, Object?> v => v,
        Map v => v.cast<String, Object?>(),
        _ => null,
      };

  /// First non-null value among candidate keys (for unconfirmed contracts).
  T? firstOf<T>(List<String> keys, T? Function(String key) read) {
    for (final key in keys) {
      final value = read(key);
      if (value != null) return value;
    }
    return null;
  }
}
```

### `README.md` outline
```markdown
# <App Name>
One-paragraph pitch. Screenshots (light/dark, AR/EN).
## Features
## Tech stack
## Architecture   → docs/ARCHITECTURE.md
## Getting started
- Flutter <version> (FVM: `fvm install`)
- `flutter pub get`
- `cp env/example.json env/local.json` and fill BASE_URL
- `flutter run --dart-define-from-file=env/dev.json`
## Tests          `flutter test` · `flutter analyze`
## Release        → RELEASE.md
## License / ownership
```

### ADR template (`docs/adr/0001-state-management.md`)
```markdown
# 1. Cubit for state management
Status: Accepted · Date: YYYY-MM-DD
## Context
## Decision
## Consequences
```
Seed every new project with ADRs for: state management, error handling (Result/Failure),
DI, i18n, theming, environments.
