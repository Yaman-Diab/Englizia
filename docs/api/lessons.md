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
| `xpPerAnswer` | int? | What a right answer earns, from the panel's table (v1.0). None before then: the feedback shows no badge. Proposed: the package has no such field | yes |
| `speechPassPercent` | int | The share of words to hear in `repeatSentence`, after inheritance (server doc §17). Without it such a question is skipped | yes |
| `typoMinLetters` | int | How long a word must be for a slip of one letter (server doc §10.5). Without it none is accepted | yes |
| `explainEnabled` | bool | «اشرح لي» is on, by the track's settings and the day's limit (S §16). Proposed | yes |
| `exercises[].id` | string | Stable question id | yes |
| `exercises[].template` | string | `multipleChoice`, `imageChoice`, `listenChoose`, `fillChoices`, `wordOrder`, `matching`, `repeatSentence`, `listenWrite`, `fillTyped`, `sentenceOrder`, `spelling`; the rest of §20.6 as they are built. One the app doesn't know is left out | yes |
| `exercises[].instructionAr` | string | The line over the question | yes |
| `exercises[].instructionArAudio` | string? | Required for kids | not yet |
| `exercises[].prompt.en` | string | `multipleChoice`: the sentence with one `___`. `fillChoices`: with one `___` per blank. `imageChoice`: the word | yes |
| `exercises[].prompt.audio` | string | `imageChoice`: the word said (optional). `listenChoose`: the clip, which "Slower" plays at 0.75. The other templates: the right sentence said, for the feedback (optional; none hides its button) | yes |
| `exercises[].prompt.transcript` | string | `listenChoose`: what the clip says, for the feedback | yes |
| `exercises[].options[].id` | string | Stable option id | yes |
| `exercises[].options[].text` | string | English text of a text option | yes |
| `exercises[].options[].image` / `.alt` | string | A picture and its Arabic name for screen readers. WebP (S §22) | yes |
| `exercises[].options[].misconception` | string? | The concept a wrong option points to | not yet |
| `exercises[].answer` | string | The right option's id; `wordOrder`: the right sentence | yes |
| `exercises[].blanks[]` | `{answer, alternatives[]}` | `fillChoices`: what each blank takes, in order | yes |
| `exercises[].distractors[]` | `{text, misconception?}` | `fillChoices`, `wordOrder`: the extra cards; `errorCorrection`: the wrong corrections | yes |
| `exercises[].meaningAr` | string | `wordOrder`: what the guide says | yes |
| `exercises[].chips` | string[]? | `wordOrder`: the sentence as cards; with none, split by spaces | yes |
| `exercises[].alternatives` | string[] | `wordOrder`: other right sentences. Compared without case, punctuation or extra spaces | yes |
| `exercises[].source` | `{text, audio}` | `repeatSentence`: the sentence and its sound. The package may point at a sentence of the lesson (`sentence_id`): the server resolves it | yes |
| `exercises[].accepted` | string[] | `listenWrite`, `fillTyped`, `translation`: right answers, compared without case, punctuation or extra spaces (S §7.4). The first is shown to a learner who got it wrong | yes |
| `exercises[].typoTolerance` | bool | `listenWrite`, `fillTyped`, `translation`: accept one wrong letter in a long enough word | yes |
| `exercises[].prompt.baseWord` | string | `fillTyped`: the word in brackets after the blank | yes |
| `exercises[].sentences` | string[] | `sentenceOrder`: in the right order; the app shuffles them | yes |
| `exercises[].word`, `.image`, `.alt` | string | `spelling`: the word, its picture and the picture's Arabic name. The package points at the lesson's vocabulary (`word_ref`): the server resolves it. Proposed | yes |
| `exercises[].distractorLetters` | string[] | `spelling`: the extra letters | yes |
| `exercises[].prompt.ar` | string | `translation`: the sentence to translate | yes |
| `exercises[].prompt.tokens[]` | `{id, text}` | `errorCorrection`: the sentence's words, in order | yes |
| `exercises[].wrongTokenId`, `.correction` | string | `errorCorrection`: the wrong word and what replaces it | yes |
| `exercises[].character` | `{name, avatar?}` | `dialogueCompletion`: with no avatar the app shows the name's first letter | yes |
| `exercises[].lines[]` | `{speaker: "character", text}` or `{speaker: "student", blank: true}` | `dialogueCompletion`: the conversation, with one line for the learner | yes |
| `exercises[].title`, `.passage`, `.audio` | string | `reading`: the text. Server doc §20.6 has `title_ar`, but the design's title is English: proposed, and open | yes |
| `exercises[].questions[]` | `{id, prompt: {en}, options[], answer, hint?, explanation?}` | `reading`, 2 to 5: each is a step of its own, checked alone. `id` is the `questionId` of its answer, so it must be unique in the lesson | yes |
| `exercises[].prompt.en`, `.audio` | string | `speakAnswer`: the question and its sound. `criterion`, `modelAnswer` and `watchedConcepts` stay on the server | yes |
| `exercises[].kind` | string | `matching`: `text` or `image` | yes |
| `exercises[].pairs[]` | `{left, right}` or `{left, rightImage, rightAlt}` | `matching`, 3 to 5 pairs. `left` is the English word, unique in its question, and the pair's id. `rightAlt` is the picture's Arabic name for screen readers (server doc §20.6 has no such field: proposed) | yes |
| `exercises[].hint.ar` | string? | The hint. None hides the button. English words in it are shown strong | yes |
| `exercises[].explanation.ar` | string? | Why, for the feedback after a wrong answer; a paragraph per line | yes |
| `exercises[].reviewOrders` | string[] | `wordOrder`: orders that are neither known right nor plainly wrong, which go to the server to judge (design `Exercise Feedback`). Proposed, and open: see below | yes |
| `exercises[].concepts` | string[] | For the mistakes bank (v0.5) | not yet |
| `exercises[].bookRef` | `{page, exercise}`? | Imaar lessons tied to a book exercise | yes |
| `exercises[].reviewOnly` | bool | For the mistakes bank only: left out of the lesson | yes |

