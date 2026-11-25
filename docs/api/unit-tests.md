# A unit's test and the level check

Status: **live, used**, from the backend's note B-33b (2026-11-24) and `docs/api/openapi.json` (`UnitTestAppDto`, `UnitTestResultDto`, `LevelCheckDto`). No test is published on the dev server's demo track yet (its map's `units[].test` is `null`), so no real answer is saved: the tests read the mock's asset, `assets/mock/unit_tests/unit_test.json`, which is in the server's shape, plus a `mockKey` per question and `mockLevels` that only the mock reads.

## On the map

`GET /api/v1/app/enrollments/{trackId}/map` ([home.md](home.md)):

| Field | Shape | In the app |
|---|---|---|
| `units[].test` | `null`, or `{id, questionCount, passPercent, state, bestPercent, retryAvailableAt}`; `state`: `locked`, `available`, `cooldown`, `passed` | The unit's last stone, `unitReview`, done when `passed`; it opens `/unit-tests/{id}`. A unit with a published test is done when its test is passed. Home's lesson counts and preview leave it out |
| `levelCheck` | `null`, or `LevelCheckDto` below | Home's card «انتقل / ابقَ», before a level done and over the email reminder |

## `GET /api/v1/app/unit-tests/{unitTestId}`

`{id, unitId, versionId, versionNo, questionCount, passPercent, state, bestPercent, retryAvailableAt, questions[], media}`. A question is `{versionId, externalId, template, instructionAr, instructionIsDefault, instructionAudioMediaId, body}`, a lesson's question with **no key, hint or explanation**. Templates and bodies are a lesson's ([lessons.md](lessons.md)); the server shuffles the options and cards for this learner, so the app keeps them **in the order they come**.

The questions are put in the app's own shape (`lessonFromUnitTest`) so the exercise screen's bodies show them; with no key, each is given a stand-in one only so a draft can be built, and nothing is marked on the phone.

## `POST /api/v1/app/unit-tests/{unitTestId}/submissions`

The whole test at once, sent only when every question has an answer:

```json
{
  "clientSubmissionId": "a new id per try, the same on every resend",
  "versionId": "the test's versionId",
  "answers": [
    {"questionVersionId": "utq_01", "answer": {"optionId": "b"}},
    {"questionVersionId": "utq_02", "answer": {"gaps": ["feeds"]}},
    {"questionVersionId": "utq_03", "answer": {"chips": ["The", "cow"]}},
    {"questionVersionId": "utq_04", "answer": {"pairs": [1, 2, 0]}}
  ]
}
```

Answers are the sync's (`AttemptAnswerRequest`, [lessons.md](lessons.md)). A matching's `pairs[i]` is the place in `right`, **as it came**, of what `left[i]` was linked to; in a test the learner links freely, each link numbered on both sides, and may link wrongly.

Reply `UnitTestResultDto`: `{submissionId, unitTestId, versionId, correct, questionCount, percent, passed, retryAvailableAt, bestPercent, questions: [{questionVersionId, isCorrect}], lessons, units, levels, levelCheck, serverTime}`. The app shows the percent, the score, a mark per question (no answers or explanations), the pass mark on a fail, the wait before another try counted down, and the level check when there is one. After the result, home asks the map again.

| Error | In the app |
|---|---|
| `422 unit_test.retry_not_yet` + `Retry-After` | Back to the test's start, the wait counted down; the test opens by itself when it is over |
| `422 unit_test.locked`, `404` | The test is read again (a lesson's answers not yet on the server, or the test gone) |
| Anything else | The answers stay, «لم يصل الاختبار. إجاباتك هنا، أرسله مرة أخرى.», and the same try goes again under the same id |

Before reading the test the app sends the lessons' answers waiting on the phone, as the server opens a test only when every lesson of the unit is done.

## `LevelCheckDto` and `POST /api/v1/app/level-checks/{checkId}/choose`

After the first unit's test of a level: `{id, direction: up | down | none, percent, level, suggestedLevel, checkedAt}`, the levels as the map names them. `none` suggests no move and shows nothing. The choice is `{move: true}` («انتقل إلى B1») or `{move: false}` («ابقَ في A2»); the reply (`EnrollmentDto`) isn't read, home asks the map again.

## Not read yet

The result's `lessons`, `units`, `levels` and `serverTime` (the wait counts on the phone's clock), and a question's `instructionAudioMediaId` (docs/STATUS.md D-127).
