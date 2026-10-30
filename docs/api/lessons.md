# Lessons

Status: **proposed** — the app runs on this contract in mock mode (`assets/mock/lessons/`); nothing is confirmed by the backend team yet.
Requirements: student doc §7.1 (the exercise container), §7.3 (templates), §2 principle 6.

## `GET /api/v1/app/lessons/{lessonId}/exercises`

A lesson's questions, in the order to show them, with their keys: "check" has to work offline (S §7.1), and the server marks each answer again when it arrives. Needs a session, a guest's or a member's.

### Response `200`

The example is `assets/mock/lessons/exercises.json`.

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "lessonId": "les_mock",
    "questions": [
      {
        "id": "q1",
        "type": "multipleChoice",
        "instruction": { "ar": "اختر الكلمة المناسبة", "en": "Choose the right word" },
        "before": "She",
        "after": "to school every day.",
        "hint": { "text": { "ar": "انتبه إلى الفاعل ", "en": "Look at the subject " }, "term": "she" },
        "options": [{ "id": "o1", "text": "go", "correct": false }]
      }
    ]
  },
  "error": null,
  "traceId": "0HN7…"
}
```

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `questions[].id` | string | Stable question id | yes |
| `questions[].type` | string | `multipleChoice`, `imageChoice`, `listeningChoice`; the app leaves out a type it doesn't know | yes |
| `questions[].instruction` | `{ar, en}` | The line over the question | yes |
| `questions[].before` / `.after` | string | Multiple choice: the sentence around its blank | yes |
| `questions[].word` | string | Image choice: the word the pictures are about | yes |
| `questions[].audioUrl` | string | Image choice: the word said. Listening: the clip. "Slower" plays this file at 0.75 | yes |
| `questions[].hint` | object? | `text` in both languages, then `term`, the English word it points at. None hides the button | yes |
| `questions[].bookReference` | `{ar, en}`? | Imaar lessons tied to a book exercise: "student's book, page 34, exercise 2" | yes |
| `questions[].options[].id` | string | Stable option id | yes |
| `questions[].options[].correct` | bool | The key | yes |
| `questions[].options[].text` | string | English text of a text option | yes |
| `questions[].options[].imageUrl` / `.imageAlt` | string, `{ar, en}` | A picture and its name for screen readers | yes |

**Open with the backend team:**
- Shuffling. The design wants options shuffled per learner with a fixed seed per learner and question. The app shows them in the order they come, so it assumes the server does this.
- Whether a lesson's keys may be sent like this at all, and whether a guest gets them.
- Picture format and sizes; the app takes SVG and any format `Image.network` reads.

### Errors

The common errors (`docs/api/README.md`). With an unknown lesson, `404`.

## `POST /api/v1/app/lessons/{lessonId}/answers`

One checked answer. Safe to repeat: the server ignores an `attemptId` it has seen.

### Request

```json
{
  "attemptId": "6f1c8f60-0000-4000-8000-000000000000",
  "questionId": "q1",
  "optionId": "o2",
  "hinted": true
}
```

| Field | Type | Meaning |
|---|---|---|
| `attemptId` | string | A UUID made on the phone when the answer is checked, the same on every resend |
| `questionId`, `optionId` | string | The answer |
| `hinted` | bool | The hint was opened on this question: a right answer is an assisted success (S §7.1) |

### Response

`200` or `204`; the app reads nothing from it. Marks and XP stay on the server. The app's own marking only drives what the learner sees.
