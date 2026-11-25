# Backend API contract

Backend: **.NET** (ASP.NET Core) REST API, separate team. Per `docs/product/dashboard-server-requirements.md` §19.1 the backend delivers an **OpenAPI document with every release** (app and control panel share it), plus a JSON Schema for the lesson package with v0.1.

- **Dev server:** `https://api-dev.engleazia.com` (`env/dev.json`). Interactive docs at `/scalar/#app-api`, the document itself at `/openapi/app.json`.
- **[`openapi.json`](openapi.json)** is the committed copy of the dev server's App API document (`https://api-dev.engleazia.com/openapi/app.json`), never the Admin API's (`/openapi/admin.json`, the control panel's `/api/v1/admin/*`); replace it with every release and reconcile this folder, the fake data sources and the fixtures against it.
- Everything the document does not cover is an assumption, tagged in code as `// ASSUMPTION(api): ...` (`grep -rn "ASSUMPTION(api)" lib` lists them).
- Real responses are saved, sanitized, under `test/fixtures/api/<endpoint>_<case>.json` and parsed in tests (`test/helpers/api_fixtures.dart`).

## Conventions

| Topic | Contract | Status |
|---|---|---|
| JSON casing | camelCase | confirmed |
| Base path | Account endpoints under `/api/v1/auth/...`; everything the signed-in app reads under `/api/v1/app/...` (`/app/me`, `/app/system/ping`). The app's proposed endpoints follow the same split | confirmed (prefix) / proposed (new paths) |
| Envelope | Every response, success or failure, is `{statusCode, message, data, error, traceId}`; `ApiClient` unwraps `data` | confirmed |
| Errors | `error: {code, details}`, `details: [{field, code, message}]` or null. The app keys its behavior on `error.code` and shows its own Arabic text; `message` is only logged. Field names are normalized by the app (`$.Email` / `request.Email` / `Email` → `email`). ProblemDetails (RFC 9457) is still parsed as a fallback | confirmed |
| Error codes | Dotted lower-case: `validation.failed` (400, with `details` codes such as `not_empty`, `email`, `minimum_length`), `auth.unauthenticated` (401, no access token), `auth.refresh_token_invalid` (401 from refresh), `auth.invalid_credentials` (401 from login), `auth.reset_token_invalid` (400 for a recovery link expired, used, replaced or unknown) and `auth.email_link_invalid` (the same for the link that confirms an email), `auth.google_token_invalid` (401 from Google sign-in), `auth.email_taken` and `auth.external_login_conflict` (409), `auth.account_disabled` (403), `auth.current_password_invalid` (400 from the password change). The OpenAPI document now lists every endpoint's codes in its response descriptions; the app keys on these and reads the rest by status: `auth.locked_out` and `rate_limit.exceeded` (429 with `Retry-After`), `auth.token_expired` and `auth.token_invalid` (401, after which the app refreshes once), `auth.refresh_token_reused` (401 from refresh), `auth.password_not_set`, `auth.email_already_confirmed` and `auth.resend_too_soon`. Constants in `lib/core/network/api_error_codes.dart`; real answers in `test/fixtures/api/` | confirmed for the ones with a fixture; the rest are from the document |
| Auth | JWT Bearer access token with `expiresIn` seconds, plus a refresh token with `refreshTokenExpiresAt`, both in `TokenResponse`. The app refreshes 30 s before the access token expires and once more on a 401, sharing one refresh call; a 400/401/403 from refresh signs the user out | confirmed |
| Devices | Login and register take `deviceId` (null on the first login; the server returns one in `TokenResponse`, which the app keeps on the phone, through sign-outs, and sends back) and `platform` (`DevicePlatform`: `android`, `ios`, `web`; `lib/core/session/device_platform.dart`) | confirmed |
| User | `UserDto {id (uuid), userName, email?, displayName, emailVerified, roles[], authMethods[], timeZone, uiLanguage (ar\|en)}`, changed through `PUT /api/v1/app/me`. `authMethods` says how the account signs in; the app doesn't read it yet. `TokenResponse.isNewUser` says a sign-in made the account | confirmed |
| Rate limiting | Register and login document `429`; the app treats it as "wait and retry" and reads `Retry-After` in seconds when present | 429 confirmed, wait time not |
| Localization | The app sends `Accept-Language` (`ar` / `en`); `message` is English only and doesn't follow it. The app shows its own text by `error.code` | confirmed |
| App gate | The server returns the minimum allowed app version per platform (v0.1) and the recommended one (v1.0) (§19.2, required); no endpoint yet | required, not in the document |
| Effective settings | The server returns settings after inheritance (global → track → level → lesson); the app reads them on open and caches them; no setting is hardcoded in the app (§19.2, student §2 principle 6) | required, proposed in [settings.md](settings.md) |
| Times | A full ISO-8601 UTC instant with three decimals (`2026-11-23T12:13:59.529Z`), shown in the learner's time zone; a time of day is `HH:mm:ss`. The learner's day starts at midnight on their clock, with no setting | confirmed |

The server's rules for every response (the backend's answers of 2026-11-23, §3): enum values are snake_case (`school_student`, `interactive_video`, `picture_choice`, `quota_out`); a field with no value is written as `null`, except in `GET /app/me/profile`, which leaves it out; a success with no data is `200` with `data: null`, never `204`, deleting included; a list is always `data.items`, never a bare array; a breaking change is `/api/v2` or a forced update (`426`), and a new field never breaks. The app's proposed contracts were written before these and use lower-camel enums in places: each will take the server's form when its task comes, as the backend announces its shape. Ids are strings, media URLs absolute, an unknown enum value is treated as the least privileged one, and bilingual text is `{ "ar": "…", "en": "…" }`.

