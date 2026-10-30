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

Every state also carries `enrollmentId`, the learner's enrollment in the track, which the app needs to put the test off. **The app assumes this field**: nothing else gives it the id.

| `state` | Other fields | Screen |
|---|---|---|
| `none` | — | First test |
| `inProgress` | `stage`, `question` (both from 1) | "You stopped at question 9 of the first stage": continue or start over |
| `retakeAvailable` | `lastLevel` (CEFR), `daysSinceResult` | "Your last result: A2, 34 days ago": take it again |
| `retakeLocked` | `daysUntilRetake` | "You can take the test again in 12 days": button disabled |

The server counts the days, as it knows the wait (30 days by default, from the panel) and its clock is the one that counts. A state the app doesn't know reads as `none`, since the server still decides what starting means. A known state with its fields missing is an error.

The app saves the last response on the phone, with when it was saved. With no connection the intro shows that state, adding the days passed to `daysSinceResult` and taking them from `daysUntilRetake` (never under 1: only the server can say the wait is over). It is forgotten when a session starts or ends, so it never reaches another account.

Status: **proposed**, mock (`assets/mock/placement/status_*.json`).

## `POST /api/v1/app/placement/attempts`

Opening the questions sends `{}`: the attempt to carry on with, the unfinished one or a new one. «ابدأ من جديد» first sends `{ "restart": true }`, which throws away the unfinished test.

```json
{ "attemptId": "att_1", "stageSizes": [12, 15], "stage": 1, "answered": 8 }
```

`stageSizes` holds the stages known so far, `stage` the one to carry on with (from 1), and `answered` how many of its questions the server has. The server picks the form (A or B) and pins the published version here.

Status: `restart` given by the owner from the backend guide, **unconfirmed**; the rest **proposed**, mock.

## `GET /api/v1/app/placement/attempts/{id}/stages/{n}`

All the questions of a stage at once, so it can't stop halfway for lack of a connection. **No answer keys, ever** (S §12.1). Options come in the order to show them, already shuffled for this learner.

```json
{
  "stage": 1,
  "questions": [
    { "id": "q1", "type": "vocabulary", "before": "I usually", "after": "breakfast at seven.",
      "options": [{ "id": "o1", "text": "have" }] },
    { "id": "q3", "type": "reading", "passage": "…", "ask": "Why did Omar leave work early?", "options": [] },
    { "id": "q4", "type": "listening", "audioUrl": "https://…", "maxPlays": 2, "ask": "What time does the train leave?", "options": [] }
  ]
}
```

`type` is `vocabulary`, `grammar`, `reading` or `listening`; the app writes each one's instruction itself. `maxPlays` comes from the test's version. A type the app doesn't know fails the whole stage.

Status: **proposed**, mock (`assets/mock/placement/stage_*.json`).

## `POST /api/v1/app/placement/attempts/{id}/answers`

One answer, sent when given, and again until it arrives: `{ "answerId", "questionId", "optionId", "dontKnow", "plays" }`. `answerId` is made on the phone and stays the same, **so a repeat must not count twice**. `optionId` is null with `dontKnow: true`. `plays` is how often the clip was played.

Status: **proposed**, mock.

## `POST /api/v1/app/placement/attempts/{id}/stages/{n}/complete`

Sent when a stage's answers have all arrived. The server marks it and answers with what follows, with no score:

```json
{ "next": { "stage": 2, "questionCount": 15, "listeningCount": 4, "deciding": false } }
```

`deciding: true` is the short stage on the edge of two levels. `"next": null` means the test is over and its result is ready. It must be safe to repeat, as the response can be lost.

Status: **proposed**, mock.

## `PATCH /api/v1/app/enrollments/{id}`

«ابدأ من البداية دون اختبار»: `{ "placement_state": "deferred" }` starts the learner from the track's first level, with the test still available from "Me". The app then goes home. `{id}` is `enrollmentId` from the status above.

Status: given by the owner from the backend guide, **unconfirmed** by the backend developer, mock.

## Questions for the backend team

1. Confirm the path and field names, and that it is available without a token.
2. Confirm `stages` counts the mandatory stages only, and the error for "no published version".
3. Confirm the attempt's endpoints above, and that the status's `question` and the attempt's `answered` agree: the app continues from `answered` plus what it hasn't sent yet.
4. Confirm the two actions above, with these details the app assumed: the `/api/v1/app/` prefix on both paths; where `enrollmentId` comes from (assumed: the status response); and `placement_state`, which is snake_case where every other field in the API is camelCase.
