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

## Questions for the backend team

1. Agree the guest account type: what it may do (everything a learner does?) and how long an unused guest is kept.
2. Agree the upgrade: signing up (email, Google, Apple) while holding a guest token turns that guest into the member account, keeping progress. Which endpoint, and what if the email already has an account (merge, or ask)?
3. Time zone: the app sends the offset now. For reminders at the learner's time across daylight-saving changes, an IANA name (`Asia/Damascus`) is better; the app can send it once a package is chosen (STATUS D-043).
4. Should onboarding answers go with every account creation (email, Google) in this same `onboarding` shape?
