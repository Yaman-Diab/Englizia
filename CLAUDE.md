# Engleazia — Agent Guide

**What it is:** student app for learning English, Arabic-first (kids, general English A1–B2, and the Emar school curriculum), one engine for every track.
**Backend:** .NET REST API + control panel, built by a separate team. Contract notes in `docs/api/` (not shared yet — most fields are assumptions).
**Platforms:** Android + iOS. Languages: Arabic (default, RTL) + English.

> Loaded into every AI session — keep it under ~150 lines. Details are read **only when needed**:
> `docs/product/` (requirements, Arabic, source of truth) · `docs/PLAYBOOK.md` (conventions + templates) ·
> `docs/STATUS.md` (what exists, what is mock, what was postponed — **read at session start**) ·
> `docs/ARCHITECTURE.md` · `docs/api/` · `docs/adr/` · `CONTRIBUTING.md` · `CHANGELOG.md` · `RELEASE.md`.

---

## Commands

| Task | Command |
|---|---|
| Run (dev) | `flutter run --dart-define-from-file=env/dev.json` |
| Run (no backend) | `flutter run --dart-define-from-file=env/mock.json` |
| Test | `flutter test` |
| Analyze | `flutter analyze --fatal-infos` |
| Format | `dart format lib test` |
| Release | see `RELEASE.md` — never build a release without `env/prod.json` |

Flutter is pinned to the version in `.fvmrc` (prefix commands with `fvm` if FVM is installed). CI uses the same version.

---

## Architecture (full version: `docs/ARCHITECTURE.md`)

```
lib/
├── app/        composition root: App widget, router, DI root, temporary shell pages.
│               The ONLY folder allowed to import from features/.
├── core/       shared kernel. Never imports app/ or features/ (enforced by test).
└── features/<feature>/
    ├── <feature>_injection.dart
    ├── domain/        pure Dart: entities, repository contracts, use cases
    ├── data/          datasources (only place that knows endpoints), models, *RepositoryImpl
    └── presentation/<screen>/{cubit,pages,widgets}
```

Dependency direction: `presentation → domain ← data`.
`domain/` imports no `package:flutter`, no `package:dio`, nothing from `core/network`, nothing from another feature's `data/`.

**Product rules that shape code** (see `docs/product/student-app-requirements.md`):
- Tracks, levels, units and lessons come from the backend — **a new track must never need a code change**.
- Five lesson types (grammar video, interactive video, interactive text, vocabulary, conversation). Interactive text and video share **one reader component**.
- Kids mode is a setting of the same engine (bigger sizes, Andika font, audio instructions), not a separate app.
- Grading and XP are computed **on the server**; the app only submits attempts with a stable attempt id (safe to resend).
- Every configurable value (thresholds, limits, points, day start, texts the panel controls) is read from the server's effective settings after inheritance (global → track → level → lesson); **never hardcode one**. Doc: S §2 principle 6.
- No guest mode: creating the account ends onboarding; onboarding answers stay on the phone until then (S §4.3).

---

## Non-negotiables

