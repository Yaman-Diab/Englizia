# Lessons

Status: **proposed** — the app runs on this contract in mock mode (`assets/mock/lessons/`); nothing is confirmed by the backend team yet.
Requirements: student doc §7.1 (the exercise container), §7.3 (templates), §2 principle 6; server doc §19.2, §19.3 and §20.6.

The exercise fields are those of the content package (server doc §20.6), under the API's rules (`README.md`): camelCase, lower-camel enum values, absolute media URLs. So `instruction_ar` is `instructionAr`, `book_ref` is `bookRef`, `multiple_choice` is `multipleChoice`.

## `GET /api/v1/app/lessons/{lessonId}`

The published lesson, whole, with its exercises and their keys: "check" has to work offline (S §7.1), and the server marks each answer again when it arrives. Needs a session, a guest's or a member's. The server leaves out questions whose template this app version can't show (server doc §19.2).

### Response `200`

The example is `assets/mock/lessons/lesson.json`.

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "id": "les_mock",
    "version": 1,
    "exercises": [
      {
        "id": "q1",
        "template": "multipleChoice",
        "instructionAr": "اختر الكلمة المناسبة",
        "prompt": { "en": "She ___ to school every day." },
        "options": [{ "id": "o1", "text": "go" }, { "id": "o2", "text": "goes" }],
        "answer": "o2",
        "hint": { "ar": "انتبه إلى الفاعل she" },
        "explanation": { "ar": "مع he/she/it نضيف s للفعل في المضارع البسيط." },
        "concepts": ["c_present_s"],
        "bookRef": null,
        "reviewOnly": false
      }
    ]
  },
  "error": null,
  "traceId": "0HN7…"
}
```

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `id` | string | The lesson | yes |
| `version` | int | The published version; an attempt counts for the version it was answered on (server doc §19.2) | yes, sent with each answer |
| `exercises[].id` | string | Stable question id | yes |
| `exercises[].template` | string | `multipleChoice`, `imageChoice`, `listenChoose`, `fillChoices`, `wordOrder`, `matching`; the rest of §20.6 as they are built. One the app doesn't know is left out | yes |
| `exercises[].instructionAr` | string | The line over the question | yes |
| `exercises[].instructionArAudio` | string? | Required for kids | not yet |
| `exercises[].prompt.en` | string | `multipleChoice`: the sentence with one `___`. `fillChoices`: with one `___` per blank. `imageChoice`: the word | yes |
| `exercises[].prompt.audio` | string | `imageChoice`: the word said (optional). `listenChoose`: the clip. "Slower" plays this file at 0.75 | yes |
| `exercises[].prompt.transcript` | string | `listenChoose`: what the clip says, for the feedback | not yet |
| `exercises[].options[].id` | string | Stable option id | yes |
| `exercises[].options[].text` | string | English text of a text option | yes |
| `exercises[].options[].image` / `.alt` | string | A picture and its Arabic name for screen readers. WebP (S §22) | yes |
| `exercises[].options[].misconception` | string? | The concept a wrong option points to | not yet |
| `exercises[].answer` | string | The right option's id; `wordOrder`: the right sentence | yes |
| `exercises[].blanks[]` | `{answer, alternatives[]}` | `fillChoices`: what each blank takes, in order | yes |
| `exercises[].distractors[]` | `{text, misconception?}` | `fillChoices`, `wordOrder`: the extra cards | yes |
| `exercises[].meaningAr` | string | `wordOrder`: what the guide says | yes |
| `exercises[].chips` | string[]? | `wordOrder`: the sentence as cards; with none, split by spaces | yes |
| `exercises[].alternatives` | string[] | `wordOrder`: other right sentences. Compared without case, punctuation or extra spaces | yes |
| `exercises[].kind` | string | `matching`: `text` or `image` | yes |
| `exercises[].pairs[]` | `{left, right}` or `{left, rightImage, rightAlt}` | `matching`, 3 to 5 pairs. `left` is the English word, unique in its question, and the pair's id. `rightAlt` is the picture's Arabic name for screen readers (server doc §20.6 has no such field: proposed) | yes |
| `exercises[].hint.ar` | string? | The hint. None hides the button. English words in it are shown strong | yes |
| `exercises[].explanation.ar` | string? | For the feedback | not yet |
| `exercises[].concepts` | string[] | For the mistakes bank (v0.5) | not yet |
| `exercises[].bookRef` | `{page, exercise}`? | Imaar lessons tied to a book exercise | yes |
| `exercises[].reviewOnly` | bool | For the mistakes bank only: left out of the lesson | yes |

A question the app can't read is skipped and logged, so it can't leave the learner stuck on the lesson; a lesson with no readable question is a failure with a retry.

**Open with the backend team:**
- Whether a question the app skipped still counts towards completing the lesson (it must not).
- English instructions and hints: the package has only Arabic, so both app languages show Arabic (S §7.1 says "Arabic instructions"), read right to left.
- The order of options is shuffled on the phone, per installation and question (S §7.1), so the server must send them in any order and needs nothing for this.

### Errors

The common errors (`README.md`). With an unknown lesson, `404`.

## `POST /api/v1/app/lessons/{lessonId}/answers`

One checked answer. Safe to repeat: the server ignores an `attemptId` it has seen.

### Request

```json
{
  "attemptId": "6f1c8f60-0000-4000-8000-000000000000",
  "lessonVersion": 1,
  "questionId": "q1",
  "answer": { "optionId": "o2" },
  "hinted": true
}
```

| Field | Type | Meaning |
|---|---|---|
| `attemptId` | string | A UUID made on the phone when the answer is checked, the same on every resend |
| `lessonVersion` | int | The version the learner answered |
| `questionId` | string | The question |
| `answer` | object | By way of answering. Choice templates: `{optionId}`. `fillChoices`: `{words}`, one per blank in order. `wordOrder`: `{words}` as placed. `matching`: `{mistakes}`, the pairs with a mistake on the way, each once, for the question's concept (S §7.3) |
| `hinted` | bool | The hint was opened on this question: a right answer is an assisted success (S §7.1) |

### Errors

The app assumes 400, 404, 409, 410 and 422 mean this answer will never be accepted: it drops it and logs that, so it can't hold back the others. Anything else, it sends again later. To confirm with the backend team.

### Response

`200` or `204`; the app reads nothing from it. Marks and XP stay on the server. The app's own marking only drives what the learner sees; if the two differ, the screen doesn't change, and completion and points follow the server (ADR 11).
