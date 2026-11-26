# A unit's test and the level check

Status: **live, used**, from the backend's note B-33b (2026-11-24), its answers of 2026-11-26 and `docs/api/openapi.json` (`UnitTestAppDto`, `UnitTestResultDto`, `LevelCheckDto`). Two tests are published on the dev server's track "General English (demo)": the first unit of A1 and of A2, six questions each, one of each template. Real answers, taken by calling the server as two new guests (2026-11-26): `test/fixtures/api/app_unit_test_*.json`, `app_level_check_*.json` and `app_map_test_*.json`. Mock mode reads `assets/mock/unit_tests/unit_test.json`, in the server's shape, plus a `mockKey` per question and `mockLevels` that only the mock reads.

## On the map

`GET /api/v1/app/enrollments/{trackId}/map` ([home.md](home.md)):

| Field | Shape | In the app |
|---|---|---|
| `units[].test` | `null`, or `{id, questionCount, passPercent, state, bestPercent, retryAvailableAt}`; `state`: `locked`, `available`, `cooldown`, `passed` | The unit's last stone, `unitReview`, with no title of its own; it opens `/unit-tests/{id}`. Done when `passed`, or when `bestPercent` reaches `passPercent`: a passed test may be taken again, and a try that then fails puts it in `cooldown` with its best kept. A unit with a published test is done when its test is passed. Home's lesson counts and preview leave it out |
| `levelCheck` | `null`, or `LevelCheckDto` below, for as long as the check is open | Home's card «انتقل / ابقَ», before a level done and over the email reminder |

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

**The same try sent again** (its reply lost) answers `200` with the result kept, whatever the answers now sent: no `422`, no second try, no new wait. Its `lessons`, `units` and `levels` are then empty, and `levelCheck` is that try's check if it is still open. A new try after a fail is a new `clientSubmissionId`.

**The wait** is ten minutes after a failed try, `retryAvailableAt` on the server's clock. The app counts it on that clock, not the phone's (`ServerClock`): each answer's `Date` header and the result's `serverTime` say what time the server has, and the phone only counts on from there, so a phone set to the wrong time waits as long as any other. The server is the judge all the same: a try sent early is refused with the seconds left in `Retry-After`, which the count then starts from.

| Error | In the app |
|---|---|
| `422 unit_test.retry_not_yet` + `Retry-After` | Back to the test's start, the wait counted down; the test opens by itself when it is over |
| `422 unit_test.locked` (reading it too), `404` | The test is read again (a lesson's answers not yet on the server, or the test gone) |
| Anything else | The answers stay, «لم يصل الاختبار. إجاباتك هنا، أرسله مرة أخرى.», and the same try goes again under the same id |

Before reading the test the app sends the lessons' answers waiting on the phone, as the server opens a test only when every lesson of the unit is done.

## `LevelCheckDto` and `POST /api/v1/app/level-checks/{checkId}/choose`

`{id, direction: up | down | none, percent, level, suggestedLevel, checkedAt}`, the levels as the map names them. `none` suggests no move and shows nothing. The choice is `{move: true}` («انتقل إلى B1») or `{move: false}` («ابقَ في A2»); the reply (`EnrollmentDto`) isn't read, home asks the map again.

The check is made **once for each placement test**, by the first try of the first unit's test of the level the placement put the learner in, pass or fail (the backend's answers of 2026-11-26):

| That first try | `direction` |
|---|---|
| 85% or more | `up`, to the next published level |
| 50% to 84% | no check |
| Under 50% | `down`, to the published level before |

The percent isn't rounded (42 of 50 is 84%: no check). The numbers are the server's alone, later the panel's (B-26): the app shows the direction and the levels it is sent, and holds none of them. The requirements' "40% or less" (S §12.3) is 50% on the server, by the backend's decision of 2026-11-24. An account placed before 2026-11-24 is never checked.

The check stays open, on the map and in the result of the try that made it, with no time limit, until the learner chooses, leaves the level checked (finished it and moved on), or the level suggested is no longer published. Then the map has `levelCheck: null`, and a choice is refused:

| Error | In the app |
|---|---|
| `422 level_check.already_chosen`, `422 level_check.closed`, `404 level_check.not_found` | As a choice made: the card goes, and home asks the map again |
| Anything else | «تعذّر…» as any failure, the card stays |

## Questions for the backend team

1. The app sets its count of the server's time by each answer's `Date` header, which on the dev server is the second of the body's `serverTime`. Will it stay the API's own clock in production (behind a proxy or a CDN)? If not, the app will ask `GET /api/v1/app/system/ping` instead.
2. An open test's options came in the content's own order for one guest (the key first in each question), and its cards shuffled. Are options shuffled for each learner, as the note says?

## Not read yet

The result's `lessons`, `units` and `levels` (home asks the map again), and a question's `instructionAudioMediaId` (docs/STATUS.md D-127).
