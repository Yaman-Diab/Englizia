# Placement test

Status: **proposed** — the app runs on this contract in mock mode (`assets/mock/placement/`); nothing is confirmed by the backend team yet.
Requirements: student doc §4.2 (the "how much English do you know?" step) and §12, server doc §12 and §19.3.

## `GET /api/v1/app/placement/summary`

The published placement test as it is introduced to the learner, before any question is loaded. Used by the onboarding level step, "preparing" and the test's intro screen. Available without a token, since onboarding runs before sign-up. Answer keys never reach the app; this endpoint carries no questions.

### Response `200`

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "version": "2026.1",
    "estimatedMinutes": { "min": 12, "max": 15 },
    "stages": 2,
    "optionalStage": true
  },
  "error": null,
  "traceId": "0HN7…"
}
```

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `version` | string | Published test version (results are stored against it) | not yet |
| `estimatedMinutes.min` / `.max` | int | Estimated duration, computed by the server from the question count at about 25 s per question (server doc §12.5) | yes ("12–15 دقيقة") |
| `stages` | int | Stages every learner takes: routing, then a block | yes ("مرحلتان…") |
| `optionalStage` | bool | Whether a short deciding stage may be added at a boundary | yes ("…وقد تُضاف مرحلة ثالثة قصيرة") |

### Errors

The common errors (`docs/api/README.md`). With no published test version, `404` with code `placement_unavailable`; the app then hides the test and offers a start from the first level.

## `GET /api/v1/app/placement/status`

Where this account stands with the test, for the test's intro (S §12.2). Needs a session, a guest's or a member's.

| `state` | Other fields | Screen |
|---|---|---|
| `none` | — | First test |
| `inProgress` | `stage`, `question` (both from 1) | "You stopped at question 9 of the first stage": continue or start over |
| `retakeAvailable` | `lastLevel` (CEFR), `daysSinceResult` | "Your last result: A2, 34 days ago": take it again |
| `retakeLocked` | `daysUntilRetake` | "You can take the test again in 12 days": button disabled |

The server counts the days, as it knows the wait (30 days by default, from the panel) and its clock is the one that counts. A state the app doesn't know reads as `none`, since the server still decides what starting means. A known state with its fields missing is an error.

Status: **proposed**, mock (`assets/mock/placement/status_*.json`).

## Still to agree, with the questions screen

- Starting over: dropping the unfinished test, so the next start begins a new one.
- Skipping («ابدأ من البداية دون اختبار»): placing the learner at the track's first level, with the test still available from "Me" (STATUS D-049).

## Questions for the backend team

1. Confirm the path and field names, and that it is available without a token.
2. Confirm `stages` counts the mandatory stages only, and the error for "no published version".