The top of a lesson also says where it sits, so its end can show that offline (design `Lesson Complete`). All proposed, and all optional: what is missing isn't shown.

| Field | Type | Meaning |
|---|---|---|
| `title` | string | The lesson's name |
| `alreadyCompleted` | bool | The learner had finished it before |
| `unit` | `{number, title, lessons: [{id, kind, done}]}` | The unit's chain. `kind`: `vocabulary`, `interactiveVideo`, `grammarVideo`, `interactiveText`, `conversation`, `unitReview` |
| `next` | `{kind, lessonId?, lessonKind?, title?, unitNumber?}` | What comes after. `kind`: `lesson`, `unitReview`, `unit`. None at the end of a track |

A grammar lesson also has `content`, and `bookRef` for one tied to a book (design `Grammar Video`, S §8.1). All proposed.

| Field | Type | Meaning |
|---|---|---|
| `content.kind` | string | `grammarVideo` |
| `content.requiredWatchPercent` | int | Of the video really watched, from the panel. Required |
| `content.exercisesOpen` | bool | The server lets the learner on without watching, as when the video is gone for good (S §8.1) |
| `content.questionsEnabled` | bool | By track, level and lesson; never for kids |
| `content.teacher` | `{name, avatar?}` | |
| `content.video` | object? | None: a lesson with no video, whose exercises are open from the start |
| `content.video.id` | string | Changes when the video is replaced: the learner starts it over |
| `content.video.durationSeconds` | int | |
| `content.video.cover` | string? | |
| `content.video.sources[]` | `{quality, url, sizeMb?}` | `quality`: `auto`, `low`, `medium`, `high`. HLS or MP4; the app reopens at the same place when it changes |
| `content.video.captions[]` | `{fromMs, toMs, ar}` | The panel's VTT file, already read, so the phone has no parser to keep |
| `content.summary` | `{ar, table[], examples[]}` | Required. `table[]`: `{left, right: [part]}`. `examples[]`: `{en: [part], ar, audio?}`. A part is `{text, strong?, marked?}` |
| `content.watch` | as below | What the server last heard, from any phone |

An interactive text has `reader` (design `Interactive Text`, S §8.2–§8.3). An interactive video will share it, with its video as the time. All proposed.

