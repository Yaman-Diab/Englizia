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
│   └── shell/         SplashPage; FoundationPage (the dev page at /dev: theme, language, the account card, the mocks' scenarios; mock entry: a long press on home's top bar); TabShell, KidTabShell (the tabs' bars); PendingPage (placeholder routes, STATUS D-031)
├── core/              shared kernel — imports nothing from app/ or features/
│   ├── config/        AppConfig (APP_ENV, BASE_URL from --dart-define-from-file)
│   ├── result/        Result<T> (Ok/Err) · guard()
│   ├── usecase/       UseCase<T, P> · NoParams
│   ├── error/         Failure (sealed) · FailureMapper
│   ├── l10n/          AppLocales · CurrentLanguage · FailureL10n (failure → translated text)
│   ├── logging/       AppLogger · Redactor · CrashReporter (no-op until a provider is chosen)
│   ├── network/       ApiClient · ApiException (server envelope) · NetworkException · TokenResponse · interceptors · DioFactory · JsonReader
│   ├── session/       AuthTokens · AppSessionController (GoRouter refreshListenable)
│   ├── storage/       TokenStorage (secure; says whether a write reached the phone) · SettingsStorageService (SharedPreferences, non-sensitive)
│   ├── router/        RoutePolicy · AppRedirect
│   ├── settings/      SettingsCubit (theme mode)
│   ├── design_system/ palette · semantic colors · text styles · spacing · theme · widgets
│   └── di/            sl · setupCoreDependencies
└── features/<feature>/ domain · data · presentation
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

- Starting or ending a session clears what belongs to the account in `SettingsStorageService` (`clearAccountData`: the saved placement status, lessons, banks, units, profile and home), as the next account may be another's. A guest's upgrade is the same account, so `upgrade` keeps it all, and signing out first gives features the chance to send what they kept (`onLeaving`).
- `AppSessionController` status: `unknown → signedOut | guest | member` (ADR 10). Tokens carry their `AccountKind`, kept through refresh and secure storage. `bootstrap()` never throws; on first launch after install it clears the keystore (iOS keeps Keychain items after uninstall).
- `AuthInterceptor` attaches the bearer token, shares **one** refresh among concurrent 401s, retries each request once, and expires the session only when the server rejects the refresh token (offline keeps the session).
- `TokenRefreshService` uses a separate Dio without the auth interceptor and sets `Authorization` itself.
- Public endpoints set `extra[AuthInterceptor.skipAuthKey] = true`.

## Routing

- `route_policies.dart` maps each route pattern to `public`, `signedOutOnly` (welcome, onboarding), `withoutAccount` (sign-in, sign-up; open to guests) or `requiresSession` (the app; guests and members); unlisted routes need a session.
- `AppRedirect`: splash until the session is known (a public route does not wait, so a link that opened it is kept), then guests and members go home and signed-out users to the welcome screen; after that the policy decides. The router listens to the session, so creating a guest account, signing in or out re-routes automatically.
- Links from outside arrive through Flutter's own deep linking, with no package: `AndroidManifest.xml` declares them and go_router takes the URL. The recovery link is the one route that reads its arguments from the URL (`token`, `email`), because the email is the only way in; every other sensitive argument goes in `extra`. Saving there starts the session the server returned, then goes to "password changed", which replaces the recovery screens on the stack.
- A new account (guest or member) is not started by the screen that creates it: its session is handed to "preparing" (or, on the child path, the kids' welcome) as `PreparingArgs` in route `extra`, which starts it. That route is `public`, so it stays open when the session starts; the router's refresh drops `extra`, so the router keeps the arguments in memory until the learner leaves preparing.
- The guard checks the route at the bottom of the stack, not one pushed over it: a pushed screen whose session changes navigates itself (a guest's upgrade from sign-up goes home).
- Tabs (Learn / Practice / Speak / Me; kids: Learn / My words / Me) are plain routes: each builds its bar around its page (`TabShell`, `KidTabShell`), so a tab starts afresh when chosen. A `StatefulShellRoute` is the owner's call (STATUS D-084). Learn is home (`/`), which picks the kids' bar for a child's track.

## Design system

- Tokens from "الهوية البصرية v2": `context.colors` (`AppSemanticColors`) with a `ToneColors` triple per role — `fill` (icons, borders, progress), `text` (≥4.5:1), `surface` (light background) — plus neutrals and reader tokens (karaoke highlight, sentence band, tappable underline, selected word, captions).
- `context.texts` (`AppTextStyles`): display 28/34, title 22/30, reading 20/36, body 16/26, caption 13/20 (+ `captionStrong`), button 16; weights 400/600; Arabic running text ≥ 1.7 line height (`runningMinHeight`). Sizes use `.sp` (design size 375×812). A design's own size and line go through `texts.sized(role, size:, line:)`, which keeps that floor for running text and the design's line for a single one; `sizedFor` gives a box the design sizes its line until the text wraps.
- `context.scheme` for Material widgets; component themes are set in `AppTheme` so widgets don't repeat overrides.
- **Waiting looks the same everywhere:** `AppSpinner` (a faint ring with a turning quarter arc, from the account designs) is the only progress mark. A busy button is `AppButton(isLoading: true)`: it keeps its size and full color, takes no taps, and its label crossfades into the spinner in the label's color; a button built another way wraps its label in `ButtonLoadingLabel`. Pages and sections wait with `AppStateView.loading()`. No `CircularProgressIndicator`, no "loading…" text in buttons.
- `NoticeCard` is the one card for something to know (information, success, error or primary tone), read out as soon as it appears; `emphasis` stresses a part of its title, `trailing` adds an action.
- `SuccessBadge` (a circle that grows, a check that draws itself) and `HopOnce` make a quiet success, wherever one is needed.
- Forms use `AppTextField` (label above, icon, focus halo, a `FieldMessage` under it with a mark per tone, `Shake` when a send is refused). A failed action shows `showFailureSnackBar` (error band, retry), which keeps what was typed.
- `design_system/icons/` — `AppIcon` / `AppIconView`: the designs' own line icons as SVG (via `flutter_svg`, flutter.dev, 160/160 points); Material icons stay for generic controls. An icon is added when its screen is built.
- `core/network/connectivity_service.dart` — `ConnectivityService` (online now, changes): connectivity_plus behind an interface; tests use `FakeConnectivityService`.
- `core/mail/` — `MailApp`: opens the phone's mail app through a small native channel (`MainActivity.kt`, `AppDelegate.swift`).
- `core/audio/` — `ClipPlayer`, which plays a clip from the server and reports a failure (`JustAudioClipPlayer` on `just_audio`; in mock mode `MockClips` names the bundled spoken file for each mock link, STATUS D-050); `AppSound` and `soundCatalog` (each effect's file, kids' file and volume, in one place), the `SoundPlayer` interface with `AssetSoundPlayer` on `JustAudioBackend` (`just_audio`, `audio_session`; ADR 9), `playSound` and `SoundOnShow` for a widget, and `DeviceVolume` (whether the phone is muted: `PlatformDeviceVolume` on `volume_controller`, never failing its caller; STATUS D-046).
- `core/security/` — `ScreenProtection` (`PlatformScreenProtection`: `FLAG_SECURE` on Android, the screen's capture on iOS, through small native channels) and `ProtectedVideo`, which a lesson's player sits in: no screenshot or recording on Android, a cover and a pause while the screen is recorded on iOS (ADR 18).
- `motion/` — `AppMotion` (`app_motion.dart`), page transitions, `Entrance` and the entrance choreography (ADR 7), `SlideSwap`, which moves between the steps of a flow on one screen, and `WhenSeen`, which holds a one-shot motion back until a third of its child is inside the scroll view, so a page that builds its whole length at once doesn't play its motion below the fold. `AppMotion`: durations, curves, distances and scales for every animation (adapted from transitions.dev, no blur). `AppMotion.resolve(context, duration)` returns zero when the platform disables animations; decorative motion checks `AppMotion.reduceMotion(context)`.
- Page transitions come from `AppTheme.pageTransitionsTheme`: Android `AppPageTransitionsBuilder` (fade + 30px slide from the end side, 250ms, in place under reduce motion); iOS/macOS keep the native Cupertino transition with edge-swipe back. A tab switch and a session's entry play it too, as neither has a transition designed of its own (STATUS D-084); only «تابع» on home adds an overlay before it (STATUS D-099).
- `test/core/design_system/theme_test.dart` pins identity values and checks WCAG contrast in light and dark.
- Fonts: Readex Pro (UI, Arabic + Latin) and Andika (kids) through `google_fonts`, loaded from bundled files in `assets/fonts/` (runtime fetching off). Each weight is its own family, so weights come from roles (`bodyStrong`, `captionStrong`), never `copyWith(fontWeight:)`.

Pieces shared by the placement test and the exercises live in core: `ClipPlayback` (one clip at a time, on `ClipPlayer`), `BlankSentence`, `ClipFailedView`, `ClipProgressRing`, `ListeningWaves`, and `ChoiceSurface`/`ChoiceCheck`, which also carry the marks of a checked answer (`ChoiceMark`).

## Exercises

ADR 11. `ExerciseCubit` runs a lesson's session and knows no template's details: a body reports an `ExerciseDraft`, `evaluate` (pure, in domain) gives an `Evaluation`, and an `ExerciseAttempt` is kept on the phone and sent. `exerciseBody` is one exhaustive `switch` on the sealed `Exercise`; bodies take `BodyAnswer` and `BodyClip` and don't read the cubit. What only draws a question stays in its body (the active blank, the picked card). `ChipStage` flies word cards, sentences and letters between their places. Speech has its own `MicCubit` over `SpeechListener` and `MicPermission` in `core/audio` (ADR 13), shown by `MicBlock`. After checking, `FeedbackSheet` takes the check button's place in the same page, drawn from the `Evaluation` and from `feedback_content.dart`, which says what the right answer is for each template. Offline (ADR 12): the repository keeps the last lessons and the answers in preferences, a lesson in progress carries on with its version, and `AnswersSync`, started by `App`, sends what waits. A text's questions are flattened into steps at parsing; `Exercise.stayKey` keeps what they share on screen, and `exercisePinned` gives the page what stays over the scrolling question. Speaking an answer is the one template judged only by the server: the cubit sends it through `reviewSpoken`, shows `ReviewPending`, and an answer it couldn't judge goes to the outbox. A grammar lesson's content comes with the lesson (`Lesson.grammar`), so it opens offline with the rule. `GrammarLessonCubit` commands a `VideoEngine` (ADR 15) and follows its snapshots, counting watched seconds in `WatchProgress`, which ignores seeking. Questions to the teacher have their own cubit and repository, and are private (ADR 14). The reader (`presentation/reader`, S §8.2) takes `Lesson.reader`: the sound or video leads, reporting through `VideoEngine`, and the page's frames carry the time on between reports (`ReaderCubit.tick`, driven by `ReaderClock`), so the cubit has no timers and the word marked follows closely; each sentence selects only its own values, so only the current one redraws. `InteractiveTextCubit` and `InteractiveVideoCubit` extend `ReaderCubit` with what differs: where the media comes from and what completes the lesson. A lesson's player is `LessonPlayer` (`presentation/video`), which only knows `PlayerState` and `PlayerActions`, and `WatchKeeper` counts and keeps the watching for it. A vocabulary lesson (`presentation/vocabulary`, S §8.5) takes `Lesson.vocabulary`: `VocabLessonCubit` says each card's word through `ClipPlayback` and reports how long each sound lasts, and the cards mark what is said by that length, so the cubit keeps no clock; `VocabDeck` owns the cards' flight and dragging, which are only the screen's. «تدرّب» is its own feature (`features/practice`, S §10). `PracticeRepositoryImpl` keeps the bank on the phone and an outbox of answers and deletions, so the tab and a review work offline; `review_schedule.dart` (domain) moves a word through the five boxes the way the server does, until the server's next answer replaces it. The tabs' bar is `app/shell/tab_shell.dart`, as the app composes the tabs. Concepts to strengthen live in the lessons feature (`presentation/concepts`, S §11), as a session shows the lessons' own question bodies and feedback; `ConceptSessionCubit` keeps only what a single question needs. Both banks keep their changes in a `SendQueue` (`core/storage`), which sends them in order and drops one the server refuses for good. «أنا» is its own feature (`features/me`, S §19.1): `ProfileRepository` keeps the last profile on the phone; `MeCubit` renames, switches the active track and the grade (through `TrackRepository` for the lists), and holds the kids' parent gate. The page takes what it leads to as `MeActions`, so the account's email sheet and signing out stay in `features/account` and the router joins them. The settings live there too (`me/presentation/settings`): `PreferencesCubit` saves the account's preferences as they change, asks the phone before notifications go on, and keeps the video's quality through `LessonRepository`; the appearance, sound effects and vibration are the core `SettingsCubit`'s, and every vibration goes through `AppHaptics` so one switch silences them. Its sea is drawn by `SeaBand` and `IslandChain` (painters) in `SeaPalette`'s colors. «تحدّث» is its own feature (`features/talk`, S §8.6): `ConversationCubit` runs the intro, the turns and the summary, plays one line at a time through `ClipPlayback`, and moves to the learner's turn when the character's line ends or its voice fails. In an AI conversation the server does the AI, the tasks and the notes, and a resent turn keeps its id; a written one follows its `script` on the phone and sends the tasks done when it ends. A reply chosen from its card flies to its place through an overlay (`FlyIn`), so the list doesn't clip it. A kids' lesson (`lessons/presentation/kids`, S §13.2) reads `Lesson.kids`, whose question screens name the lesson's own `exercises`: `KidLessonCubit` plays the guide's lines through `ClipPlayback`, sends each question's first answer and completes the lesson as `ExerciseCubit` does, and counts a win the page answers with a star flying to the bar (`flyKidStar`, an overlay), which calls `landed` when it arrives. Its media screens (story, song, dialogue, «كرّر بعدي») are the same cubit's steps, kept in `kid_media_steps.dart` (a `part` of it): the story marks words by their timings, the song by the video's snapshots, and the microphone is the page's `MicCubit`, whose try the page reports with `listening` and `tried`. The kids' «كلماتي» belongs to the practice feature (`practice/presentation/kids`), on the same bank and `ReviewCubit`, under `KidTabShell`; what both kids' features draw (the bar, the star and its flight, the round buttons, pictures) is in `core/design_system/kids`. A unit's screen (`lessons/presentation/unit`, S §6.2) reads `UnitRepository` (the unit, kept for offline) and merges `LessonRepository.onPhone` into it: what is kept, a completion still waiting, where a lesson stopped. `UnitPlan` (domain) says which lesson is current and which are locked; back on top (`ModalRoute.isCurrentOf`), `UnitCubit.returned` reads it again, holds the chain while the lesson just done fills (`settling`), and the page lets it move on. «اشرح لي» (`lessons/presentation/explain`) is a sheet with its own small `ExplainCubit`, as interactive sheets have: a page builds an `ExplainRequest` from the question and the learner's draft, and the router opens the sheet with its cubit. `ExplainRepositoryImpl` keeps each explanation given and the day's count while the app runs. Shared with the lessons, in core: `MicCubit`, the microphone's permission sheet, `AiDots`, `SaidWord` and `heardWords` (`core/text`). Shadowing (`presentation/shadowing`, S §9) practises `Lesson.reader`'s chosen sentences: `ShadowingCubit` plays each one's part of the sound or video through `VideoEngine` and judges what `MicCubit` heard with `heardWords`; the page joins the two, as the microphone stays its own cubit. A lesson's end is its own small flow: `ExerciseCubit.summary` is what the phone counted, carried to `LessonCompleteCubit` by route `extra`, which asks the repository for the official numbers; the answers go first, and a completion that can't go waits in the same outbox. Pieces other screens will want are in core: `CountUp` and `RollingNumber` in motion, `XpAmount` (every place that shows points), `GoalRing` and `StreakFlame`. A press that skips an arrival sets `disableAnimations` for the subtree, so a piece only ever has to know how to be simply there. Sizes ease through `SmoothSize`, never `AnimatedSize` directly (enforced by test), as it dirties itself during layout when reduce motion gives it no time. To add a template: a subclass in `domain/entities/exercise.dart`, a case in `LessonModel`, a body and its case in `exerciseBody`, and a draft and evaluation if it answers in a new way.

## Home

ADR 17. «تعلّم» is its own feature (`features/home`, S §6.1). `HomeRepository` keeps the last home on the phone, so it opens at once and offline; `HomeCubit` shows it, merges `LessonRepository.onPhone` into the current unit, keeps a clock for the greeting and the day's end (a new day starts on the phone at the day start, `HomeRules.asOf`, then asks the server), and when a page over it closes asks the server and compares home as it was drawn with the day after (`HomeRules.diff`, pure, in domain) into a `HomeMoment`: one return at a time, waiting 2 s for the server before trusting the phone, its later answer shown without a moment. A first open, with nothing kept, names the track for the capsule from the profile. The page learns of pages through the router's `RouteObserver` of page routes (`RouteAware`), so closing a sheet or a dialog isn't a return, and while a page covers home a refresh keeps its answer for the return instead of redrawing. `HomeRules` also holds the product rules: the greeting, the status, the streak at risk, which notice wins the header's slots, the page search. The page (`presentation/home`) is a stage: a `CustomScrollView` of the map under a day header and a level header that float over it, moved by `StageController`. The map's geometry is pure and computed in the design's right-to-left space (`geometry/`: `IslandLayout`, `MapLayout`, `MapAnchor`), scaled by `MapFrame` and mirrored in English; the sea, the islands, the bridges, the fog and the waves are painters (`paint/`): the islands' art is recorded once per state and kept, and the other layers sit behind a `RepaintBoundary` and repaint only when their inputs change. Every motion is a timeline in `HomeChoreographer` (`motion/`) that writes `MapOverrides` and `HeaderOverrides`, which the map, the header and the bubble read instead of the data while it plays; flights and sparks draw in `FlightLayer`, and `LoopBudget` keeps at most three ambient loops running. The page takes what it opens as `HomeActions`, so the router joins it to the lessons, the unit, the review, «أنا», the tracks sheet and the dev page. In mock mode `HomeFakeDataSource` acts as the server on the bundled homes, and the dev page sets its scenario through `HomeMockControls`, the interface it is registered as.

## Localization

- easy_localization, `assets/translations/{ar,en}.json`, flat snake_case keys prefixed by feature.
- Device language decides at first launch; Arabic is the fallback. The onboarding language step sets it explicitly.
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
