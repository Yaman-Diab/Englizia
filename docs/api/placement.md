# Placement test

Status: **live** on the dev server (docs/api/openapi.json), with a published demo version on the track "General English (demo)": every one of its questions starts with `[demo]`. The app uses all five requests. Real answers: `test/fixtures/api/app_placement_*.json`; mock mode goes through the same answers (`assets/mock/placement/`).
Requirements: student doc §4.2 and §12, server doc §12 and §19.3. The backend's note N-3b (2026-11-20) is the reference for what follows.

The test and its result are the account's, one for the platform; each request names a `trackId` so the server knows the enrollment and the track's levels. Only a track whose `entryMode` is `placement` has one: kids, Emar and direct tracks don't. A learner joins with `"start": "placement"` (onboarding or `POST /api/v1/app/enrollments`) and starts at the first level with `placementPending: true`. The app takes the track onboarding chose, else the active enrollment (`GET /api/v1/app/enrollments`, `isActive`).

Two stages, 12 questions then 15, and a deciding third of 8 when the result falls between two levels. **A stage goes to the server when it ends**, whole; until then its answers stay on the phone, and the server knows nothing of a stage not sent. Nothing of the test goes through `POST /api/v1/app/sync`. The server marks: the phone never gets the right answer nor a question's level. Every call needs an account (a guest's too); before one exists the app asks nothing.

## `GET /api/v1/app/placement?trackId=`

Where the account stands, read by the intro (3.01), "preparing", the result (3.07) and the home's notices (15.22).

```json
{ "trackId": "…", "state": "available", "reason": null,
  "test": { "versionNo": 1, "listenCount": 2,
            "questionCount": { "withoutTiebreak": 27, "withTiebreak": 35 },
            "estimatedSeconds": { "withoutTiebreak": 675, "withTiebreak": 875 } },
  "isRetake": false, "session": null, "result": null, "retakeAvailableAt": null }
```

| `state` | When | The app |
|---|---|---|
| `available` | A first test, or a retake (`isRetake: true`, with the last `result`) | The intro: what the test takes from `test` (minutes from `estimatedSeconds`, without then with the deciding stage), or the last result and how long ago |
| `in_progress` | A session not finished: `session: {id, stage}` | «تابع الاختبار», at the question the phone got to in that stage |
| `result` | Finished, and the learner hasn't chosen where to start | «اعرض نتيجتك»: the result opens until they choose |
| `done` | Chosen; `retakeAvailableAt` 30 days after the result | A retake waits until then |
| `unavailable` | `reason: track_not_placement` or `no_published_version` | Nothing of the test is shown |

A missing `trackId` is `400`; a track not joined `404 enrollment.not_found`. With no connection the app shows the state it last kept (its dates are absolute, so the days still count).

«ابدأ من البداية دون اختبار» sends nothing: the learner is already at the first level, and `placementPending` stays `true`.

## `POST /api/v1/app/placement/sessions`

«ابدأ الاختبار»: `{ "trackId": "…" }`. `201` with a new session at stage 1, or `200` with the running one (two taps give one session). A retake takes the other form (`form: a`, `b`, `a`…). Before 30 days: `409 placement.retake_not_yet`.

## `GET /api/v1/app/placement/sessions/{sessionId}`

The session, to carry on after a stop; the same body comes from «ابدأ» and from each stage.

```json
{ "id": "…", "status": "in_progress", "versionNo": 1, "form": "a", "isRetake": false, "listenCount": 2,
  "stage": 1, "block": "routing",
  "questions": [
    { "id": "…", "skill": "vocabulary", "template": "multiple_choice",
      "instructionAr": "اختر الكلمة المناسبة", "instructionAudioMediaId": null,
      "prompt": "I drink ___ every morning.", "passage": null, "audioMediaId": null,
      "options": [ { "id": "a", "text": "milk" }, "…" ] } ],
  "media": { "019a…": { "kind": "audio", "url": "https://api-dev.engleazia.com/media/audio/…mp3", "sizeBytes": 8847 } },
  "result": null }
```

| Field | The app |
|---|---|
| `skill` | `vocabulary`, `grammar` (the sentence split at its `___`), `reading` (its `passage`, 3.04), `listening` (its `audioMediaId`, 3.05) |
| `template` | `multiple_choice` or `listen_choose`, four options `a`–`d`; anything else can't be shown, and the stage fails |
| `options` | Shuffled by the phone, the same for this phone each time (no `correct`, `transcript` or `cefr` comes) |
| `instructionAr` | Shown as it is in Arabic; the app's own words in English |
| `listenCount` | How often a clip may play; the phone counts and keeps the listens |
| `media` | Each file once, by id. Its links are public, with no token, and don't run out |
| `block` | Not shown |

