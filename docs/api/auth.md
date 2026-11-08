# Accounts and sessions

Status: mixed. **Live** on the dev server (docs/api/openapi.json): register, login, refresh, logout, Google and Apple sign-in, password recovery, the password change and the email's confirmation; the app uses all but Google and Apple (STATUS D-001). **Proposed**, mock only (`assets/mock/account/`): the guest account and its upgrade. The real answers the app was checked against are in `test/fixtures/api/auth_*.json`.
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

Turns the guest account of this phone into a member account **in place**: same account id, same progress, points and streak. Sent with the guest's own access token (the normal `Authorization` header), from "create an account" on «أنا»'s guest card (or the dev page's account card). The body is register's `RegisterRequest`:

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

Step 1 of password recovery (S §5.2): `ForgotPasswordRequest { "email": "user@example.com" }`, sent without a token. The server mails a link to set a new password (valid one hour, once) **if** the email has an account, and answers the same way either way (`202`, empty `data`), so no screen can tell which emails are registered. An address that isn't one is a `400 validation.failed` on `email`. It limits requests per email and per device; the app treats `429` as sent too. Other errors (connection, server) show a retry.

"Check your email" sends the same request again after a growing wait the app keeps (1, 2, then 5 minutes, S §5.2), so the server's own limit should allow at least that. The link must open the app directly (App Links and Universal Links, not Firebase Dynamic Links, which are shut down).

Status: **live**, used (the mock always sends).

## The link in the recovery email

`https://engleazia.com/reset-password?token=<token>&email=<email>` opens the app's "set a new password" screen (S §5.2), which shows the email while the token is checked, and hands it to "forgot your password" when the link has expired. A link without a token counts as expired; without an email the screen only leaves that line out. Host and path are **proposed** (`android/app/src/main/AndroidManifest.xml`, STATUS D-024): the server needs `/.well-known/assetlinks.json` on that host for Android and an apple-app-site-association file for iOS. A browser that opens the link without the app needs a page of its own, the backend's to decide.

## `POST /api/v1/auth/password/reset/check`

`CheckResetTokenRequest { "token": "..." }`, sent without a session token, when the screen opens and before the field shows. `200` with `ResetTokenInfo { email }` for a good link; the app shows the link's own email and doesn't read this one. A link expired, used already or unknown is one answer for all three: `400` with `auth.reset_token_invalid` (`test/fixtures/api/auth_link_invalid.json`), which the app reads as an expired link wherever it comes, not as a form error (`FailureMapper`).

Status: **live**, used (the mock: any token but `expired` is good, and `expired` answers as the server does).

## `POST /api/v1/auth/password/reset`

`ResetPasswordRequest { "token", "newPassword", "deviceId", "platform" }`, sent without a session token. The token works once. Success ends the account's other sessions and answers with a `TokenResponse`, the session that signs the learner in on this phone; a `200` with no tokens means the password changed but no session started, and the learner signs in by hand. `400 auth.reset_token_invalid` as above, `400 validation.failed` naming `newPassword` for a password the server refuses (`test/fixtures/api/auth_password_reset_validation_failed.json`).

Status: **live**, used (the mock answers like register; the token `offline` fails with no connection, and `no-session` answers with no tokens).

## Confirming the email

The first link goes out by itself when an account is made with an email (S §5.3). The app reads the state from `GET /api/v1/app/me` (live: `email`, `emailVerified`), when home opens and on coming back to the app, so confirming on another device is noticed. It shows nothing with no `email` or with `emailVerified: true`, so **accounts from Google and Apple must arrive with `emailVerified: true`**. `UserDto.authMethods` now says how an account signs in; the app doesn't read it yet.

The link is `https://engleazia.com/verify-email?token=<token>`, valid and opening the app like the recovery link (STATUS D-024). All three below are **live**, used:

- `POST /api/v1/auth/email/verify`: `VerifyEmailRequest { "token": "..." }`, sent without a session, as the phone may be signed out. `200`, or `400 auth.reset_token_invalid` for a link expired, used or unknown: the recovery's code, read the same way (`test/fixtures/api/auth_email_verify_link_invalid.json`).
- `POST /api/v1/auth/email/resend`: with the session, no body. Sends the link again (`202`). The app waits 1, 2, then 5 minutes between tries, so the server's limit should allow that; `429` counts as sent. `409` is likely an email confirmed already, which the next read of `/app/me` shows.
- `PUT /api/v1/auth/email`: `ChangeEmailRequest { "newEmail": "..." }`, with the session. Corrects the address and sends a link there (`202`). `409` when it has an account, `400` (`validation.failed`) when refused.

Questions for the backend team: whether correcting the email will ask for the password again after some time (it would need a step the design doesn't draw, STATUS D-052), and whether the 3 days a hidden reminder stays hidden should be a setting of the panel.

## `POST /api/v1/auth/google` and `POST /api/v1/auth/apple`

Live, not used yet: the app's side needs the final application ID, which Google's and Apple's sign-in are bound to (STATUS D-001). Google takes `GoogleSignInRequest { idToken, deviceId, platform }`; Apple takes `AppleSignInRequest { identityToken, authorizationCode, nonce, givenName, familyName, deviceId, platform }`, with `POST /api/v1/auth/apple/callback` for the web flow Android needs. Both answer with a `TokenResponse` whose `isNewUser` says the sign-in made the account, when the onboarding answers belong with it. A refused Google token is `401 auth.google_token_invalid`.

## `POST /api/v1/auth/logout`

Live (docs/api/openapi.json): `{refreshToken}`, sent without the access token. The app calls it on sign-out and never waits on it: signing out works offline, and a failure only means the server forgets the session later. Signing out as a guest loses the account; the app warns first («ستفقد تقدّمك لأنه غير محفوظ في حساب»).

## Questions for the backend team

1. Agree the guest account type: what it may do (everything a learner does?) and how long an unused guest is kept.
2. Agree the upgrade above: the path, that it keeps the same account and progress, the same for Google and Apple sign-up, and what happens when the email already has an account (the app now says so and offers sign-in, which would leave the guest behind; merge instead?).
3. Time zone: the app sends the offset now. For reminders at the learner's time across daylight-saving changes, an IANA name (`Asia/Damascus`) is better; the app can send it once a package is chosen (STATUS D-043).
4. Should onboarding answers go with every account creation (email, Google) in this same `onboarding` shape?
