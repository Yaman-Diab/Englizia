# Englizia codebase audit report

- **Date:** 2026-10-13
- **Scope:** `main` at commit `df369b8`, Flutter 3.41.6.
- **Mode:** audit only. No changes were made to code, configuration or git history.

**Generated files:**
- `flutter test --coverage` regenerated `coverage/`, which git ignores.
- The coverage script lives in the session scratchpad, outside the repo.

**What was inspected:**
- All 50 files under `lib/` and all 21 test files.
- `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `RELEASE.md`, `CHANGELOG.md`, `docs/ARCHITECTURE.md`, `docs/api/`, the ADRs.
- `pubspec.yaml`, `analysis_options.yaml`, `env/*`, the Android manifest and Gradle file, and `Info.plist`.
- There is no `AGENTS.md`.

**Skills:**
- The project's `/new-feature` and `/sync-docs` commands don't apply to an audit.
- The `code-review-and-quality` skill was loaded, and its five axes were applied: correctness, readability, architecture, security, performance.
- The skill also recommends mutating code to check whether tests catch it. That was **not** run, because the audit forbids changing files. Test-gap judgments rest on reading the code plus coverage.

---

## 1. Executive summary

**Main finding:** the project is still a foundation.
- There is no feature folder (`lib/features/` doesn't exist).
- There is no repository, no data source and no feature Cubit.

This audit therefore judges the core layer and the app shell as they are. Rules about how features apply the standards (Cubit states, repositories, real API contracts) are **NOT VERIFIED**: the evidence doesn't exist yet. That is not a failure.

**What follows the standards, by inspection:**
- **Layer separation:** enforced by a test.
- **Single error funnel:** `ApiClient` → `guard` → `FailureMapper` → `FailureL10n`.
- **Translations:** every visible string is translated, and an automated test checks it.
- **Directional layout:** enforced by a test.
- **Color tokens:** read from the theme only.
- **Logs:** redacted.
- **Tokens:** kept in secure storage.

**Most important concerns:**
1. **A real High-priority bug:** any 5xx response from the token-refresh endpoint signs the user out (`auth_interceptor.dart:99-103`).
2. **No release diagnostics:** the crash reporter is a no-op, so errors after release are lost.
3. **Test gaps:**
   - `AppButton`, `AppStateView`, `FailureL10n` and `SecureTokenStorage` have no tests.
   - Dark mode isn't covered by any widget test.
4. **A doc overstatement:** `CLAUDE.md` presents `env/mock.json` as "Run (no backend)", but mock mode isn't implemented.

---

## 2. Compliance scorecard

| Area | Status | Evidence | Main concern |
|---|---|---|---|
| Architecture | PASS (core) / NOT VERIFIED (features) | `test/core/architecture_test.dart` enforces that `core` doesn't import `app`/`features`, plus the domain rules. `lib/app` is the only composition root | No feature exists yet to check the feature layers against |
| Cubit and states | PARTIAL | `SettingsCubit` follows the rules (`final class` state, Equatable, `copyWith`) and is tested with `bloc_test` | It's the only Cubit. Loading, error and empty patterns haven't been exercised yet |
| Repositories and services | NOT VERIFIED | `guard()`, `UseCase` and `Result` exist but nothing uses them | No repository or data source exists |
| Dio and API handling | PARTIAL | `ApiClient`, ProblemDetails parsing, a shared token refresh; tests cover 81–100% of the files | A 5xx from refresh signs the user out. An `unknown` Dio error shows "unexpected error" to the user |
| Dependency injection | PASS | `configureDependencies()` is shared by `main` and `di_test`. `sl<>()` is used only in `app/` and `main` | Some registrations are concrete classes, while the rule says "interfaces" (a wording issue) |
| Error handling | PARTIAL | Every catch keeps the stack trace. Every failure type has a translation | No-op reporter in release. `ErrorWidget` hides errors. Storage write failures are swallowed |
| Localization and RTL | PASS | `localization_test` (parity, args, unused keys, hardcoded text). The directional rule in `architecture_test`. RTL checked in `app_test` | The hardcoded-text scan only covers `Text('...')`. Plurals and number formatting haven't been exercised |
| Design system | PASS (with a conflict note) | Tokens come from `context.colors` / `context.texts`. Contrast is pinned in `theme_test` | The general naming standard (`f16W400Black`, no `height`) differs from the role-based approach the project adopted. Needs a decision |
| Code quality | PASS | Analyzer clean, format clean, `strict-casts` on | Scaffolding not used yet. A few small magic numbers |
| Testing | PARTIAL | 99 tests pass. 78.4% line coverage | Four files have no tests. `SecureTokenStorage` is at 35%. No dark-mode test. No integration test |
| Security | PASS (with notes) | `flutter_secure_storage`, redaction, `allowBackup=false`, debug-only logging | `graphify-out/` isn't ignored. The release reporter will receive raw errors once a real provider is added |

---

## 3. Critical violations

**None at Critical level.**
- No security or correctness problem is currently reachable by a user.
- No feature calls the network yet, and no build has been distributed.

**Highest finding (High): refresh error classification**

| | |
|---|---|
| **Rule** | Sign the user out only when the server rejects the refresh token. |
| **Status** | FAIL. Confirmed by reading the code; no test was run, because files couldn't be changed. |
| **Evidence** | `lib/core/network/auth_interceptor.dart:99-103`. Any `DioException` that carries a response, whatever its status code, returns `_Rejected`, and `_Rejected` calls `onSessionExpired`. |
| **Problem** | A 500, 502 or 503 from the refresh endpoint is treated as a rejected token. |
| **Impact** | A brief server outage signs out every user whose access token happens to expire during it. |
| **Smallest fix** | Treat 400/401/403 as `_Rejected` and every other status as `_Unavailable`. Add one test to `auth_interceptor_test.dart`; the current tests only cover a 401 (line 97) and a connection failure (line 124). |
| **Priority** | High (P1) |

---

## 4. Architectural inconsistencies

1. **Mock mode is claimed but not implemented.**
   - `CLAUDE.md:18` lists "Run (no backend) | env/mock.json".
   - `AppConfig.isMock` (`app_config.dart:9`) isn't used anywhere, and no fake data sources exist.
   - Running with `mock.json` uses the real Dio against `https://mock.invalid`.
   - `ARCHITECTURE.md:84` is accurate ("reserved for"). `CLAUDE.md` overstates.

2. **"Register interfaces, not impls" (`CLAUDE.md`) versus the implementation.**
   - `service_locator.dart:29-60` registers these as concrete classes: `SettingsStorageService`, `ApiClient`, `AppSessionController`, `AppHeadersInterceptor`, `CurrentLanguage`.
   - They are infrastructure classes with no contracts, so adding interfaces would be over-engineering.
   - Recommendation: clarify the rule ("interfaces for repository and data-source contracts") rather than change the code.

3. **Merge method.**
   - `CONTRIBUTING.md:15` says to squash-merge.
   - The last merge into `main` used merge commits, as the user asked.
   - The document and the practice disagree.

4. **Definition of Done: "Checked at 320dp, Arabic + English, light + dark".**
   - `app_test` covers 320/375dp and Arabic/English in light mode only.
   - Dark mode is only checked through the color contrast values in `theme_test`, never on a rendered screen.

---

## 5. File-by-file findings

### Networking and session

| File | Finding | Priority |
|---|---|---|
| `core/network/auth_interceptor.dart:99-103` | A 5xx from refresh signs the user out (see section 3) | High |
| `core/network/auth_interceptor.dart:106-109` | A malformed refresh response (for example, no `accessToken`) also signs the user out. Defensible, but not documented | Low |
| `core/network/api_client.dart:67-74` | `DioExceptionType.unknown` is returned unconverted, so the user sees "unexpected error" instead of "network error". Which platform errors arrive as `unknown` is NOT VERIFIED | Low |
| `core/storage/secure_token_storage.dart:28-33` | A failed read is cached as `null` (`_loaded = true`), with no retry for the rest of the session | Low |
| `core/storage/secure_token_storage.dart:37-45` | A failed write is swallowed (only logged). `signIn` looks successful, but the session is lost on the next launch | Medium |
| `core/router/app_redirect.dart:32-35` | During bootstrap every route goes to splash, then to home. The original destination of a deep link or notification is lost | Medium (before v1.0 notifications) |
| `app/router/app_router.dart:17` | `loginLocation` temporarily points to `home`. Documented, and harmless while no protected routes exist | Low |
| `core/network/api_exception.dart:44-48` | `normalizeField` drops indexes (`Items[0].Name` becomes `name`), so field errors could collide. Depends on the .NET contract | Low |
| `core/network/json_reader.dart:20` | `readBool('abc')` returns `false` instead of `null` | Low |

### Initialization, logging and errors

| File | Finding | Priority |
|---|---|---|
| `core/logging/crash_reporter.dart` + `main.dart:22-25` | In release every error goes to `NoopCrashReporter`. Already listed as a blocker in `RELEASE.md` | High (before the first tester build) |
| `main.dart:26-28` | In release, `ErrorWidget` becomes `SizedBox.shrink()`, so a broken part of the screen just disappears | Low |
| `core/logging/app_logger.dart:40-42` | In release the raw error goes to the reporter without redaction. A future risk once a real provider is added | Low |
| `core/network/api_status_codes.dart:2-4,12` | `ok`, `created`, `noContent` and `internalServerError` are unused | Low |

### Design system and UI

| File | Finding | Priority |
|---|---|---|
| `core/design_system/widgets/app_button.dart:29-31` | The numbers `20` and `strokeWidth: 2` aren't in `AppSizes`. The file has no test | Low / test gap |
| `core/design_system/widgets/app_state_view.dart` | No test, and no screen uses it yet | Test gap |
| `core/design_system/app_text_styles.dart:52` + `app/app.dart:44-46` | `.sp` with `minTextAdapt` shrinks text on small phones (16 becomes about 13.7 at 320dp). This is on top of the 0.9–1.3 text-scale clamp (`app.dart:73-74`). An accessibility trade-off inherited from the playbook | Needs a decision |
| `core/design_system/app_theme.dart` | Uses the role tokens. `Colors.transparent` is the only raw color, and it is allowed | PASS |

### Localization

| File | Finding | Priority |
|---|---|---|
| `core/l10n/failure_l10n.dart` | Never loaded by any test. No test confirms that each failure type maps to its translation key | Medium |
| `test/localization/localization_test.dart:86-90` | The hardcoded-text scan only covers `Text('...')` and Arabic characters. A literal in `tooltip:`, `hintText:`, `labelText:` or `semanticsLabel:` would slip through | Medium |

### Tests and repository

| File | Finding | Priority |
|---|---|---|
| `test/core/architecture_test.dart:44,64` | The raw-color scan covers `lib/features` only, not `lib/app` | Low |
| `test/app/app_test.dart` | No dark-mode test (`pump_app` defaults to `ThemeMode.light`) | Low |
| `.gitignore` | `graphify-out/` isn't ignored. It contains a cache and absolute paths, and could be committed by accident | Low |
| `README.md` | The tech-stack list omits `google_fonts` | Low |

---

## 6. Missing or incomplete implementations

- **All product features:** sign-in, tracks, lessons, exercises, placement test, and so on. Expected at this stage, per the roadmap.
- **Temporary shell pieces:**
  - `FoundationPage`, a temporary home screen.
  - `loginLocation` pointing to home.
  - `ApiEndpoints`, which contains only `refreshToken`, marked `ASSUMPTION(api)`.
- **Mock mode:** documented but not implemented (see section 4).
- **Crash reporter:** no provider chosen yet.
- **Release blockers already documented in `RELEASE.md`:**
  - The application ID is still `com.example.englizia`.
  - The localized iOS display name (`InfoPlist.strings`) isn't set.
  - Icons and splash screen are still the Flutter defaults.
- **Not exercised yet:**
  - Number and date formatting. "Latin digits" is only a decision so far.
  - Plurals: `.plural()` is never used.

---

## 7. Correctly implemented areas (do not change)

- **Layers:**
  - `core` doesn't import `app` or `features`, and a test enforces it.
  - `sl<>()` is used only in `app/app.dart` and `main.dart`.
- **Error funnel:**
  - `ApiClient` converts Dio errors once.
  - `guard` maps once.
  - `Failure` is sealed and free of localization.
  - Every failure type has a translated message.
  - The raw server message is never shown to the user.
- **Session:**
  - One shared refresh for concurrent requests.
  - One retry per request.
  - Going offline keeps the session.
  - The Keychain is cleared on a fresh install.
  - Test coverage is 95% for `auth_interceptor.dart` and 85% for `app_session_controller.dart`.
- **Security:**
  - Tokens are kept in `flutter_secure_storage`, and their `toString` is hidden (`auth_tokens.dart:14`).
  - Logging is redacted and debug-only.
  - `allowBackup=false`.
  - Nothing sensitive goes into `SharedPreferences`.
- **Localization:**
  - Full parity between the files (26 keys each).
  - No `startLocale`, with Arabic as the fallback, as decided in ADR 4.
  - `Accept-Language` follows the UI language, tested end to end.
- **RTL:** every layout call is directional, and a test rejects physical left/right APIs.
- **Design:**
  - Colors come from the identity doc, are pinned in a test, and have WCAG contrast checked in both modes.
  - Motion comes from `AppMotion`, with reduced-motion support.
  - The Android page transition is custom; iOS keeps its native transition.
- **Startup:**
  - `AppConfig.validate()` fails fast.
  - The global error handlers are installed before `runApp`.

---

## 8. Minimal remediation plan

**P0 (critical):** none.

**P1:**
1. **Refresh error classification.** Files: `core/network/auth_interceptor.dart` and its test. Only 400/401/403 sign the user out; a 5xx keeps the session. Outcome: no mass sign-out when the server has a brief outage.
2. **Crash reporter.** Choose a provider and wire it into `AppLogger.reporter`, redacting before sending. Needs a decision on the provider. Required before the first tester build.

**P2:**

3. **Mock mode wording.** `CLAUDE.md:18`: reword "Run (no backend)" to "reserved for fixture data sources (not implemented)", or implement mock mode with the first feature.
4. **New tests:**
   - `AppButton`: loading disables the button, the icon, `expand`.
   - `AppStateView`: retry callback, semantics.
   - `FailureL10n`: one translation key per failure type.
   - `SecureTokenStorage`: cache, failed read, failed write.
   - A dark-mode run in `app_test`.
5. **Hardcoded-text scan.** `localization_test.dart`: extend the scan to `tooltip:`, `hintText:`, `labelText:`, `semanticsLabel:` and `message:`.
6. **Token storage failures.** `secure_token_storage.dart`: report a write failure to the caller, and allow a re-read if the first read failed.
7. **Deep links during bootstrap.** `app_redirect.dart`: keep the intended route while the session loads. Due before notifications and deep links (v1.0).
8. **`.gitignore`:** add `graphify-out/`.
9. **Merge method.** `CONTRIBUTING.md`: align the documented merge method with the one actually used.

**P3 (optional):**

10. Clarify the "Register interfaces" rule wording in `CLAUDE.md`.
11. Move the numbers in `app_button.dart` into `AppSizes`.
12. Delete or keep the unused `ApiStatusCodes` constants.
13. Add `google_fonts` to the README.
14. Refine `readBool` and `normalizeField` once the .NET contract arrives.
15. Dependabot: `go_router 18` and `google_fonts 9` are major versions. Review each one separately.

**Decisions needed (not violations):**
- **Text-style approach.** The general standard (`AppColors`, `f16W400Black`, no `height`/`letterSpacing`) versus the approach this project adopted: role-based styles with line heights from the identity doc (ADR 5, `CLAUDE.md`). The standard says "when present", and it isn't present in this project, so this wasn't counted as a violation. Confirm which approach is authoritative.
- **Text size on small phones.** `.sp` shrinks text on small phones, which works against readability, especially for kids.

---

## 9. Verification results

| Command | Result |
|---|---|
| `flutter --version` | 3.41.6 stable |
| `dart format --output=none --set-exit-if-changed .` | 71 files, 0 changed, exit 0 |
| `flutter analyze --fatal-infos` | No issues, exit 0 |
| `flutter test --coverage` | 99 tests, all passed, exit 0 |
| Coverage (`lcov`) | 78.4% (589/751 lines) across 37 files |
| `flutter pub outdated` | Two major versions available: `go_router 18.0.2`, `google_fonts 9.0.0` |

**Coverage detail:**
- Lowest files: `app_semantic_colors` 8%, `secure_token_storage` 35%, `redacting_log_interceptor` 49%.
- Not loaded by any test: `app_button`, `app_state_view`, `failure_l10n`, `main`.

**Not run:**
- No device test or integration test exists.
- No iOS build (no Mac available).
- The CI result on `main` wasn't re-checked during this audit.

---

## 10. Final verdict: MOSTLY COMPLIANT (foundation only)

**What exists follows the standards,** backed by automated tests rather than documentation alone:
- Layer boundaries: `architecture_test`.
- The error funnel.
- Translations and RTL: `localization_test` and the directional rule.
- Theme tokens: `theme_test`.

**It isn't fully compliant, because of:**
- A real bug in refresh error classification (`auth_interceptor.dart:99-103`).
- No release diagnostics.
- Test gaps in files that will carry features: `AppStateView`, `FailureL10n`, `SecureTokenStorage`.
- One doc overstatement about mock mode.

**What couldn't be judged yet:** most of the standards (Cubit states, repositories, API contracts, preventing duplicate requests) need a feature to exist. The first audit after a feature is the real test.

No corrections have been applied. The P1 and P2 items above are waiting for approval.
