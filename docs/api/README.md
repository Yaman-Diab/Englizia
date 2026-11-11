# Backend API contract

Backend: **.NET** (ASP.NET Core) REST API, separate team. Per `docs/product/dashboard-server-requirements.md` §19.1 the backend delivers an **OpenAPI document with every release** (app and control panel share it), plus a JSON Schema for the lesson package with v0.1.

- **Dev server:** `https://api-dev.engleazia.com` (`env/dev.json`). Interactive docs at `/scalar/#app-api`, the document itself at `/openapi/app.json`.
- **[`openapi.json`](openapi.json)** is the committed copy of the app's OpenAPI document; replace it with every release and reconcile this folder, the fake data sources and the fixtures against it.
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
| Localization | The app sends `Accept-Language` (`ar` / `en`); whether `message` is localized is unknown, and it is not shown anyway | to confirm |
| App gate | The server returns the minimum allowed app version per platform (v0.1) and the recommended one (v1.0) (§19.2, required); no endpoint yet | required, not in the document |
| Effective settings | The server returns settings after inheritance (global → track → level → lesson); the app reads them on open and caches them; no setting is hardcoded in the app (§19.2, student §2 principle 6) | required, proposed in [settings.md](settings.md) |
| Times | ISO-8601 UTC; the student's day uses their time zone and a configurable day start, default 04:00 (§19.1) | confirmed (format) |

