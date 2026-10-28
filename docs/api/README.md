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
| Error codes | Dotted lower-case: `validation.failed` (400, with `details` codes such as `not_empty`), `auth.unauthenticated` (401, no or bad access token), `auth.refresh_token_invalid` (401 from refresh). Constants in `lib/core/network/api_error_codes.dart` | confirmed (these three); the full list is requested |
| Auth | JWT Bearer access token with `expiresIn` seconds, plus a refresh token with `refreshTokenExpiresAt`, both in `TokenResponse`. The app refreshes 30 s before the access token expires and once more on a 401, sharing one refresh call; a 400/401/403 from refresh signs the user out | confirmed |
| Devices | Login and register take `deviceId` (null on the first login; the server returns one in `TokenResponse`) and `platform` (`DevicePlatform`: `android`, `web`) | confirmed; `ios` is missing |
| User | `UserDto {id (uuid), userName, email?, displayName, emailVerified, roles[], timeZone, uiLanguage (ar\|en)}`, changed through `PUT /api/v1/app/me` | confirmed |
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
| [`openapi.json`](openapi.json) | Register, login, refresh, logout, `/app/me`, ping | register and refresh (sign-in is not built) |
| [`tracks.md`](tracks.md) | Onboarding "who will learn", the grade step, "preparing" (first unit), later track switching | mock |
| [`placement.md`](placement.md) | Onboarding "how much English do you know?", later the placement test | mock |
| [`auth.md`](auth.md) | "Save progress": the guest account (ADR 10) | mock |
| [`settings.md`](settings.md) | Onboarding reminder step (reminder times, the reminder's text), later every screen that reads a setting | mock |

## Headers sent on every request

`Accept: application/json` · `Accept-Language: ar|en` · `X-App-Version: <semver>` · `X-Platform: android|ios` · `Authorization: Bearer <token>` (unless the request opts out). The document declares only `Authorization`; the other headers are the app's, for the app gate and localization. Refresh also sends the expired access token as `Authorization`, which the server does not require.

## Endpoints

| Endpoint | Method | Body | Response `data` | Status |
|---|---|---|---|---|
| `/api/v1/auth/register` | POST | `RegisterRequest {email, password, displayName, deviceId, platform}` | `TokenResponse` (201); 409 when the email has an account | live, used (email sign-up) |
| `/api/v1/auth/login` | POST | `LoginRequest {email, password, deviceId, platform}` | `TokenResponse` | live, not used yet |
| `/api/v1/auth/refresh` | POST | `RefreshRequest {refreshToken}` | `TokenResponse` | live, used |
| `/api/v1/auth/logout` | POST | `LogoutRequest {refreshToken}` | — | live, used (sign-out, never waited on) |
| `/api/v1/app/me` | GET | — | `UserDto` | live, not used yet |
| `/api/v1/app/me` | PUT | `UpdateMeRequest {displayName, timeZone, uiLanguage}` | `UserDto` | live, not used yet |
| `/api/v1/app/system/ping` | GET | — | `PingResponse {status, serverTime}` | live, not used yet |
| `/api/v1/app/tracks` | GET | — | track list ([tracks.md](tracks.md)) | proposed, mock |
| `/api/v1/app/tracks/{trackId}/levels` | GET | — | level list ([tracks.md](tracks.md)) | proposed, mock |
| `/api/v1/app/levels/{levelId}/units` | GET | — | unit list ([tracks.md](tracks.md)) | proposed, mock |
| `/api/v1/app/placement/summary` | GET | — | duration and stages ([placement.md](placement.md)) | proposed, mock |
| `/api/v1/app/settings` | GET | — | effective settings by section ([settings.md](settings.md)) | proposed, mock |
| `/api/v1/auth/guest` | POST | `{installationId, language, utcOffsetMinutes, onboarding}` | `TokenResponse` ([auth.md](auth.md)) | proposed, mock |
| `/api/v1/auth/guest/upgrade` | POST | `RegisterRequest`, with the guest's token | `TokenResponse` of the same account, now a member ([auth.md](auth.md)) | proposed, mock |

## Requests to raise with the backend team

Paste-ready; each item names what the app needs and why.

1. **`ios` in `DevicePlatform`.** The enum has `android` and `web` only; the app ships on iPhone too, so login and register from an iPhone cannot send a valid platform.
2. **Guest account (ADR 10).** `POST /api/v1/auth/guest` as in [auth.md](auth.md): no token, idempotent on `installationId`, returns the same `TokenResponse` with `roles: ["guest"]`. Plus the **upgrade**, `POST /api/v1/auth/guest/upgrade` with the guest's token and register's body: the same account becomes a member and keeps its progress; agree it and what happens when the email already has an account.
3. **Google and Apple sign-in.** Endpoints that take the provider's ID token and return `TokenResponse` (and upgrade a guest the same way). Apple sign-in is required on iOS when Google is offered.
4. **Onboarding answers with account creation.** `RegisterRequest` (and the guest and social endpoints) should accept the `onboarding` object from [auth.md](auth.md) (audience, track, child profile, grade, reasons, daily goal, challenge, start level, placement choice, reminder time), so the plan is ready on first sign-in (S §4.3).
5. **Content and settings endpoints**, under `/api/v1/app/` and in the same envelope: `GET /app/tracks`, `GET /app/tracks/{trackId}/levels`, `GET /app/levels/{levelId}/units`, `GET /app/placement/summary`, `GET /app/settings` (effective settings after inheritance). Contracts in [tracks.md](tracks.md), [placement.md](placement.md), [settings.md](settings.md); the tracks, levels and settings calls must work **without a token**, because onboarding reads them before an account exists.
6. **Time zone as an IANA name** (`Asia/Damascus`), as `UserDto.timeZone` suggests: confirm the format and accept it at account creation, so the day start and reminders follow daylight-saving changes (the app sends a UTC offset today, STATUS D-043).
7. **The password policy and the full list of `error.code` values** per endpoint, kept in the OpenAPI document: the minimum password length (the app checks 8, S §4.3) and any name length limit as `minLength`/`maxLength`, and the codes for at least email taken (409 on register), wrong credentials (401 on login), account locked or disabled (403 on login), rate limited (429), and the `details` codes beyond `not_empty`. The app shows its own text per code.
8. **`Retry-After` on 429** (seconds), so the app can tell the learner how long to wait after too many failed logins (§19.8).
9. **Refresh semantics.** Confirm that 400/401/403 from refresh always mean the session is over (the app signs out on them) and anything else is transient; whether the refresh token rotates on every call (the app stores the new one when it comes back); and whether refresh should accept the expired access token header or ignore it.
10. **App gate.** An endpoint for the minimum and recommended app version per platform (§19.2), e.g. `GET /api/v1/app/config`.
11. **Localize `message` and `details[].message` via `Accept-Language`**, for logs and support; the app never shows them.
12. **Attempts** accept a client-generated `attemptId` so resending never duplicates an attempt or XP (student requirements §2 principle 4, §7.1, §21; server requirements §19.3).
13. **Versioning.** Keep deprecated routes alive for one release cycle, and publish the OpenAPI document with every release.
14. **Lesson content** follows the lesson package format in `docs/product/dashboard-server-requirements.md` §20 (timings in ms, stable string ids), with its JSON Schema in v0.1.