### Envelope examples (real responses)

Success (`test/fixtures/api/system_ping_ok.json`):

```json
{ "statusCode": 200, "message": "…", "data": { "status": "ok", "serverTime": "2026-10-28T09:00:00Z" }, "error": null, "traceId": "…" }
```

Validation failure (`test/fixtures/api/auth_login_validation_failed.json`):

```json
{
  "statusCode": 400,
  "message": "One or more fields are invalid.",
  "data": null,
  "error": {
    "code": "validation.failed",
    "details": [
      { "field": "email", "code": "not_empty", "message": "'Email' must not be empty." }
    ]
  },
  "traceId": "…"
}
```

## Endpoint contracts

One file per endpoint group, with request, response and example; the matching mock data and test fixture use the same JSON.

| Contract | Used by | Data in the app |
|---|---|---|
| [`openapi.json`](openapi.json) | The App API: auth, the guest and its upgrades, `/app/me`, onboarding, `system/config`, tracks, enrollments and the track's map, the placement test, a lesson, sync, a unit's test and the level check, the profile, ping | live, the endpoints below marked used |
| [`tracks.md`](tracks.md) | Onboarding "who will learn", the grade step, "preparing" (first unit), «أنا»'s tracks and grades | live, units mock |
| [`placement.md`](placement.md) | Onboarding "how much English do you know?", "preparing", the placement test's intro, questions and result | live |
| [`lessons.md`](lessons.md) | A lesson, its questions and their answers: the server's lesson and the sync are live; the other templates and lesson types, the unit and what a lesson reports besides are proposed | live in part |
| [`unit-tests.md`](unit-tests.md) | A unit's test from the map's last stone, its start, questions and result, and the level suggested after the first unit's test | live, no test published yet |
| [`auth.md`](auth.md) | Accounts: sign-up and sign-in, password recovery, the email's confirmation, Google and Apple, "save progress"'s guest account and its upgrades (ADR 10), onboarding's answers | live |
| [`concepts.md`](concepts.md) | «مفاهيم للتقوية»: the list and a session of new questions | mock |
| [`explanations.md`](explanations.md) | «اشرح لي» under a wrong answer, in a lesson or a concept's session | mock |
| [`talk.md`](talk.md) | «تحدّث»: the scenarios, the intro, a conversation's turns and its summary's notes | mock |
| [`practice.md`](practice.md) | The «تدرّب» tab, a review of the word bank, «كلماتي» | mock |
| [`me.md`](me.md) | «أنا» and the settings: the profile, its name, the active track and the grade, the goal and the reminder, the password and deleting the account | live, the profile and deletion mock |
| [`home.md`](home.md) | The «تعلّم» tab and a unit's screen: put together from the account, the joined tracks and the active track's map; today, the review, the cards and one-time notices in mock mode only | live in part |
| [`notifications.md`](notifications.md) | Notifications: the push token, what the server sends and what a tap opens (ADR 21) | proposed, mock |
| [`downloads.md`](downloads.md) | Lessons downloaded to open with no connection: a lesson's files, and the panel's limits (ADR 22) | proposed, mock |
| [`settings.md`](settings.md) | Onboarding reminder step (reminder times, the reminder's text), the splash's version gate, later every screen that reads a setting | mock |

## Headers sent on every request

`Accept: application/json` · `Accept-Language: ar|en` · `X-App-Version: <semver>` · `X-Platform: android|ios` · `Authorization: Bearer <token>` (unless the request opts out). The document declares only `Authorization`; the other headers are the app's, for the app gate and localization. Refresh also sends the expired access token as `Authorization`, which the server does not require.

## Endpoints

| Endpoint | Method | Body | Response `data` | Status |
|---|---|---|---|---|
| `/api/v1/auth/register` | POST | `RegisterRequest {email, password, displayName, deviceId, platform}` | `TokenResponse` (201); 409 when the email has an account | live, used (email sign-up) |
| `/api/v1/auth/login` | POST | `LoginRequest {email, password, deviceId, platform}` | `TokenResponse`; 401 for wrong credentials, 429 for too many tries | live, used (sign-in) |
| `/api/v1/auth/refresh` | POST | `RefreshRequest {refreshToken}` | `TokenResponse` | live, used |
| `/api/v1/auth/logout` | POST | `LogoutRequest {refreshToken}` | — | live, used (sign-out, never waited on) |
| `/api/v1/app/me` | GET | — | `UserDto`; the goal and the reminder ([me.md](me.md)) | live, used |
| `/api/v1/app/me` | PUT | `UpdateMeRequest {displayName, timeZone, uiLanguage}` | `UserDto` | live, used (the name) |
| `/api/v1/app/me/learning` | PUT | `UpdateLearningRequest {dailyGoalMinutes, reminderTime}` | `UserDto` ([me.md](me.md)) | live, used |
| `/api/v1/app/enrollments/{trackId}/active` | PUT | — | the enrollments ([me.md](me.md)) | live, used |
| `/api/v1/app/enrollments/{trackId}/level` | PUT | `ChangeLevelRequest {levelId}` | `EnrollmentDto` ([me.md](me.md)) | live, used |
| `/api/v1/app/system/ping` | GET | — | `PingResponse {status, serverTime}` | live, not used yet |
| `/api/v1/app/tracks` | GET | — (a session) | `{items: TrackCatalogItemDto[]}`, each with its levels ([tracks.md](tracks.md)) | live, used |
| `/api/v1/app/lessons/{id}` | GET | — | `{id, versionId, versionNo, type, content, questions[], media}`, with keys ([lessons.md](lessons.md)) | live, used |
| `/api/v1/app/lessons/{id}/answers/review` | POST | `{attemptId, lessonVersion, questionId, answer, hinted}` | `{correct}` ([lessons.md](lessons.md)) | proposed, mock; not needed on the server: word orders take saved alternatives only |
| `/api/v1/app/lessons/{id}/words` | POST | `{spanId or wordId, saved, base?, kind?, ar?, note?, sentence?}` | none ([lessons.md](lessons.md)) | proposed; v0.4 |
| `/api/v1/app/concepts` | GET | — | today's concepts with their new questions, those later and those mastered ([concepts.md](concepts.md)) | proposed; v0.5 |
| `/api/v1/app/concepts/answers` | POST | `{answerId, conceptId, questionId, correct, answeredAt}` | none; safe to repeat | proposed; v0.5 |
| `/api/v1/app/concepts/reports` | POST | `{reportId, conceptId, questionId, reason}` | none; safe to repeat | proposed; not planned on the server |
| `/api/v1/app/explanations` | POST | `{questionId, lessonId or conceptId, answer}` | the explanation and the explanations left today, or `quotaOut` ([explanations.md](explanations.md)) | proposed; v0.5 |
| `/api/v1/app/explanations/{id}/rating` | POST | `{helpful}` | none | proposed; v0.5 |
| `/api/v1/app/talk` | GET | — | the scenarios by unit and the AI conversations left today ([talk.md](talk.md)) | proposed; v0.5 |
| `/api/v1/app/talk/scenarios/{id}` | GET | — | the intro, role, tasks, opening line and first suggestions | proposed; v0.5 |
| `/api/v1/app/talk/conversations` | POST | `{conversationId, scenarioId}` | none; counts against today's limit | proposed; v0.5 |
| `/api/v1/app/talk/conversations/{id}/turns` | POST | `{turnId, text, via}` | the reply, every task done so far, suggestions, turns left; safe to repeat | proposed; v0.5 |
| `/api/v1/app/talk/conversations/{id}/end` | POST | `{tasksDone}` | none | proposed; v0.5 |
| `/api/v1/app/talk/conversations/{id}/notes` | GET | — | the summary's notes: `ready`, `pending` or `failed` | proposed; v0.5 |
| `/api/v1/app/word-bank` | GET | — | the bank, its words and their boxes ([practice.md](practice.md)) | proposed; v0.4 |
| `/api/v1/app/word-bank/reviews` | POST | `{reviewId, wordId, known, reviewedAt}` | none; safe to repeat | proposed; v0.4 |
| `/api/v1/app/word-bank/words/{wordId}` | DELETE | — | none; safe to repeat | proposed; v0.4 |
| `/api/v1/app/lessons/{id}/shadowing` | POST | `{sentenceId, heard, total}` | none; the server keeps the best | proposed; v0.4 |
| `/api/v1/app/lessons/{id}/content-done` | POST | `{lessonVersion}` | none; safe to repeat | proposed; the server plans it for v0.3 (a text, a video) and v0.4 (vocabulary) |
| `/api/v1/app/lessons/{id}/watch` | POST | `{videoId, lessonVersion, positionSeconds, watched}` | none; only the latest counts | proposed; the server plans it for v0.2, with where a lesson stopped |
| `/api/v1/app/lessons/{id}/questions` | GET | — | **Only the caller's** questions and replies ([lessons.md](lessons.md), ADR 14) | proposed; v1.0 |
| `/api/v1/app/lessons/{id}/questions` | POST | `{questionId, text, videoSeconds?}` | The question; safe to repeat | proposed; v1.0 |
| `/api/v1/app/lessons/{id}/complete` | POST | `{completionId, lessonVersion, seconds}` | The official numbers ([lessons.md](lessons.md)) | proposed, mock lessons only; not needed on the server: the sync completes a lesson |
| `/api/v1/app/lessons/{id}/answers/spoken-review` | POST | `{attemptId, lessonVersion, questionId, answer, hinted}` | `{outcome, note?, better?}` ([lessons.md](lessons.md)) | proposed; v0.5, through the sync with a `pending_ai` status |
| `/api/v1/app/lessons/{id}/reports` | POST | `{reportId, lessonVersion, questionId, reason, answer?}` | none; safe to repeat ([lessons.md](lessons.md)) | proposed, mock; not planned on the server |
| `/api/v1/app/sync` | POST | `{sentAt, attempts: [{clientAttemptId, lessonVersionId, questionVersionId, runId, answer, hintsUsed, clientCreatedAt}]}` | one result for each answer (`accepted`, `duplicate` or `rejected`), and what they completed; safe to repeat ([lessons.md](lessons.md)) | live, used |
| `/api/v1/app/unit-tests/{id}` | GET | — | `UnitTestAppDto`: the state and the questions with no key, in this learner's order ([unit-tests.md](unit-tests.md)) | live, used; no test published on the demo track |
| `/api/v1/app/unit-tests/{id}/submissions` | POST | `{clientSubmissionId, versionId, answers: [{questionVersionId, answer}]}` | `UnitTestResultDto`; `422 unit_test.retry_not_yet` with `Retry-After`; safe to repeat ([unit-tests.md](unit-tests.md)) | live, used |
| `/api/v1/app/level-checks/{id}/choose` | POST | `{move}` | `EnrollmentDto`, not read ([unit-tests.md](unit-tests.md)) | live, used |
| `/api/v1/app/placement?trackId=` | GET | — | the state: `available`, `in_progress`, `result`, `done` or `unavailable`, with the test, the session and the result ([placement.md](placement.md)) | live, used |
| `/api/v1/app/placement/sessions` | POST | `{trackId}` | the session at its stage, with its questions ([placement.md](placement.md)) | live, used |
| `/api/v1/app/placement/sessions/{id}` | GET | — | the session ([placement.md](placement.md)) | live, used |
| `/api/v1/app/placement/sessions/{id}/stages/{n}` | POST | `{answers: [{questionId, optionId} or {questionId, dontKnow}]}` | the session as it now stands; safe to repeat ([placement.md](placement.md)) | live, used |
| `/api/v1/app/placement/sessions/{id}/choose` | POST | `{trackId, choice: result or lower}` | `EnrollmentDto` ([placement.md](placement.md)) | live, used |
| `/api/v1/app/enrollments` | GET | — | the learner's enrollments; the placement test takes the active one's track | live, used |
| `/api/v1/app/enrollments/{trackId}/map` | GET | — | the level's units and their lessons, with what is done and open ([home.md](home.md)) | live, used |
| `/api/v1/app/settings` | GET | — | effective settings by section ([settings.md](settings.md)) | proposed for v0.5; the app reads the bundled ones until then |
| `/api/v1/app/system/config` | GET | — (no session) | `SystemConfigDto`: versions, links, goals, AI switches, onboarding's tracks ([settings.md](settings.md)) | live, versions, links and onboarding's tracks used |
| `/api/v1/auth/guest` | POST | `CreateGuestRequest {deviceId, platform, displayName}`, no session | `TokenResponse`, `accountType: "guest"` ([auth.md](auth.md)) | live, used |
| `/api/v1/app/me/onboarding` | POST | `OnboardingRequest`, with the new account's token | `OnboardingResultDto` ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/password/forgot` | POST | `ForgotPasswordRequest {email}` | `202`, the same whether or not the email has an account ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/password/reset/check` | POST | `CheckResetTokenRequest {token}` | `ResetTokenInfo {email}`; `400 auth.reset_token_invalid` for a link expired, used or unknown ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/password/reset` | POST | `ResetPasswordRequest {token, newPassword, deviceId, platform}` | `TokenResponse`; `400 auth.reset_token_invalid` as above, `400 validation.failed` for a refused password ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/password/change` | POST | `ChangePasswordRequest {currentPassword, newPassword, deviceId, platform}` | `TokenResponse`, the session this phone keeps ([me.md](me.md)) | live, used |
| `/api/v1/auth/email/verify` | POST | `VerifyEmailRequest {token}` | none; `400 auth.email_link_invalid` for a link expired, used or unknown ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/email/resend` | POST | — | `202`; `409`, `429` ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/email` | PUT | `ChangeEmailRequest {newEmail}` | `202`; `409` when it has an account ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/google` | POST | `GoogleSignInRequest {idToken, deviceId, platform}` | `TokenResponse` with `isNewUser`; `401 auth.google_token_invalid`, `403 auth.account_disabled`, `409 auth.email_taken` or `auth.external_login_conflict` ([auth.md](auth.md)) | live, used (no real token sent yet, STATUS D-110) |
| `/api/v1/auth/apple` | POST | `AppleSignInRequest {identityToken, authorizationCode, nonce, givenName, familyName, deviceId, platform}` | `TokenResponse` | live, not used |
| `/api/v1/app/me/push-token` | PUT | `{token, platform, deviceId}` | `204` ([notifications.md](notifications.md)) | proposed, mock; v1.0, answering `200` with no data |
| `/api/v1/app/lessons/{id}/download` | GET | — | `{lessonId, lessonVersion, lesson, files[]}` ([downloads.md](downloads.md)) | proposed, mock; not planned on the server (an open decision) |
| `/api/v1/auth/guest/upgrade/email` | POST | `{email, password, displayName}`, with the guest's session | `UserDto`; the session carries on ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/guest/upgrade/google` | POST | `{idToken}`, with the guest's session | `UserDto`; `409 auth.external_login_conflict` signs in to that account instead ([auth.md](auth.md)) | live, used |

## Requests to raise with the backend team

Paste-ready; each item names what the app needs and why.

1. **Guest account (ADR 10).** Answered: `POST /api/v1/auth/guest` and the upgrades by email, Google and Apple are live ([auth.md](auth.md)).
2. **Google and Apple for a guest.** Answered: `POST /api/v1/auth/guest/upgrade/google` and `/apple`.
   **Google's client.** The server must check the `idToken`'s audience against the "Web application" client of the app's Google Cloud project ([auth.md](auth.md)); the app's owner sends its ID.
3. **Onboarding answers with account creation.** Answered: `POST /api/v1/app/me/onboarding`, sent with the new account's token right after it is made ([auth.md](auth.md)).
4. **Content and settings endpoints**, under `/api/v1/app/` and in the same envelope: `GET /app/settings` (effective settings after inheritance). Contracts in [tracks.md](tracks.md), [placement.md](placement.md), [settings.md](settings.md); the settings call must work **without a token**, because onboarding reads them before an account exists.
5. **Time zone as an IANA name.** Answered: an `Etc/GMT` zone is accepted, and a city (`Asia/Damascus`, the default) is better; the app still sends the phone's offset (STATUS D-043). Was: (`Asia/Damascus`), as `UserDto.timeZone` suggests: confirm the format and accept it at account creation, so the day start and reminders follow daylight-saving changes (the app sends a UTC offset today, STATUS D-043).
6. **The password policy.** Answered: a password is 8 to 128 characters, a name 1 to 100, an email up to 256. Was: in the OpenAPI document: any name length limit as `minLength`/`maxLength` (the password's 8 shows only in register's answer), and the `details` codes beyond `not_empty`. The codes per endpoint are there now, in each response's description; as an `enum` or an extension field they could be checked by a test.
7. **`Retry-After` on 429.** Answered by the document: `auth.locked_out` (5 wrong passwords, 5 minutes) and `rate_limit.exceeded` both carry it, and the app counts it down. Not yet seen on the dev server.
8. **Refresh semantics.** Answered: `400`, `401` and `403` from refresh end the session, `429` and `5xx` are passing. The refresh token changes on every refresh, so the new one is always kept; one used again after 60 seconds revokes all the device's tokens (`auth.refresh_token_reused`). Refresh doesn't read `Authorization`. Was: Confirm that 400/401/403 from refresh always mean the session is over (the app signs out on them) and anything else is transient; whether the refresh token rotates on every call (the app stores the new one when it comes back); and whether refresh should accept the expired access token header or ignore it.
9. **The links in the emails open the app.** Waiting: `assetlinks.json` and Apple's file need `engleazia.com` to be hosted, and the backend needs the Android package name, its signing key's SHA-256 and the iOS Bundle ID from the app's owner. Was: Recovery and confirmation are live; their links (`https://engleazia.com/reset-password?token=…&email=…`, `/verify-email?token=…`) need `assetlinks.json` and apple-app-site-association on that host, and the Apple relay domain registered so they reach hidden Apple emails (S §5.1).
10. **The password change's refusals.** Answered by the document: a wrong current password is `400 auth.current_password_invalid`, an account with no password `409 auth.password_not_set`, five wrong tries `429 auth.locked_out`. The app keys on the first; it has not been seen on the dev server yet.
11. **The confirmation link's code.** Answered: a bad `/auth/email/verify` token is now `auth.email_link_invalid` (`test/fixtures/api/auth_email_verify_link_invalid.json`), which the app reads as an expired link, like the recovery's. Please announce a code's change before it reaches the dev server: this one made the expired-link screen show a form error until the app followed.
12. **App gate.** Answered: `GET /api/v1/app/system/config` carries the versions and the store page, and every `/app/` call refuses a version below the minimum with `426 app.update_required`; the app follows both.
13. **Localize `message` and `details[].message` via `Accept-Language`.** Answered: no; `message` stays English, and the app never shows it.
14. **Attempts** accept a client-generated id so resending never duplicates an attempt or XP. Answered for lesson questions: `clientAttemptId` in `POST /api/v1/app/sync` ([lessons.md](lessons.md)) (student requirements §2 principle 4, §7.1, §21; server requirements §19.3).
15. **Versioning.** Answered: the path stays `/api/v1`; a new field never breaks; a breaking change is `/api/v2` or a forced update (`426`).
16. **Lesson content.** Answered: the package format is the content team's; the app reads only `GET /api/v1/app/lessons/{id}` ([lessons.md](lessons.md)). Was: follows the lesson package format in `docs/product/dashboard-server-requirements.md` §20 (timings in ms, stable string ids), with its JSON Schema in v0.1.
