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
Requirement references are sections of `docs/product/student-app-requirements.md` (**v3.0, 2026-10-22**, the version everything is built on; "S" = student doc, "SV" = `dashboard-server-requirements.md`). Designs are a visual reference only; where they differ, the documents win (student §27).

v0.1 target date: **2026-11-05**; v0.2 2026-11-26; v0.3 2026-12-17; v0.4 2027-01-07; v0.5 2027-01-28; v1.0 2027-02-15 (S §23).

| Feature / screen | Requirement | Version | Status | Data | Notes |
|---|---|---|---|---|---|
| App foundation (DI, router, session, theme, i18n, network, tests) | — | — | done | — | `FoundationPage` is a temporary home screen |
| Guide character «بلبل» (`core/design_system/mascot/`) | S §22 | v0.1 | done | — | 12 expressions, key, headphones, light/dark, idle loop; AI variant deferred (D-025) |
| Splash and forced update | S §4.1, §21; SV §19.2 | v0.1 | planned | — | Minimum version comes from the server |
| Welcome screen | S §4.2 | v0.1 | done | — | Design `Welcome Screen v2`; guests land here after the splash. Buttons open placeholders (D-031) |
| Onboarding: language step | S §4.2 | v0.1 | done | — | Design `Language Screen` on the shared `Onboarding Question` template (`OnboardingQuestionScaffold`, `OnboardingOption`). Progress counts the learner's actual path (`onboardingStepsFor`) |
| Onboarding: who will learn | S §4.2, §3.1 | v0.1 | done | mock | Options come from the published tracks' "suggested for" setting (`GET /api/v1/tracks`); an audience without a track is «قريبًا». Avatars are a proposal (D-032) |
| Onboarding: grade, why, save progress, preparing | S §4.2–4.5 | v0.1 | planned | — | No guest mode: creating the account ends onboarding. Goal, challenge, level and reminder steps arrive in v0.2/v1.0; the child path in v0.5 |
| Account: email + Google sign-in, password recovery, sign-out | S §4.3, §5.1–5.2; SV §19.8 | v0.1 | planned | — | Apple on iOS, email confirmation, account deletion are v1.0 |
| Home (basic) and track switching | S §6.1, §3.2 | v0.1 | planned | — | Replaces `FoundationPage` |
| Unit screen | S §6.2 | v0.1 | planned | — | |
| "Me" tab and basic settings | S §19 | v0.1 | planned | — | Support section is v1.0 |
| Lessons, exercises, readers, vocabulary, practice, conversation, kids mode, motivation, notifications | S §7–§20 | v0.2–v1.0 | not started | — | Read the matching sections before building (D-027) |

---

## Deferred

