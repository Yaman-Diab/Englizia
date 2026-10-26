# Project status

The single place that answers "what exists, what is fake, and what was postponed".
Read it at the start of a session; update it **in the same commit** as the change.

| Kind of information | Where it lives |
|---|---|
| State of each screen/feature, mock vs connected | **this file**, "Screens and features" |
| Anything skipped, stubbed or temporary, with the reason | **this file**, "Deferred" |
| Why a lasting decision was taken | `docs/adr/` |
| Backend request/response shapes and their status | `docs/api/` |
| User-visible changes over time | `CHANGELOG.md` |
| How a bug was found | commit / PR description |

Rules for this file:
- It describes the **current state**; finished items leave the Deferred table (git history keeps them).
- Every deferral has a reason and a **revisit trigger** (a version, an event, or a decision). "Later" is not a trigger.
- Anything faked for lack of a backend is a row here until its endpoint is connected and the mock data is deleted.

Rows D-014 to D-020 come from `docs/audits/2026-10-13-codebase-audit.md` (its P1 item, token-refresh classification, is already fixed).

Last full review: 2026-10-25.

---

## Screens and features

Status: `planned` · `in progress` · `done` · `blocked`. Data: `mock` (fake data source) · `connected` (real endpoint, unconfirmed) · `confirmed` (checked against a real response).
Requirement references point to `docs/product/student-app-requirements.md` (the newest requirements version is still to be added by the owner; screens built on it note which version they follow).

| Feature / screen | Requirement | Version | Status | Data | Notes |
|---|---|---|---|---|---|
| App foundation (DI, router, session, theme, i18n, network, tests) | — | — | done | — | `FoundationPage` is a temporary home screen |
| Registration and login | §4, §17 | v0.1 | planned | — | Google/email; Apple in v1.0 |
| "Who will learn" and track selection | §4 | v0.1 | planned | — | |
| Browse levels, units, lessons | §3, §5 | v0.1 | planned | — | First planned slice, on mock data |
| "Learn" and "Me" tabs | §5 | v0.1 | planned | — | Replaces `FoundationPage` |

---

## Deferred

| ID | Item | Why deferred | Blocked by | Revisit when | Since |
|---|---|---|---|---|---|
| D-001 | Final application ID (now `com.example.englizia`) | Owner has not chosen it | Owner decision | Before the first distributed build; cannot change after store upload (`RELEASE.md`) | 2026-10-11 |
| D-002 | Crash reporter provider wired into `AppLogger.reporter` (now a no-op) | Provider not chosen; must work for users in Syria | Owner decision | Before the first tester build | 2026-10-11 |
| D-003 | Real `BASE_URL` in `env/*.json` (placeholders now) | Backend not deployed | Backend team | When the first endpoint is connected | 2026-10-11 |
| D-004 | .NET API contract: every field is an `ASSUMPTION(api)`; the unified `{data, meta, error}` envelope is proposed, not agreed | Backend contract not shared | Backend team | Before connecting the first endpoint; questions listed in `docs/api/README.md` | 2026-10-25 |
| D-005 | Mock mode: `AppConfig.isMock` exists but nothing uses it | Built together with the first screen | First screen | With the first screen; delete mock data per endpoint once it is confirmed | 2026-10-25 |
| D-006 | Flutter stays on 3.41.6; go_router 18 and google_fonts 9 are ignored in Dependabot | Upgrade deferred by the owner; both need a newer SDK | Owner decision | When the SDK pin moves: remove the Dependabot ignores and re-verify the page-transition assumptions (ADR 7) | 2026-10-25 |
| D-007 | Android predictive-back peek (custom page transition does not provide it); manifest flag `enableOnBackInvokedCallback` is not set | Trade-off accepted in ADR 7 | An Android 16 device | First test on an Android 14+/16 device | 2026-10-12 |
| D-008 | iOS checks: localized home-screen name (`InfoPlist.strings`), permission strings, and that iOS "Reduce Motion" reaches `disableAnimations` | No Mac available | A Mac | First iOS build (do one early, `RELEASE.md`) | 2026-10-12 |
| D-009 | App icon and splash are still the Flutter defaults | No source artwork | Designer | Before the first tester build | 2026-10-11 |
| D-010 | `linux/`, `macos/`, `web/`, `windows/` folders kept although only Android and iOS ship | Owner has not decided | Owner decision | Before the first store build | 2026-10-11 |
| D-011 | Provisional palette values: text tokens, some status surfaces, most dark values (`ASSUMPTION(design)`); four doc fills sit under 3:1 on white (success, streak, reward, info) | Identity v2 token JSON was empty; the docs themselves keep those fills | Designer | When the original v2 token file arrives | 2026-10-12 |
| D-012 | Text style approach: owner's general standard (`f16W400Black`, no `height`) vs the role-based styles adopted in ADR 5 | Not confirmed which is authoritative | Owner decision | Before the first screen is styled further | 2026-10-13 |
| D-013 | `.sp` with `minTextAdapt` shrinks text on small phones (16 → ~13.7 at 320dp) on top of the 0.9–1.3 text-scale clamp | Accessibility trade-off inherited from the playbook | Owner decision | Before kids mode (v0.5) at the latest | 2026-10-13 |
| D-014 | Tests for `AppButton`, `AppStateView`, `FailureL10n`, `SecureTokenStorage`, and a dark-mode widget test | Audit P2 | Owner approval | With the first screen that uses them | 2026-10-13 |
| D-015 | Hardcoded-text scan only covers `Text('…')`; extend to `tooltip:`, `hintText:`, `labelText:`, `semanticsLabel:`, `message:` | Audit P2 | Owner approval | Before the first form screen | 2026-10-13 |
| D-016 | `SecureTokenStorage`: report a failed write to the caller; allow re-read after a failed read | Audit P2 | Owner approval | Before the login feature is connected | 2026-10-13 |
| D-017 | `AppRedirect` forgets the intended route while the session loads | Audit P2; no deep links yet | v1.0 notifications | Before notifications / deep links | 2026-10-13 |
| D-018 | `loginLocation` points to home until the auth feature adds a login route | No auth feature yet | Registration and login | With that feature | 2026-10-11 |
| D-019 | `.gitignore` lacks `graphify-out/` | Audit P3 | Owner approval | Next housekeeping commit | 2026-10-13 |
| D-020 | `CONTRIBUTING.md` says squash-merge; practice has been merge commits | Audit P2 | Owner decision | Next docs pass | 2026-10-13 |
| D-021 | Open product decisions: speech-to-text (on-device vs cloud), chat AI provider, video hosting (all must work in Syria) | Requirements §19 | Owner / backend | v0.2 (video), v0.4 (speech), v0.5 (AI) | 2026-10-11 |
| D-022 | Written permission from the Emar series rights holder | Requirements §14 | Owner | Before publishing the Emar track | 2026-10-11 |
