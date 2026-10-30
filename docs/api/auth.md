# Accounts and sessions

Status: **proposed** — the app runs on this contract in mock mode (`assets/mock/account/`); nothing is confirmed by the backend team yet.
Decision: guest mode is back by the owner's decision (2026-10-27, ADR 10), as a **server-side guest account**. This reverses student doc §4.3 ("no guest mode") and server doc §26's table row ("no guest accounts"); both documents need updating, and the backend needs a guest account type.

## `POST /api/v1/auth/guest`

Creates the anonymous guest account of this phone when the learner chooses «متابعة كضيف» on "save progress". Sent without a token. The guest can learn like any learner (grading, points and streaks stay on the server), but has no credentials: the account is reachable from this install only, until the learner creates a full account, which must **upgrade the same account** so nothing is lost.

### Request

```json
{
  "installationId": "3f0b8f5e-6a1c-4c2e-9d0b-6f1e2a7c9b11",
  "language": "ar",
  "utcOffsetMinutes": 180,
  "onboarding": {
    "audience": "self",
    "trackId": "trk_general",
    "child": null,
    "gradeLevelId": null,
    "reasons": ["travel", "career"],
    "dailyGoalMinutes": 15,
    "challengeDays": 14,
    "startLevelId": "lvl_gen_prea1",
    "placementTest": false,
    "reminderTime": "08:05"
  }
}
```

| Field | Type | Meaning |
|---|---|---|
| `installationId` | UUID v4 string | Random id made on the phone at first use and kept. **Idempotency key**: a retried request with the same id returns the same guest, never a second one |
| `language` | `ar` \| `en` | The interface language chosen in onboarding |
| `utcOffsetMinutes` | int | The phone's offset from UTC now; see question 3 |
| `onboarding.audience` | `self` \| `child` \| `schoolStudent` | "Who will learn" |
| `onboarding.trackId` | string | The track the audience leads to |
| `onboarding.child` | `{name, age}` or null | The child path's profile; the name is shown to the child only (S §4.5) |
| `onboarding.gradeLevelId` | string or null | The school student's grade (a level of the curriculum track) |
| `onboarding.reasons` | string[] | `communication`, `fun`, `education`, `travel`, `career`, `exams` |
| `onboarding.dailyGoalMinutes` / `challengeDays` | int or null | The goal and streak challenge chosen |
| `onboarding.startLevelId` | string or null | The first level, when the learner starts there (now, or with the test left for later) |
| `onboarding.placementTest` | bool | The learner went on to the placement test |
| `onboarding.reminderTime` | `"HH:mm"` or null | The daily reminder, phone time; null for none |

### Response `200`

The server's `TokenResponse`, exactly as login and register return it (`docs/api/openapi.json`), so the guest's session is handled by the same code:

```json
{
  "statusCode": 201,
  "message": "Created",
  "data": {
    "accessToken": "…",
    "expiresIn": 900,
    "tokenType": "Bearer",
    "refreshToken": "…",
    "refreshTokenExpiresAt": "2026-12-31T00:00:00Z",
    "deviceId": "00000000-0000-4000-8000-000000000000",
    "user": {
      "id": "00000000-0000-0000-0000-000000000000",
      "userName": "guest-00000000000",
      "email": null,
      "displayName": "",
      "emailVerified": false,
      "roles": ["guest"],
      "timeZone": "Asia/Damascus",
      "uiLanguage": "ar"
    }
  },
  "error": null,
  "traceId": "0HN7…"
}
```

The tokens work like a member's (same refresh endpoint, same headers); the app stores them as a guest's. `roles` should hold `guest` so the server can refuse member-only actions.

### Errors

The common errors (`docs/api/README.md`). Creating a guest needs a connection; the app says so and offers to retry.

## `POST /api/v1/auth/guest/upgrade`

Turns the guest account of this phone into a member account **in place**: same account id, same progress, points and streak. Sent with the guest's own access token (the normal `Authorization` header), from "create an account" in «أنا» (for now the temporary home). The body is register's `RegisterRequest`:

```json
{
  "email": "user@example.com",
  "password": "…",
  "displayName": "Learner",
  "deviceId": null,
  "platform": "android"
}
```

The response is register's: `TokenResponse` (201) for the member account, whose tokens replace the guest's. Errors as register: `409` when the email already has an account (the app shows "this email already has an account" with "sign in instead"), `400 validation.failed` with field `details`, and `401` when the token is not a guest's.

Status: **proposed**, mock (the mock answers like register). The app never upgrades by calling register: a new account would leave the guest's progress behind.

## `POST /api/v1/auth/password/forgot`

Step 1 of password recovery (S §5.2): `{ "email": "user@example.com" }`, sent without a token. The server mails a link to set a new password (valid one hour, once) **if** the email has an account, and answers the same way either way (`202`, empty `data`), so no screen can tell which emails are registered. It limits requests per email and per device; the app treats `429` as sent too. Other errors (connection, server) show a retry.

"Check your email" sends the same request again after a growing wait the app keeps (1, 2, then 5 minutes, S §5.2), so the server's own limit should allow at least that. The link must open the app directly (App Links and Universal Links, not Firebase Dynamic Links, which are shut down).

Status: **proposed**, mock (always sent).

## The link in the recovery email

`https://engleazia.com/reset-password?token=<token>&email=<email>` opens the app's "set a new password" screen (S §5.2), which shows the email while the token is checked, and hands it to "forgot your password" when the link has expired. A link without a token counts as expired; without an email the screen only leaves that line out. Host and path are **proposed** (`android/app/src/main/AndroidManifest.xml`, STATUS D-024): the server needs `/.well-known/assetlinks.json` on that host for Android and an apple-app-site-association file for iOS. A browser that opens the link without the app needs a page of its own, the backend's to decide.

## `POST /api/v1/auth/password/reset/verify`

`{ "token": "..." }`, sent without a session token, when the screen opens and before the field shows. `200`, empty `data`, for a good link. `410` for one expired, used already or unknown: the same answer for all three.

Status: **proposed**, mock (any token but `expired` is good).

## `POST /api/v1/auth/password/reset`

`{ "token", "password", "deviceId", "platform" }`, sent without a session token. The token works once. Success ends the account's other sessions and answers with a `TokenResponse`, the session that signs the learner in on this phone; a `200` with no tokens means the password changed but no session started, and the learner signs in by hand. `410` as above, `400` (`validation.failed`, naming `password`) for a password the server refuses.

Status: **proposed**, mock (answers like register; the token `offline` fails with no connection, and `no-session` answers with no tokens).

## `POST /api/v1/auth/logout`

Live (docs/api/openapi.json): `{refreshToken}`, sent without the access token. The app calls it on sign-out and never waits on it: signing out works offline, and a failure only means the server forgets the session later. Signing out as a guest loses the account; the app warns first («ستفقد تقدّمك لأنه غير محفوظ في حساب»).

## Questions for the backend team

1. Agree the guest account type: what it may do (everything a learner does?) and how long an unused guest is kept.
2. Agree the upgrade above: the path, that it keeps the same account and progress, the same for Google and Apple sign-up, and what happens when the email already has an account (the app now says so and offers sign-in, which would leave the guest behind; merge instead?).
3. Time zone: the app sends the offset now. For reminders at the learner's time across daylight-saving changes, an IANA name (`Asia/Damascus`) is better; the app can send it once a package is chosen (STATUS D-043).
4. Should onboarding answers go with every account creation (email, Google) in this same `onboarding` shape?
