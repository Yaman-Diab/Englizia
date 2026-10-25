# Backend API contract

Backend: **.NET** (ASP.NET Core) REST API, separate team. No OpenAPI document has been shared yet.
Preferred: the backend exports `openapi.json` (Swashbuckle / NSwag) and it is committed here.

Every assumption in code is tagged `// ASSUMPTION(api): ...` — `grep -rn "ASSUMPTION(api)" lib` lists them.
When a field is confirmed, save a sanitized real response under `test/fixtures/api/` and parse it in a test.

## Conventions the app assumes

| Topic | Assumption | Status |
|---|---|---|
| JSON casing | camelCase (System.Text.Json web defaults) | assumed |
| Base path | `/api/v1/...` | assumed |
| Errors | RFC 9457 ProblemDetails: `title`, `detail`, `status`, `errors: {Field: [msg]}`; optional `code` extension for business errors | assumed |
| Field names in `errors` | normalized by the app: `$.Email` / `request.Email` / `Email` → `email` | app-side |
| Rate limiting | 429 with `Retry-After` in seconds | assumed |
| Auth | JWT access token (Bearer) + refresh token | assumed |
| Localization | server reads `Accept-Language` (`ar` / `en`) and localizes messages | to request |
| App gate | `GET /api/v1/app/config` → `minSupportedVersion` | to request |

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
4. Attempts accept a client-generated `attemptId` so resending never duplicates an attempt or XP (requirements §2.4, §17).
5. Keep deprecated routes alive for one release cycle; expose `minSupportedVersion`.
6. Lesson content follows the lesson package format in `docs/product/dashboard-requirements.md` §10 (timings in ms, stable string ids).
7. Confirm which refresh-endpoint statuses mean the refresh token is invalid or revoked. The app signs the user out on 400/401/403 and treats every other failure (5xx, 429, timeout, malformed body) as transient.