Proposed contracts keep these rules too: ids are strings, absolute media URLs, enums are lower-camel strings and an unknown value is treated as the least privileged one, bilingual text is `{ "ar": "…", "en": "…" }` (as in the content package, server doc §20.1).

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
| [`openapi.json`](openapi.json) | Register, login, refresh, logout, `/app/me`, ping | register, login, refresh and logout |
| [`tracks.md`](tracks.md) | Onboarding "who will learn", the grade step, "preparing" (first unit), later track switching | mock |
| [`placement.md`](placement.md) | Onboarding "how much English do you know?", later the placement test | mock |
| [`lessons.md`](lessons.md) | A lesson's exercises and their answers | mock |
| [`auth.md`](auth.md) | Accounts: sign-up and sign-in, password recovery, the email's confirmation, Google and Apple, and "save progress"'s guest account (ADR 10) | live, guest mock |
| [`concepts.md`](concepts.md) | «مفاهيم للتقوية»: the list and a session of new questions | mock |
| [`explanations.md`](explanations.md) | «اشرح لي» under a wrong answer, in a lesson or a concept's session | mock |
| [`talk.md`](talk.md) | «تحدّث»: the scenarios, the intro, a conversation's turns and its summary's notes | mock |
| [`practice.md`](practice.md) | The «تدرّب» tab, a review of the word bank, «كلماتي» | mock |
| [`me.md`](me.md) | «أنا» and the settings: the profile, its name, the active track and the grade, the preferences, the password and deleting the account | mock (`PUT /api/v1/app/me` confirmed) |
| [`home.md`](home.md) | The «تعلّم» tab: the active track's units, the current unit's lessons, today, the review, the cards and one-time notices | mock |
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
| `/api/v1/app/me` | GET | — | `UserDto` | live, not used yet |
| `/api/v1/app/me` | PUT | `UpdateMeRequest {displayName, timeZone, uiLanguage}` | `UserDto` | live, not used yet |
| `/api/v1/app/system/ping` | GET | — | `PingResponse {status, serverTime}` | live, not used yet |
| `/api/v1/app/tracks` | GET | — | track list ([tracks.md](tracks.md)) | proposed, mock |
| `/api/v1/app/tracks/{trackId}/levels` | GET | — | level list ([tracks.md](tracks.md)) | proposed, mock |
| `/api/v1/app/levels/{levelId}/units` | GET | — | unit list ([tracks.md](tracks.md)) | proposed, mock |
| `/api/v1/app/lessons/{id}` | GET | — | `{id, version, exercises}`, with keys ([lessons.md](lessons.md)) | proposed, mock |
| `/api/v1/app/lessons/{id}/answers/review` | POST | as an answer | `{correct}` ([lessons.md](lessons.md)) | proposed, mock |
| `/api/v1/app/lessons/{id}/words` | POST | `{spanId or wordId, saved, base?, kind?, ar?, note?, sentence?}` | none ([lessons.md](lessons.md)) | proposed |
| `/api/v1/app/concepts` | GET | — | today's concepts with their new questions, those later and those mastered ([concepts.md](concepts.md)) | proposed |
| `/api/v1/app/concepts/answers` | POST | `{answerId, conceptId, questionId, correct, answeredAt}` | none; safe to repeat | proposed |
| `/api/v1/app/concepts/reports` | POST | `{reportId, conceptId, questionId, reason}` | none; safe to repeat | proposed |
| `/api/v1/app/explanations` | POST | `{questionId, lessonId or conceptId, answer}` | the explanation and the explanations left today, or `quotaOut` ([explanations.md](explanations.md)) | proposed |
| `/api/v1/app/explanations/{id}/rating` | POST | `{helpful}` | none | proposed |
| `/api/v1/app/talk` | GET | — | the scenarios by unit and the AI conversations left today ([talk.md](talk.md)) | proposed |
| `/api/v1/app/talk/scenarios/{id}` | GET | — | the intro, role, tasks, opening line and first suggestions | proposed |
| `/api/v1/app/talk/conversations` | POST | `{conversationId, scenarioId}` | none; counts against today's limit | proposed |
| `/api/v1/app/talk/conversations/{id}/turns` | POST | `{turnId, text, via}` | the reply, every task done so far, suggestions, turns left; safe to repeat | proposed |
| `/api/v1/app/talk/conversations/{id}/end` | POST | `{tasksDone}` | none | proposed |
| `/api/v1/app/talk/conversations/{id}/notes` | GET | — | the summary's notes: `ready`, `pending` or `failed` | proposed |
| `/api/v1/app/word-bank` | GET | — | the bank, its words and their boxes ([practice.md](practice.md)) | proposed |
| `/api/v1/app/word-bank/reviews` | POST | `{reviewId, wordId, known, reviewedAt}` | none; safe to repeat | proposed |
| `/api/v1/app/word-bank/words/{wordId}` | DELETE | — | none; safe to repeat | proposed |
| `/api/v1/app/lessons/{id}/shadowing` | POST | `{sentenceId, heard, total}` | none; the server keeps the best | proposed |
| `/api/v1/app/lessons/{id}/content-done` | POST | `{lessonVersion}` | none; safe to repeat | proposed |
| `/api/v1/app/lessons/{id}/watch` | POST | `{videoId, lessonVersion, positionSeconds, watched}` | none; only the latest counts | proposed |
| `/api/v1/app/lessons/{id}/questions` | GET | — | **Only the caller's** questions and replies ([lessons.md](lessons.md), ADR 14) | proposed |
| `/api/v1/app/lessons/{id}/questions` | POST | `{questionId, text, videoSeconds?}` | The question; safe to repeat | proposed |
| `/api/v1/app/lessons/{id}/complete` | POST | `{completionId, lessonVersion, seconds}` | The official numbers ([lessons.md](lessons.md)) | proposed |
| `/api/v1/app/lessons/{id}/answers/spoken-review` | POST | as an answer | `{outcome, note?, better?}` ([lessons.md](lessons.md)) | proposed |
| `/api/v1/app/lessons/{id}/reports` | POST | `{reportId, lessonVersion, questionId, reason, answer?}` | none; safe to repeat ([lessons.md](lessons.md)) | proposed, mock |
| `/api/v1/app/lessons/{id}/answers` | POST | `{attemptId, lessonVersion, questionId, answer, hinted}` | none; safe to repeat ([lessons.md](lessons.md)) | proposed, mock |
| `/api/v1/app/placement/summary` | GET | — | duration and stages ([placement.md](placement.md)) | proposed, mock |
| `/api/v1/app/placement/status` | GET | — | `{state, stage?, question?, lastLevel?, daysSinceResult?, daysUntilRetake?}` ([placement.md](placement.md)) | proposed, mock |
| `/api/v1/app/placement/attempts` | POST | `{}` or `{restart: true}` | `{attemptId, stageSizes, stage, answered}` ([placement.md](placement.md)) | `restart` from the backend guide, the rest proposed; mock |
| `/api/v1/app/placement/attempts/{id}/stages/{n}` | GET | — | `{stage, questions}`, no answer keys ([placement.md](placement.md)) | proposed, mock |
| `/api/v1/app/placement/attempts/{id}/answers` | POST | `{answerId, questionId, optionId, dontKnow, plays}` | none; safe to repeat ([placement.md](placement.md)) | proposed, mock |
| `/api/v1/app/placement/attempts/{id}/stages/{n}/complete` | POST | — | `{next}`, null at the end ([placement.md](placement.md)) | proposed, mock |
| `/api/v1/app/placement/attempts/{id}/result` | GET | — | `{levelId, levels, skills}` ([placement.md](placement.md)) | proposed, mock |
| `/api/v1/app/placement/attempts/{id}/accept` | POST | `{levelId}` | none ([placement.md](placement.md)) | proposed, mock |
| `/api/v1/app/enrollments/{id}` | PATCH | `{placement_state: "deferred"}` | ignored ([placement.md](placement.md)) | from the backend guide, unconfirmed, mock |
| `/api/v1/app/home` | GET | — | the active enrollment's tab ([home.md](home.md)) | proposed, mock |
| `/api/v1/app/settings` | GET | — | effective settings by section ([settings.md](settings.md)) | proposed, mock |
| `/api/v1/auth/guest` | POST | `{installationId, language, utcOffsetMinutes, onboarding}` | `TokenResponse` ([auth.md](auth.md)) | proposed, mock |
| `/api/v1/auth/password/forgot` | POST | `ForgotPasswordRequest {email}` | `202`, the same whether or not the email has an account ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/password/reset/check` | POST | `CheckResetTokenRequest {token}` | `ResetTokenInfo {email}`; `400 auth.reset_token_invalid` for a link expired, used or unknown ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/password/reset` | POST | `ResetPasswordRequest {token, newPassword, deviceId, platform}` | `TokenResponse`; `400 auth.reset_token_invalid` as above, `400 validation.failed` for a refused password ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/password/change` | POST | `ChangePasswordRequest {currentPassword, newPassword, deviceId, platform}` | `TokenResponse`, the session this phone keeps ([me.md](me.md)) | live, used |
| `/api/v1/auth/email/verify` | POST | `VerifyEmailRequest {token}` | none; `400 auth.email_link_invalid` for a link expired, used or unknown ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/email/resend` | POST | — | `202`; `409`, `429` ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/email` | PUT | `ChangeEmailRequest {newEmail}` | `202`; `409` when it has an account ([auth.md](auth.md)) | live, used |
| `/api/v1/auth/google` | POST | `GoogleSignInRequest {idToken, deviceId, platform}` | `TokenResponse` with `isNewUser`; `401 auth.google_token_invalid`, `403 auth.account_disabled`, `409 auth.email_taken` or `auth.external_login_conflict` ([auth.md](auth.md)) | live, used (no real token sent yet, STATUS D-110) |
| `/api/v1/auth/apple` | POST | `AppleSignInRequest {identityToken, authorizationCode, nonce, givenName, familyName, deviceId, platform}` | `TokenResponse` | live, not used |
| `/api/v1/auth/guest/upgrade` | POST | `RegisterRequest`, with the guest's token | `TokenResponse` of the same account, now a member ([auth.md](auth.md)) | proposed, mock |

## Requests to raise with the backend team

Paste-ready; each item names what the app needs and why.

1. **Guest account (ADR 10).** `POST /api/v1/auth/guest` as in [auth.md](auth.md): no token, idempotent on `installationId`, returns the same `TokenResponse` with `roles: ["guest"]`. Plus the **upgrade**, `POST /api/v1/auth/guest/upgrade` with the guest's token and register's body: the same account becomes a member and keeps its progress; agree it and what happens when the email already has an account.
2. **Google and Apple for a guest.** `POST /api/v1/auth/google` and `/apple` exist; a guest signing in with one should upgrade the same account, as the email upgrade does, and `isNewUser: true` should take the `onboarding` answers (item 3). Today the app's Google sign-in leaves the guest account behind.
   **Google's client.** The server must check the `idToken`'s audience against the "Web application" client of the app's Google Cloud project ([auth.md](auth.md)); the app's owner sends its ID.
3. **Onboarding answers with account creation.** `RegisterRequest` (and the guest and social endpoints) should accept the `onboarding` object from [auth.md](auth.md) (audience, track, child profile, grade, reasons, daily goal, challenge, start level, placement choice, reminder time), so the plan is ready on first sign-in (S §4.3).
4. **Content and settings endpoints**, under `/api/v1/app/` and in the same envelope: `GET /app/tracks`, `GET /app/tracks/{trackId}/levels`, `GET /app/levels/{levelId}/units`, `GET /app/placement/summary`, `GET /app/settings` (effective settings after inheritance). Contracts in [tracks.md](tracks.md), [placement.md](placement.md), [settings.md](settings.md); the tracks, levels and settings calls must work **without a token**, because onboarding reads them before an account exists.
5. **Time zone as an IANA name** (`Asia/Damascus`), as `UserDto.timeZone` suggests: confirm the format and accept it at account creation, so the day start and reminders follow daylight-saving changes (the app sends a UTC offset today, STATUS D-043).
6. **The password policy** in the OpenAPI document: any name length limit as `minLength`/`maxLength` (the password's 8 shows only in register's answer), and the `details` codes beyond `not_empty`. The codes per endpoint are there now, in each response's description; as an `enum` or an extension field they could be checked by a test.
7. **`Retry-After` on 429.** Answered by the document: `auth.locked_out` (5 wrong passwords, 5 minutes) and `rate_limit.exceeded` both carry it, and the app counts it down. Not yet seen on the dev server.
8. **Refresh semantics.** Confirm that 400/401/403 from refresh always mean the session is over (the app signs out on them) and anything else is transient; whether the refresh token rotates on every call (the app stores the new one when it comes back); and whether refresh should accept the expired access token header or ignore it.
9. **The links in the emails open the app.** Recovery and confirmation are live; their links (`https://engleazia.com/reset-password?token=…&email=…`, `/verify-email?token=…`) need `assetlinks.json` and apple-app-site-association on that host, and the Apple relay domain registered so they reach hidden Apple emails (S §5.1).
10. **The password change's refusals.** Answered by the document: a wrong current password is `400 auth.current_password_invalid`, an account with no password `409 auth.password_not_set`, five wrong tries `429 auth.locked_out`. The app keys on the first; it has not been seen on the dev server yet.
11. **The confirmation link's code.** Answered: a bad `/auth/email/verify` token is now `auth.email_link_invalid` (`test/fixtures/api/auth_email_verify_link_invalid.json`), which the app reads as an expired link, like the recovery's. Please announce a code's change before it reaches the dev server: this one made the expired-link screen show a form error until the app followed.
12. **App gate.** The minimum and recommended app version per platform (§19.2), proposed as the `appVersion` group of `GET /api/v1/app/settings` ([settings.md](settings.md)), so the app needs one call on open.
13. **Localize `message` and `details[].message` via `Accept-Language`**, for logs and support; the app never shows them.
14. **Attempts** accept a client-generated `attemptId` so resending never duplicates an attempt or XP (student requirements §2 principle 4, §7.1, §21; server requirements §19.3).
15. **Versioning.** Keep deprecated routes alive for one release cycle, and publish the OpenAPI document with every release.
16. **Lesson content** follows the lesson package format in `docs/product/dashboard-server-requirements.md` §20 (timings in ms, stable string ids), with its JSON Schema in v0.1.