| ID | Item | Why deferred | Blocked by | Revisit when | Since |
|---|---|---|---|---|---|
| D-001 | Final application ID (now `com.example.englizia`) | Owner has not chosen it | Owner decision | **Before Google sign-in work in v0.1**: Google OAuth clients are bound to the application ID and signing SHA-1, and the ID cannot change after store upload (`RELEASE.md`) | 2026-10-11 |
| D-002 | Crash reporter provider wired into `AppLogger.reporter` (now a no-op) | Provider not chosen; must work for users in Syria | Owner decision | Before the first tester build | 2026-10-11 |
| D-003 | Real `BASE_URL` in `env/*.json` (placeholders now) | Backend not deployed | Backend team | When the first endpoint is connected | 2026-10-11 |
| D-004 | .NET API contract: every field is an `ASSUMPTION(api)`; the unified `{data, meta, error}` envelope is proposed, not agreed. The backend must deliver an OpenAPI document with each release (SV §19.1) and none has arrived | Contract not shared | Backend team | When the v0.1 OpenAPI arrives: reconcile `docs/api`, fakes and fixtures; questions in `docs/api/README.md` | 2026-10-25 |
| D-005 | Mock mode (`env/mock.json`): fake data sources read the contract examples bundled in `assets/mock/<feature>/` (the tests parse the same files). Endpoints on mock data: `GET /api/v1/tracks`, `GET /api/v1/tracks/{trackId}/levels`. Not yet verified that a release build drops the fake classes | Backend not ready | Backend team | Per endpoint: when it is live, check the real response against the contract, save it in `test/fixtures/api/`, delete its mock asset and fake data source. Verify tree-shaking with the first release build | 2026-10-25 |
| D-006 | Flutter stays on 3.41.6; go_router 18 and google_fonts 9 are ignored in Dependabot | Upgrade deferred by the owner; both need a newer SDK | Owner decision | When the SDK pin moves: remove the Dependabot ignores and re-verify the page-transition assumptions (ADR 7) | 2026-10-25 |
| D-007 | Android predictive-back peek (custom page transition does not provide it); manifest flag `enableOnBackInvokedCallback` is not set | Trade-off accepted in ADR 7 | An Android 16 device | First test on an Android 14+/16 device | 2026-10-12 |
| D-008 | iOS checks: localized home-screen name (`InfoPlist.strings`), permission strings, and that iOS "Reduce Motion" reaches `disableAnimations` | No Mac available | A Mac | First iOS build (do one early, `RELEASE.md`) | 2026-10-12 |
| D-009 | App icon, splash and logo are still placeholders: Flutter's default icon and splash, and an "E" in a circle as the logo mark on the welcome screen (`app_logo_mark`, `ASSUMPTION(design)`; the designs use "A") | Final artwork not approved (S §26) | Owner / designer | Before the first tester build; the store upload needs the final logo and icon | 2026-10-11 |
| D-010 | `linux/`, `macos/`, `web/`, `windows/` folders kept although only Android and iOS ship | Owner has not decided | Owner decision | Before the first store build | 2026-10-11 |
| D-011 | Provisional palette values: light text tokens, most status surfaces, and the dark streak/reward/AI/info values (`ASSUMPTION(design)`); four doc fills sit under 3:1 on white (success, streak, reward, info). Dark neutrals, primary text, error and success now follow the designs' token table (ADR 5). The table's **light** column (e.g. BACKGROUND `#F7F9FC`, TEXT_PRIMARY `#0F1A2A`, SUCCESS `#1F8A4C`) differs from identity 1.0 and is not adopted, by the owner's decision | Identity token block still incomplete | Owner / designer | When the identity token block is completed: reconcile both columns, then drop the `ASSUMPTION(design)` tags | 2026-10-12 |
| D-012 | Text style approach: owner's general standard (`f16W400Black`, no `height`) vs the role-based styles adopted in ADR 5 | Not confirmed which is authoritative | Owner decision | Before the first screen is styled further | 2026-10-13 |
| D-013 | `.sp` with `minTextAdapt` shrinks text on small phones (16 → ~13.7 at 320dp) on top of the 0.9–1.3 text-scale clamp | Accessibility trade-off inherited from the playbook | Owner decision | Before kids mode (v0.5) at the latest | 2026-10-13 |
| D-014 | Tests for `AppButton`, `AppStateView`, `FailureL10n`, `SecureTokenStorage`, and a dark-mode widget test | Audit P2 | Owner approval | With the first screen that uses them | 2026-10-13 |
| D-015 | Hardcoded-text scan only covers `Text('…')`; extend to `tooltip:`, `hintText:`, `labelText:`, `semanticsLabel:`, `message:` | Audit P2 | Owner approval | Before the first form screen | 2026-10-13 |
| D-016 | `SecureTokenStorage`: report a failed write to the caller; allow re-read after a failed read | Audit P2 | Owner approval | Before the login feature is connected | 2026-10-13 |
| D-017 | `AppRedirect` forgets the intended route while the session loads | Audit P2; no deep links yet | v1.0 notifications | Before notifications / deep links | 2026-10-13 |
| D-019 | `.gitignore` lacks `graphify-out/` | Audit P3 | Owner approval | Next housekeeping commit | 2026-10-13 |
| D-020 | `CONTRIBUTING.md` says squash-merge; practice has been merge commits | Audit P2 | Owner decision | Next docs pass | 2026-10-13 |
| D-021 | Open product decisions (S §26, SV §26): video streaming service, speech-to-text (default on-device), chat AI provider, listening count in the placement test; all must work in Syria | Open in the requirements | Owner / backend | v0.2 (video), v0.4 (speech), v0.5 (AI) | 2026-10-11 |
| D-022 | Written permission from the Emar series rights holder | S §26 (owner responsibility) | Owner | Before publishing the Emar track | 2026-10-11 |
| D-023 | App name: the v3.0 documents say "Englizia" (S §22, §27) but the app was renamed **Engleazia** on 2026-10-25 | Owner changed the name after the documents were issued | Owner | Confirm the final spelling and update documents and designs before the store listing | 2026-10-25 |
| D-024 | Password-reset links must open the app: Android App Links and iOS Universal Links need a real domain, `assetlinks.json` and an apple-app-site-association file (S §5.2) | No domain yet | Owner / backend | Before the recovery flow (v0.1) | 2026-10-25 |
| D-025 | Guide character, remaining parts: the AI variant and its five expressions (`ai-think`, `ai-idea`, `ai-magic`, `ai-translate`, `ai-voice`), the silhouette mode, animated bubble contents, and the hand-size morph during a pose change. Built: 12 expressions, key, headphones, dark rim, idle loop, head framing (ADR 8) | Not needed by v0.1 screens | AI features (v0.5) | When the first AI screen is built; the data is in the design file `Guide.dc.html` | 2026-10-25 |
| D-032 | The "who will learn" avatars are the guide in a head framing with glasses / a beanie / a graduation cap (`MascotProp`, `ASSUMPTION(design)`), proposed by the agent to replace the designs' human faces, which the owner rejected | Not in the approved designs | Owner / designer | Owner approves or the designer draws final versions; swapping them is a change in the avatar list of the audience step | 2026-10-26 |
| D-026 | Local storage for cached home/lessons and queued answers with stable attempt ids (S §7.1, §21); technology not chosen. v0.1 only needs onboarding answers kept on the phone until the account exists (S §4.3) | Needed from v0.2 | Decision | Before v0.2 (choose and record in an ADR) | 2026-10-25 |
| D-027 | Requirements coverage: read so far — S §1–8.5 and §21–27; SV §19, §20.1, §23–27 and the table of contents. **Not yet read:** S §8.6–§20 and SV §1–18, §20.2–§22 | Large documents; read per feature | — | Read the matching sections before building each feature, then update this row | 2026-10-25 |
| D-028 | S §22 asks for fixed-width numbers and directional isolation of mixed Arabic/English text; neither exists in `AppTextStyles` or the widgets yet | New requirement | — | Before the first screen with numbers or mixed text | 2026-10-25 |
| D-029 | Agent tooling installed at user scope on 2026-10-26: `dart-flutter` 1.0.7 (official skills + Dart MCP server, works with Dart 3.11.4) and `ui-ux-pro-max` 2.15.0 (reference only, see CLAUDE.md); `dart-lang/skills` skipped as a duplicate. GitHub clones kept failing on the slow connection, so `ui-ux-pro-max` is registered from a local shallow clone (`~/.claude/plugins/local-src/ui-ux-pro-max-skill`) and does **not** auto-update | Slow connection | — | To update it: `git -C ~/.claude/plugins/local-src/ui-ux-pro-max-skill pull`, then `claude plugin marketplace update ui-ux-pro-max-skill`. Confirm the skills appear after the next session restart | 2026-10-25 |
| D-031 | Placeholder routes (`PendingPage`): `/onboarding/grade`, `/onboarding/reason` and `/onboarding/save-progress` after "who will learn", and `/sign-in` from welcome | Those screens are not built | The next onboarding steps and the account feature (v0.1) | Replace each placeholder route with the real screen; delete `PendingPage` when none is left | 2026-10-26 |
| D-033 | Onboarding answers (audience so far) live only in screen state; S §4.3 needs them kept on the phone until the account is created and sent with it | Storage for the onboarding draft not built | Save-progress step (v0.1) | With the save-progress step: an onboarding draft persisted locally (see D-026) | 2026-10-26 |
| D-034 | When several published tracks share one audience, the learner must choose between them (S §3.1, SV §5.2); the app now treats them as one choice | No design for that screen | Designer, or build it from existing components (S §27) | Before a second track gets the same "suggested for" value | 2026-10-26 |
| D-035 | The «قريبًا» badge is neutral (surface + secondary text) instead of the designs' amber, because amber is reserved for rewards (identity v2) | Rule conflict in the designs | Owner / designer | Confirm or give the badge its own token | 2026-10-26 |
