# Placement test

Status: **proposed** — the app runs on this contract in mock mode (`assets/mock/placement/`); nothing is confirmed by the backend team yet.
Requirements: student doc §4.2 (the "how much English do you know?" step) and §12, server doc §12 and §19.3.

## `GET /api/v1/app/placement/summary`

The published placement test as it is introduced to the learner, before any question is loaded. Used by the onboarding level step (and later the test's intro screen). Available without a token, since onboarding runs before sign-up. Answer keys never reach the app; this endpoint carries no questions.

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

## Questions for the backend team

1. Confirm the path and field names, and that it is available without a token.
2. Confirm `stages` counts the mandatory stages only, and the error for "no published version".