How many questions each stage has, for the progress bar: the stage's own `questions`, and the test's totals for the others.

## `POST /api/v1/app/placement/sessions/{sessionId}/stages/{stage}`

The stage's answers, one for each of its questions; «لا أعرف» is `dontKnow` and counts as wrong:

```json
{ "answers": [ { "questionId": "…", "optionId": "b" }, { "questionId": "…", "dontKnow": true } ] }
```

`200` with the session as it now stands: `in_progress` with the next stage and all its questions (3.06 says how many, and how many listening), or `completed` with `result` (below). A stage sent before (the answer lost, and sent again) is safe: `200` with the session as it is, the new answers ignored. `409 placement.stage_not_current` (a later stage, or a finished session): the app reads the session and goes on from it. `400 validation.failed` is a bug in the app and keeps nothing: `answers` empty or over 15, an option not `a`–`d`, both or neither of `optionId` and `dontKnow`, a question of the stage with no answer (`questions[{id}]`, `missing`), or one not of the stage or twice.

## The result (3.07)

After the last stage the session is `completed`, its `stage`, `block` and `questions` empty, and `result: {cefr, completedAt, skills[], strongestSkill}`. The levels to start from are the track's, so the app reads them from `GET /api/v1/app/placement?trackId=`:

```json
"result": { "sessionId": "…", "cefr": "a2", "completedAt": "…", "versionNo": 1, "form": "a", "isRetake": false,
            "level":      { "id": "…", "nameAr": "المستوى الثالث", "nameEn": "A2", "cefrCode": "a2", "gradeNumber": null },
            "lowerLevel": { "id": "…", "nameAr": "المستوى الثاني", "nameEn": "A1", "cefrCode": "a1", "gradeNumber": null },
            "skills": [ { "skill": "vocabulary", "correct": 7, "total": 9, "percent": 78 }, "…" ], "strongestSkill": "vocabulary" },
"retakeAvailableAt": "…"
```

| From | In 3.07 |
|---|---|
| `cefr` (`pre_a1`…`b2`) | Where the guide stands on the ladder, Pre-A1 to B2, drawn by the app |
| «تستطيع أن…» | The app's own three sentences for each step, not the server's (the final ones aren't written yet: STATUS D-122) |
| `skills`, in their order | «مهاراتك», as bars against one another, never a number; the strongest and the weakest marked |
| `level` | «ابدأ من …», named as the track names it. A `pre_a1` result starts at the track's first level |
| `lowerLevel` | «ابدأ من مستوى أقل»; none (`null`) hides it |

A learner who closes 3.07 without choosing finds it again (`state: result`).

## `POST /api/v1/app/placement/sessions/{sessionId}/choose`

`{ "trackId": "…", "choice": "result" }` or `"lower"`. `200` with the enrollment (`EnrollmentDto`): the new level, `entryMethod: "placement"`, `placementPending: false`; the state becomes `done`, and choosing again with the same session is allowed. The first level's progress stays. The track's map (`GET /api/v1/app/enrollments/{trackId}/map`) changes with the level; the app doesn't read it yet. A second placement track joined later shows the same result with its own levels, and is chosen with its own `trackId`, with no new test.

| Code | Status | When | The app |
|---|---|---|---|
| `placement.session_not_completed` | 409 | Before the last stage | Reads the session and goes on |
| `placement.session_not_latest` | 409 | An older session than the latest result | Chooses with `result.sessionId` from the state |
| `placement.no_lower_level` | 422 | `lower` with none | The link isn't shown when `lowerLevel` is null |

## Other codes

| Code | Status | When | The app |
|---|---|---|---|
| `placement.session_not_found` | 404 | No such session, or another learner's | Reads the state |
| `placement.track_not_placement` | 422 | A track with no test | Shows no test |
| `placement.not_available` | 422 | No published version | Shows no test |
| `enrollment.not_found` | 404 | The track isn't joined | — |
| `enrollment.level_not_available` | 422 | The track has no published level | — |

Deleting the account, and a guest signing out, deletes its sessions and answers.

## Questions for the backend team

1. «ابدأ من جديد» on an unfinished test (S §12.2, the design "Placement Intro"): there is no way to throw a session away, so the app offers only «تابع الاختبار» and the lessons (STATUS D-121). Is a restart planned?
2. The onboarding step "how much English" comes before the account exists, so it can't say how long the test takes. Could `system/config` carry the published test's `estimatedSeconds`?
3. `GET /api/v1/app/tracks` lists no levels for the General English (demo) track (`levels: []`): are a CEFR track's levels left out on purpose?