| Field | Type | Meaning |
|---|---|---|
| `reader.audio` | `{url, durationMs}` | The whole text's sound. Required |
| `reader.sentences[]` | `{id, ar, words[], image?, imageAlt?, speaker?, shadowing?}` | In order. `shadowing`: practised after the text; with none, the text goes on to the exercises |
| `reader.sentences[].words[]` | `{id, text, startMs, endMs, gloss?}` | Punctuation stuck to its word (`leave.`). `gloss`: its meaning when it is in no span; with none, pressing it shows nothing, as no AI is asked |
| `reader.spans[]` | `{id, sentenceId, wordIds[], kind, base, ar, note?, noteExample?}` | `kind`: `word`, `phrasalVerb`, `idiom`. Words side by side or not, in one sentence, and no word in two spans. `noteExample[]`: `{text, strong?}`, shown under the note |

`aiReviewEnabled` (top level, bool) says whether the AI may judge in this lesson, by the track's settings and the learner's age: with it off, or absent, the app leaves out `speakAnswer` questions, uncounted (S §16.2). Proposed.

A question the app can't read is skipped and logged, so it can't leave the learner stuck on the lesson; a lesson with no readable question is a failure with a retry.

**Open with the backend team:**
- Judging word orders with AI. The design sends some orders to AI, but S §16 and server doc §19.5 list no such use: they accept saved alternatives only (S §7.3). The app does what the design shows; with no `reviewOrders` nothing is ever sent.
- A reading's title: `title_ar` in the package, English in the design.
- Whether a question the app skipped still counts towards completing the lesson (it must not).
- English instructions and hints: the package has only Arabic, so both app languages show Arabic (S §7.1 says "Arabic instructions"), read right to left.
- The order of options is shuffled on the phone, per installation and question (S §7.1), so the server must send them in any order and needs nothing for this.

### Errors

The common errors (`README.md`). With an unknown lesson, `404`.

## `POST /api/v1/app/lessons/{lessonId}/reports`

"A problem with this question" (S §18), kept on the phone and sent like an answer. The app's version and platform go in every request's headers.

```json
{
  "reportId": "6f1c8f60-0000-4000-8000-000000000001",
  "lessonVersion": 1,
  "questionId": "q1",
  "reason": "audio",
  "answer": { "optionId": "o2" }
}
```

`reason` is `alsoRight`, `audio`, `question`, `translation` or `other`. `reportId` makes it safe to repeat. Proposed.

## `POST /api/v1/app/lessons/{lessonId}/answers/review`

Asks the server to judge an order in `reviewOrders`, with the same body as an answer, while the learner waits. `200` with `{ "correct": true }`. On any failure the learner reads "we'll check it later, and it won't count as wrong", and the server judges it when it can (S §16.3). Proposed.

## `POST /api/v1/app/lessons/{lessonId}/words`

The star on a span, kept on the phone and sent like an answer. Proposed.

```json
{ "spanId": "turnoff", "saved": true, "base": "turn off", "kind": "phrasalVerb", "ar": "...", "note": "...", "sentence": { "en": "...", "ar": "..." } }
```

Saving sends the span whole, so changing it in the panel later doesn't change what was saved (S §8.2). Taking it back sends `{spanId, saved: false}`.

## `POST /api/v1/app/lessons/{lessonId}/content-done`

`{lessonVersion}`, once the end of a text is reached, which is what completes it (S §8.3). Kept on the phone and sent like an answer, and safe to repeat. Proposed.

## `POST /api/v1/app/lessons/{lessonId}/watch`

How much of the video was really watched, kept on the phone and sent like an answer. Only the latest counts, so a newer one replaces any still waiting. Proposed.

```json
{ "videoId": "vid_1", "lessonVersion": 1, "positionSeconds": 134, "watched": [[0, 120], [200, 214]] }
```

`watched` is `[from, to)` in seconds, counted from what played: moving the bar adds nothing. The server should take the union, and decide completion from it (S §7.6).

## `GET /api/v1/app/lessons/{lessonId}/questions`

**Only the caller's own questions on this lesson, and the replies to them, newest first. The server must enforce this: no other learner's question may ever appear in this response (ADR 14).** Proposed.