| Rule | Detail |
|---|---|
| Cubit, not Bloc | Bloc only when event semantics are really needed (debounce, streams). |
| State carries its data | `final class XState extends Equatable` + `copyWith`. No marker classes. |
| No Flutter types in Cubits | Controllers/FocusNodes/FormKeys live in the page `State`. |
| `Result<T>` not exceptions | Repos/use cases return `Ok`/`Err` (`core/result`). Handle with `switch`. |
| One error funnel | `*RepositoryImpl` wraps calls in `guard()`; `FailureMapper` maps once; UI shows `failure.localizedMessage`. |
| Network only via `ApiClient` | Datasources never touch Dio errors; `ApiClient` throws `ApiException`/`NetworkException`. |
| Manual DI (GetIt) | Register interfaces, not impls. Cubits `factory`, everything else `lazySingleton`. |
| No raw colors / text styles | Only `context.colors`, `context.scheme`, `context.texts`, `AppSpacing`/`AppRadius`/`AppSizes`. Fonts via `google_fonts` from bundled assets; never `copyWith(fontWeight:)`, use a role. |
| Color meanings are fixed | `ai` (violet) only for AI features · `reward` (amber) = XP/stars/save star · `streak` only streak. State never by color alone: icon + text. |
| Motion from tokens | Durations and curves only from `AppMotion`; wrap durations in `AppMotion.resolve(context, …)`. Page transitions come from `AppTheme.pageTransitionsTheme`, never per route. No blur-heavy effects. |
| No hardcoded visible text | Every string via `'key'.tr()` with a **literal** key, in both `ar.json` and `en.json`. |
| Directional layout | `EdgeInsetsDirectional`, `AlignmentDirectional`; let `matchTextDirection` flip icons. |
| No `print` | Use `AppLogger`. Network logging is debug-only and redacts tokens/passwords/PII. |
| Environments via files | `--dart-define-from-file=env/<env>.json`. **Never edit source to switch backend.** |
| No invented contracts | Unconfirmed backend field → `// ASSUMPTION(api): ...` + entry in `docs/api/`. Same for design values: `ASSUMPTION(design)`. |
| No real personal data | Fixtures use `user@example.com`, fake IDs (`00000000000`), generic names. Kids' voice recordings are never stored. |
| Sensitive route args | Pass via `GoRouterState.extra`, never query params. |
| Access control | Route policies in `app/router/route_policies.dart` are the single source of truth; buttons may only *mirror* them. |

---

## Definition of Done (every change)

- [ ] `flutter analyze --fatal-infos` clean, `flutter test` green (incl. localization + architecture tests).
- [ ] New/changed strings exist in **both** translation files; plurals use `.plural()`.
- [ ] Data layer + Cubit of the change are tested; risky code (interceptors, parsing, guards) has tests.
- [ ] Checked at **320dp** width, **Arabic (RTL) + English**, **light + dark**.
- [ ] Docs touched by the change are updated **in the same commit** — as current state, not history.
- [ ] No `print`, no secrets, no real personal data, no environment edits in source.
- [ ] `docs/STATUS.md` updated: the feature's status/data row, and every skipped, stubbed or temporary item logged under Deferred with a reason and revisit trigger.
- [ ] Conventional Commit, one logical change per commit (`CONTRIBUTING.md`).

---

## Comment & doc policy

- Code comments state the **current why/constraint** in 1–3 lines. No bug stories, no status markers.
- How a bug was found → commit/PR description. A lasting decision → `docs/adr/NNNN-title.md`.
- Repo text (comments, test names, docs) in **English**; user-facing strings in `assets/translations/`; product docs stay Arabic.
- Never put volatile numbers (test count, key count) in docs — commands report them.

---

## Working agreements for the agent

- Read `docs/PLAYBOOK.md` before creating a new feature, a new core file, CI, or release config. Use `/new-feature`.
- Read the relevant section of `docs/product/` before building any screen; read `docs/api/` before touching a datasource or model.
- Before building a requested screen, list its parts tagged to a **later version** than the current target (requirements §4.2 tables, §23) and ask the owner per item: build now or defer. Build only what is approved; log the rest in `docs/STATUS.md`.
  Save every real response (sanitized) as `test/fixtures/api/<endpoint>_<case>.json` and parse it in a test.
- **Commit after each logical change, but never `git push` without asking the user first — every time.**
- Never rewrite history or change git config without an explicit request.
- New packages must be reputable: pub points near the max, many likes and downloads, a recent release, a verified publisher where possible, Android + iOS, and compatible with the Flutter pin. Show those numbers and the alternatives when proposing one; prefer a little code over a weak package.
- Pending decisions and postponed work live in `docs/STATUS.md` → Deferred; don't change them silently
  (e.g. application ID, kept platform folders, provisional palette, the Flutter 3.41.6 pin).
- Never leave something undone without a Deferred row. Fake/mock data is a Deferred row until its endpoint is connected, then the mock data is deleted.
- `ui-ux-pro-max` (design skill) is **reference only**: never override the identity tokens (`docs/product/visual-identity-*`) or the approved designs, and never take palettes, fonts or styles from it. Dart/Flutter skills from the `dart-flutter` plugin may be used for Dart and Flutter tasks.
- If a problem is wider than reported, say so with evidence (file:line, command output).
- Report results honestly: failing tests are reported with their output.
