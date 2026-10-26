# Backend API contract

Backend: **.NET** (ASP.NET Core) REST API, separate team. Per `docs/product/dashboard-server-requirements.md` §19.1 the backend delivers an **OpenAPI document with every release** (app and control panel share it), plus a JSON Schema for the lesson package with v0.1. None has arrived yet, so everything below is an assumption except where the Status column says "required".
When the OpenAPI arrives, commit it here as `openapi.json` and reconcile this file, the fake data sources and the fixtures against it.

Every assumption in code is tagged `// ASSUMPTION(api): ...` — `grep -rn "ASSUMPTION(api)" lib` lists them.
When a field is confirmed, save a sanitized real response under `test/fixtures/api/` and parse it in a test.

## Conventions the app assumes

| Topic | Assumption | Status |
|---|---|---|
| JSON casing | camelCase (System.Text.Json web defaults) | assumed |
| Base path | `/api/v1/...` | assumed |
| Envelope and errors | Every response is the unified envelope below; error messages for the app carry **stable codes** and the app shows its own Arabic text (§19.1, required). `ApiClient` unwraps `data`, and `ApiException` reads `error`, falling back to RFC 9457 ProblemDetails while the envelope is not agreed | codes required, envelope proposed |
| Field names in `errors` | normalized by the app: `$.Email` / `request.Email` / `Email` → `email` | app-side |
| Rate limiting | Too many failed logins return a wait time to the app (§19.8, required); modeled as 429 with `Retry-After` in seconds | wait time required, shape assumed |
| Auth | Short-lived access key + refresh key, role and permission checked on every request (§19.1, required); JWT Bearer assumed | required (concept) / assumed (format) |
| Localization | server reads `Accept-Language` (`ar` / `en`) and localizes messages | to request |
| App gate | The server returns the minimum allowed app version per platform (v0.1) and the recommended one (v1.0) (§19.2, required); path and field names assumed: `GET /api/v1/app/config` → `minSupportedVersion` | required (concept) / assumed (shape) |
| Effective settings | The server returns settings after inheritance (global → track → level → lesson); the app reads them on open and caches them; no setting is hardcoded in the app (§19.2, student §2 principle 6) | required |
| Times | Stored in UTC; the student's day uses their time zone and a configurable day start, default 04:00 (§19.1) | required |

## Unified response envelope (proposed to the backend team)

Every response, success or failure, has the same three fields; exactly one of `data` and `error` is non-null.

```json
{ "data": { "id": "trk_01" }, "meta": null, "error": null }
```

Lists carry paging in `meta` (only where a list is paged):

```json
{ "data": [ ... ], "meta": { "page": 1, "pageSize": 20, "total": 134, "hasMore": true }, "error": null }
```

Failures keep an honest HTTP status (401 token, 403 forbidden, 404, 409, 422 validation, 429 rate limit with `Retry-After`, 5xx):

```json
{ "data": null, "meta": null, "error": { "code": "email_taken", "message": "…", "fieldErrors": { "email": ["…"] }, "traceId": "00-ab12…" } }
```

Rules: camelCase; ids are strings; times ISO-8601 UTC; absolute media URLs; enums are lower-camel strings and an unknown value is treated as the least privileged one; bilingual text is `{ "ar": "…", "en": "…" }` (as in the content package, server doc §20.1). `message` is for logs only — the app never shows it. In ASP.NET Core this needs a custom `InvalidModelStateResponseFactory` and an exception-handling middleware that write the `error` object instead of the default ProblemDetails.

## Endpoint contracts

One file per endpoint group, with request, response and example; the matching mock data and test fixture use the same JSON.

| Contract | Used by | Data in the app |
|---|---|---|

## Headers sent on every request

`Accept: application/json` · `Accept-Language: ar|en` · `X-App-Version: <semver>` · `X-Platform: android|ios` · `Authorization: Bearer <token>` (unless the request opts out).

## Endpoints

| Endpoint | Method | Body | Response | Status |
|---|---|---|---|---|
| `/api/v1/auth/refresh` | POST | `{refreshToken}` + `Authorization: Bearer <expired access>` | `{accessToken, refreshToken}` | assumed |

## Requests to raise with the backend team

1. Share the OpenAPI document and keep it updated per release.
2. Return a stable machine `code` for business errors (e.g. `email_taken`, `attempt_duplicate`).
3. Localize validation messages via `Accept-Language`.
4. Attempts accept a client-generated `attemptId` so resending never duplicates an attempt or XP (student requirements §2 principle 4, §7.1, §21; server requirements §19.3).
5. Keep deprecated routes alive for one release cycle; expose `minSupportedVersion`.
6. Lesson content follows the lesson package format in `docs/product/dashboard-server-requirements.md` §20 (timings in ms, stable string ids); the backend delivers a JSON Schema for it with v0.1.
7. Confirm which refresh-endpoint statuses mean the refresh token is invalid or revoked. The app signs the user out on 400/401/403 and treats every other failure (5xx, 429, timeout, malformed body) as transient.