```json
[
  {
    "questionId": "6f1c8f60-0000-4000-8000-000000000003",
    "text": "...",
    "askedAt": "2026-11-01T08:00:00Z",
    "videoSeconds": 134,
    "reply": { "name": "...", "role": "teacher", "text": "..." }
  }
]
```

`role` is `teacher` or `admin`. `videoSeconds` and `reply` are optional.

## `POST /api/v1/app/lessons/{lessonId}/questions`

`{questionId, text, videoSeconds?}`, and answers with the question as above, including `askedAt`. `questionId` is made on the phone and the same on every try, so a repeat keeps one question. A reply should notify only this learner (S §17). Proposed.

Open with the backend team: the panel's questions page (SV §9.1) was designed around public questions; moderation by report and block no longer applies, as nothing is shown to other learners.

## `POST /api/v1/app/lessons/{lessonId}/complete`

The last question is done. Sent after the lesson's answers, and returns the official numbers (S §7.6). Proposed.

```json
{ "completionId": "6f1c8f60-0000-4000-8000-000000000002", "lessonVersion": 1, "seconds": 420 }
```

`completionId` is the same on every try, and a repeat must answer the same numbers. When the server can't be reached the completion waits on the phone with the answers, and goes when it can; the screen shows "counted when online", and the numbers reach the learner later (Home).

| Response field | Type | Meaning |
|---|---|---|
| `xp` | int? | Points earned. None: no points shown. A lesson done again follows the server's table |
| `firstTry` | `{right, total}`? | The first answer of each question, without skipped speech questions. None: as the phone counted |
| `seconds` | int? | The lesson's time. None: as the phone counted |
| `pendingReviews` | int? | Questions waiting for AI, not counted as wrong |
| `wordsSaved` | int? | Words this lesson saved. The list's screen isn't built |
| `concepts` | string[] | Up to two to review, by their Arabic names from the panel |
| `goal` | `{before, now, target}`? | Minutes today. `target` from the panel |
| `streak` | `{before, now}`? | Days in a row |
| `unit`, `next` | as in the lesson | The chain and what comes next, now that this one is done |
| `replay` | bool? | Done before: the title says "reviewed" and the chain stays |

Open with the backend team: what counts as completing a lesson with content before its exercises (S §7.6: 80% of a video and so on) is the server's, and needs the watching reported somewhere; no endpoint exists for that.

## `POST /api/v1/app/lessons/{lessonId}/answers/spoken-review`

The learner's own words on a `speakAnswer` question, judged by the server's AI while they wait, with the same body as an answer. Only the words are sent, never a recording. The app holds no AI key (S §16.3). Proposed.

| `outcome` | With | The app |
|---|---|---|
| `answered` | `note`, `better?`, and `misconceptions[]` for the server's own use | Shows the note and the better form, and moves on |
| `offTopic` | `note` | Neutral: another try or a skip, not counted, and the question stays |
| `quotaOut` | | Says the day's allowance is over, and moves on, uncounted |

On any failure the learner reads "we'll check it later, and it won't count as wrong", and the answer goes to `/answers` under the same `attemptId` when it can (S §16.3): the server judges it there.

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
| `answer` | object | By way of answering. Choice templates: `{optionId}`. `fillChoices`: `{words}`, one per blank in order. `wordOrder`: `{words}` as placed. `matching`: `{mistakes}`, the pairs with a mistake on the way, each once, for the question's concept (S §7.3). `listenWrite`, `fillTyped`, `translation`: `{text}`. `errorCorrection`: `{tokenId, replacement}`. `speakAnswer`: `{text, typed}`. `sentenceOrder`, `spelling`: `{words}`, one per place. `repeatSentence`: `{heardWords, totalWords}`, sent only when enough was heard, and never what was said (S §7.5) |
| `hinted` | bool | The hint was opened on this question: a right answer is an assisted success (S §7.1) |

### Errors

The app assumes 400, 404, 409, 410 and 422 mean this answer will never be accepted: it drops it and logs that, so it can't hold back the others. Anything else, it sends again later. To confirm with the backend team.

### Response

`200` or `204`; the app reads nothing from it. Marks and XP stay on the server. The app's own marking only drives what the learner sees; if the two differ, the screen doesn't change, and completion and points follow the server (ADR 11).
