# Lessons

Status: **partly live.** On the dev server (docs/api/openapi.json): a lesson (`GET /api/v1/app/lessons/{lessonId}`) and its answers (`POST /api/v1/app/sync`), with six question templates and one lesson type published, a grammar lesson with no video. The app uses both. Real answers: `test/fixtures/api/app_lesson_*.json` and `app_sync_*.json`. Everything else on this page is **proposed** and runs in mock mode only (`assets/mock/lessons/`): the other templates and lesson types, the unit, reports, words, watching, the teacher's questions, completion and the AI's review.
Requirements: student doc §7.1 (the exercise container), §7.3 (templates), §2 principle 6; server doc §19.2, §19.3 and §20.6. For what is live, the backend's notes B-18 and B-19 (2026-11-19) and its answers of 2026-11-20 are the reference.

## `GET /api/v1/app/lessons/{lessonId}` (live)

The published lesson, whole, with its questions and their keys: «تحقق» has to work offline (S §7.1), and the server marks each answer again when it arrives. Needs a session, a guest's or a member's. It carries an `ETag` (`Cache-Control: private, no-cache`), which the app doesn't use yet (STATUS D-124). A locked lesson answers `200` all the same: the locks are the map's.

```json
{ "id": "…", "versionId": "…", "versionNo": 1, "unitId": "…", "type": "grammar_video",
  "titleAr": "الفعل to be: am وis وare", "titleEn": "To be: am, is, are",
  "objectiveAr": "…", "objectiveEn": null, "minutes": 8, "bookPages": null, "publishedAt": "…",
  "content": { "type": "grammar_video", "withVideo": false, "video": null,
    "ruleCard": { "summaryAr": "…", "forms": [["I", "[am]"], ["he / she / it", "[is]"]],
      "examples": [{ "textEn": "I am a student.", "highlight": [1], "translationAr": "أنا طالب.", "audioMediaId": "…" }] } },
  "questions": [
    { "versionId": "…", "template": "multiple_choice", "instructionAr": "اختر الكلمة المناسبة",
      "instructionIsDefault": true, "instructionAudioMediaId": null, "hintAr": null, "explanationAr": "…", "bookPages": null,
      "body": { "prompt": "He ___ a doctor.", "options": [{ "id": "a", "text": "is" }] },
      "answerKey": { "optionId": "a" } } ],
  "media": { "<id>": { "kind": "audio", "url": "https://…/media/audio/….mp3", "sizeBytes": 9161 } } }
```

| Field | The app |
|---|---|
| `versionId` | The version the learner sees; every answer names it (`lessonVersionId`). A lesson in progress carries on with the version it started on, kept on the phone |
| `versionNo` | The version as a number, for what the app still sends to proposed endpoints |
| `type` | `grammar_video`, `interactive_video`, `interactive_text`, `vocabulary`, `conversation`. `grammar_video` and `interactive_text` are published and read; the app reads the others from the mock, in its own shape (below) |
| `titleAr`, `titleEn` | The app shows `titleAr` in both languages for now (D-123) |
| `content.ruleCard` | The rule's summary: `summaryAr`; `forms`, rows whose first cell says who and whose others are joined, the letters between `[` and `]` marked; `examples`, where `highlight` counts the words of `textEn` from 0, split at its spaces |
| `content.withVideo`, `video` | With no video the exercises are open at once. No lesson with a video is published, so the shape of `video` isn't known: such a lesson's content can't be shown yet, and the page says so (question 1) |
| `questions[].versionId` | The question's only id; an answer names it (`questionVersionId`) |
| `instructionAr`, `hintAr`, `explanationAr` | Shown as they are, in Arabic, in both app languages |
| `instructionAudioMediaId`, `bookPages`, `objectiveAr`, `minutes` | Not shown yet (D-123) |
| `media` | Each file once, by id; a `…MediaId` names one. Its links are public, with no token, and don't run out |

The six templates, each with its `body` and `answerKey`:

| `template` | `body` | `answerKey` | The app's name |
|---|---|---|---|
| `multiple_choice` | `prompt` with one `___`, `options[{id, text}]` | `{optionId}` | `multipleChoice` |
| `picture_choice` | `prompt`, `promptAudioMediaId`, `options[{id, imageMediaId}]` | `{optionId}` | `imageChoice` |
| `listen_choose` | `audioMediaId`, `transcript`, `options[{id, text}]` | `{optionId}` | `listenChoose` |
| `gap_choice` | `sentence` with a `___` for each gap, `gapCount`, `chips[]`: the answers and the extra ones | `{gaps[]}` | `fillChoices` |
| `word_order` | `meaningAr`, `chips[]`: the answer's and the extra ones | `{chips[], alternatives[][]}`, each alternative as its words | `wordOrder` |
| `matching` | `rightKind` (`text` or `image`), `left[]`, `right[{text, imageMediaId}]` | `{pairs[]}`: for each of `left`, the place in `right` of what goes with it | `matching` |

The app puts this lesson in its own shape before reading it (`server_lesson.dart`), so one reader serves it and the mock's lessons. Options are shuffled on the phone, the same for this phone each time. A question the app can't read is skipped and logged, and a template it doesn't know is left out (question 5). A picture has no text for a screen reader (question 3).

### An interactive text's `content` (live)

From the backend's note B-21 (2026-11-24). Published on the dev server: «يوم في حياة سارة» (`demo-gen-a2-u02-l03`, General English, A2, unit 2, lesson 3), saved as `test/fixtures/api/app_lesson_interactive_text.json`, and a kids' story (`demo-kids-k1-u02-l03`), which the app doesn't read yet (STATUS D-133).

```json
"content": { "type": "interactive_text",
  "media": { "mediaId": "…", "durationMs": 26336 },
  "sentences": [
    { "id": "s5", "speaker": "Mum", "textEn": "Please turn it off before you leave.", "textAr": "من فضلك أطفئه قبل أن تغادر.",
      "startMs": 18467, "endMs": 22319, "imageMediaId": null, "shadowing": true,
      "tokens": [ { "id": "s5t1", "text": "Please", "startMs": 18467, "endMs": 19036 }, "…" ],
      "spans": [ { "id": "sp4", "tokenIds": ["s5t2", "s5t4"], "kind": "phrasal_verb", "lemma": "turn off",
                   "textAr": "يُطفئ", "noteAr": null } ] } ] }
```

| Field | The app |
|---|---|
| `media` | The lesson's one sound, from `media[mediaId].url`, and its length. Every time below is a moment in it; there is no file for a sentence or a span. `null` for an interactive video, which has no media until the server takes videos (N-9): its content can't be shown, and the page says so |
| `sentences[]` | In their order (1 to 200) |
| `id` | Kept as it is; its form isn't relied on |
| `speaker` | Who says it, over the sentence |
| `textEn` | Not read: the sentence is its `tokens`, each `text` as it is with a space between |
| `textAr` | Its translation. `null`: the sentence offers no «الترجمة», shows no Arabic in any way of showing, and keeps its English in «الترجمة فقط» |
| `startMs`, `endMs` | Not read: a sentence runs from its first word's start to its last word's end, which are the same moments |
| `imageMediaId` | Its picture, from `media`, under the sentence. It has no text of its own, in the data or the panel: it shows its sentence, which a screen reader reads with it, so the picture itself isn't announced |
| `shadowing` | «كرّر بعدي» takes only these sentences. The learner's voice stays on the phone |
| `tokens[]` | `{id, text, startMs, endMs}`, its words in order, punctuation in its word (`leave.`). The word lit is the one whose time holds the sound's moment; between two words, none |
| `spans[]` | What can be pressed (0 to 10 a sentence): `tokenIds` in the sentence's order, side by side or not (`turn … off`), a word in one span at most. `kind`: `word`, `phrasal_verb`, `expression` (the app's `idiom`, «تعبير»). `lemma`, `textAr` (the meaning here) and `noteAr` fill its card. A word of no span opens nothing, and is meant to: a word that needs a meaning is marked by the content team as a span of one word, and no dictionary of single words is planned for v1 |
| A span's sound | From its first word's start to its last word's end, what lies between included (the backend's rule R197) |

Reading, listening, «كرّر بعدي» and opening a span send the server nothing: the lesson completes by its questions, through the sync, as any lesson. So for a lesson of the server's the app sends no `content-done` and no `shadowing` (both proposed, below). **Saving a span's word has no call yet (N-5): the card shows no star.** The lesson's sound isn't kept for offline use (downloads are v1.0, [downloads.md](downloads.md)).

### Marking on the phone

The server's marking is the one that counts, and the phone marks by the same rules, so the two agree:

| Template | Right when |
|---|---|
| The three choices | The option is the key's |
| `gap_choice` | Each gap holds its key's text, letter for letter: case counts, and nothing is trimmed |
| `word_order` | The cards' words are the key's, or one alternative's, by the rule R45: each card split at its spaces, all punctuation (Unicode `P`) taken out, lower case, and what is left empty dropped. "have to" is two words, and "It's" is "its" |
| `matching` | Every pair is the key's |

## The app's own shape (proposed)

The templates and lesson types the server doesn't have yet come from the mock in this shape, which is also the one the server's lesson is put in. Its fields are those of the content package (server doc §20.6), under the API's rules (`README.md`): camelCase, lower-camel enum values, absolute media URLs. So `instruction_ar` is `instructionAr`, `book_ref` is `bookRef`, `multiple_choice` is `multipleChoice`. The backend sends each new template's shape, answer and marking rule before the app needs it; until then these are the app's guesses.

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
| `next` | `{kind, lessonId?, lessonKind?, scenarioId?, title?, unitNumber?}` | What comes after. `kind`: `lesson`, `unitReview`, `unit`. A conversation's `scenarioId` opens its «تحدّث» scenario, as a unit's lesson has it. None at the end of a track |

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

A vocabulary lesson has `vocabulary` (design `Vocab Lesson`, S §8.5): its cards, browsed before its exercises. All proposed.

| Field | Type | Meaning |
|---|---|---|
| `vocabulary.words[]` | `{id, word, pos?, ar, image?, audio?, example}` | In order. `pos`: `noun`, `verb`, `adjective`, `adverb`, `phrase`; another shows no badge. With no `image` the card shows the word's first letter. `audio` is said once as the card shows |
| `…example` | `{tokens[], ar, audio?, highlight[]}` | `tokens[]`: `{id, text, startMs?, endMs?}`, punctuation stuck to its word. `highlight`: the ids of the tokens that are the word, several for a phrase. With no times, the mark follows the sound by the tokens' letters |

An interactive text and an interactive video both have `reader` (designs `Interactive Text`, `Interactive Video`, S §8.2–§8.4): the same sentences and spans, with a sound or a video as the time. All proposed.

| Field | Type | Meaning |
|---|---|---|
| `reader.audio` | `{url, durationMs}` | A text's whole sound. Required with no `video` |
| `reader.video` | `{id, durationSeconds, sources[], cover?}` | A video, as in a grammar lesson: replacing it means a new `id`. The word timings are in this video's time |
| `reader.requiredWatchPercent` | int | With `video`: how much really watched completes it, from the panel (default 80, S §7.6). Required |
| `reader.defaultSpeed` | number | With `video`: the speed it opens at, from the panel, as 0.75 for kids. Default 1 |
| `reader.watch` | `{videoId, positionSeconds, watched[]}` | With `video`: as the server last heard, from any phone |
| `reader.sentences[]` | `{id, ar, words[], image?, imageAlt?, speaker?, shadowing?, waveform?}` | In order. `speaker`: shown above the sentence, in every way of showing it. `shadowing`: practised after the text; with none, the text goes on to the exercises | `waveform`: its sound's loudness, 0 to 1, for «قارن»; with none, the words' timings draw it. A video's sentence's `image` is its still for shadowing
| `reader.shadowingMode` | `repeat`, `together` or `hidden` | How shadowing starts, by the learner's level: `repeat` for Pre-A1, A1 and kids, `together` from A2 (S §9). The learner's own choice then stays on the phone. Default `repeat` |
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

### A kids' lesson (`kids`)

In kids mode (S §13), a lesson comes with `kids`: its screens in order, the words it teaches, and the guide's recorded lines. Its questions stay in `exercises` as any lesson's, answered and completed the same way (the sync, `complete`); a `question` screen names one by its `id`. Proposed, from designs `Kid Lesson` and `Kid Media`.

```json
"kids": {
  "voice": { "praise": "…/praise.mp3", "tryAgain": "…/try_again.mp3", "leave": "…/leave.mp3", "done": "…/done_six_words.mp3" },
  "words": [{ "word": "apple", "image": "…/apple.svg", "ar": "تفاحة", "audio": "…/apple.mp3" }],
  "steps": [
    { "kind": "word", "id": "k_word", "instructionAudio": "…/in_word.mp3", "word": { "word": "apple", "image": "…", "ar": "تفاحة", "audio": "…" } },
    { "kind": "letter", "id": "k_letter", "instructionAudio": "…", "letter": "A", "video": "…/letter_a.mp4", "videoMs": 4600, "audio": "…/letter_a.mp3", "words": [{ "word": "apple" }, { "word": "ant" }] },
    { "kind": "question", "id": "kq_letter", "instructionAudio": "…/in_choose_letter.mp3" }
  ]
}
```

| Field | Meaning |
|---|---|
| `voice` | «أحسنت!», «حاول مرة أخرى», «تريد أن تخرج؟» and the end's «رائع! تعلّمت ست كلمات جديدة», recorded |
| `words[]` | The lesson's 5 or 6 words, pictured at its end; a matching word alone says itself from here |
| `steps[].instructionAudio` | The screen's Arabic instruction (`instruction_ar_audio`), played by itself; pressing the guide plays it again |
| `kind: word` | «بطاقة الكلمة» (Starter 2): its picture, the word and its voice, said after the instruction |
| `kind: letter` | «بطاقة الحرف» (Starter 1): the capital (the small one is shown beside it), its video and its length in ms in case the player can't tell, its voice, and two words that start with it |
| `kind: question` | One of `exercises`: `listenChoose` with letters (`text`) for «اسمع واختر الحرف», `imageChoice` for «اسمع واختر الصورة», `matching` with pictures for «طابق». No check button: pressing answers. The first answer to each goes through the sync, so the server records a mistake on its concept without a word to the child |
| `kind: story` | «قصة مصوّرة» (S §13.3): `pages[]` of `{image, audio, words[{text, startMs}], marked[]}`. Each page is told with its words lit from `startMs`; a `marked` word (a `words[]` entry, matched by its letters) is underlined and opens its card: picture and voice, no text. The child turns the pages, or lets them turn; past the last, a star |
| `kind: song` | «أنشودة»: `video`, `videoMs`, `pictures[]` drawn over it, and `lines[]` of `{words[{text, startMs}]}` lit with the video's own clock. It opens at 0.75, «عادي» plays at 1; no translation. «غنِّ مرة أخرى» starts it over, «التالي» gives the star |
| `kind: dialogue` | «حوار مكتوب»: `character` (a word: name and picture), `opening`, `closing` and each of `replies[]` `{word, answer, echo}`, every line `{en, audio}`. The child picks a reply by its picture, the character answers, then the child says `echo` (`echoInstructionAudio` asks for it) and any try earns the star before `closing` |
| `kind: speak` | «كرّر بعدي»: a `word`, its model said after the instruction; the child's try is never judged (S §13.2), it earns the star |

The voice isn't sent or kept: the phone's speech engine only tells the app that the child spoke (D-088).

The end shows five stars filling, whatever the points (S §13.1: points show as stars). A screen that can't be read is left out; with none, the lesson can't be shown.

### Errors

The common errors (`README.md`). With an unknown lesson, `404`.

## `GET /api/v1/app/units/{unitId}`

A unit's screen (S §6.2, §13.5, §14): what it teaches and its lessons in the panel's order, however many and of whatever kinds. The phone keeps the last few for offline. The server has no such call: there a unit is read from its level's map ([home.md](home.md)) and put in this shape, which is the app's own, from design `Unit`, and which mock mode serves. Mock: `assets/mock/units/<unitId>.json`.

```json
{
  "id": "unit_gen_a2_03",
  "number": 3,
  "title": "يوم في المزرعة",
  "levelLabel": "A2",
  "cover": "https://…/farm.webp",
  "kidsMode": false,
  "ordered": true,
  "goals": ["تصف يومًا في الريف", "تستخدم المضارع البسيط للعادات"],
  "concepts": [{ "id": "c_present_simple", "name": "المضارع البسيط" }],
  "bookPages": null,
  "titleAudio": null,
  "lockedBy": null,
  "next": { "id": "unit_gen_a2_04", "number": 4, "title": "في السوق" },
  "lessons": [
    { "id": "les_voc", "kind": "vocabulary", "title": "كلمات المزرعة", "minutes": 5, "done": true },
    { "id": "les_chat_box", "kind": "conversation", "title": "الصندوق القابل للكسر", "minutes": 5, "done": false, "scenarioId": "sc_fragile_box" }
  ]
}
```

| Field | Meaning |
|---|---|
| `number`, `title`, `levelLabel` | «الوحدة 3», its title, and the level's short name on the badge («A2», «الصف 7», «Starter 2») |
| `cover` | The unit's cover from the panel, wider than tall; it moves slower than the page as it scrolls |
| `kidsMode` | The effective setting: a grid of picture cards with stars, and no goals or grammar |
| `ordered` | The effective «ترتيب إلزامي» setting proposed for the panel: lessons open one after another; `false` (Emar) opens them all and suggests the first left. Default `true` |
| `goals` | «ستتعلّم أن…», open on the learner's first visit and folded after (kept on the phone) |
| `concepts[].name` | «قواعد الوحدة»: the concepts the unit targets |
| `bookPages` | `{from, to}` in the student's book (Emar), or `null` |
| `titleAudio` | Kids: the unit's name, said by the guide when the screen opens and when it is pressed |
| `lockedBy` | `{id, number, title}` of the unit to finish first, or `null`: the lessons show locked as a preview, with «أكمل الوحدة 2 لتفتح هذه الوحدة» |
| `next` | The next unit, for «الوحدة التالية» once every lesson is done |
| `lessons[].kind` | One of the lesson kinds of `complete` (`vocabulary`, `interactiveVideo`, `grammarVideo`, `interactiveText`, `conversation`, `unitReview`); another shows with the general icon and opens as exercises. A kids' unit opens each as a kids' lesson |
| `lessons[].minutes` | Its estimated length, from the media and the questions or written in the content |
| `lessons[].page` | Its page in the book (Emar) |
| `lessons[].done`, `stars` | Completed, and the stars it earned (kids, 0 to 5) |
| `lessons[].image`, `audio` | Kids: its card's picture, and its name said when a locked card is pressed |
| `lessons[].scenarioId` | A conversation lesson is that «تحدّث» scenario, and opens it |
| `lessons[].resume` | `{question, share}`: where it stopped on another phone. The phone's own place, and a completion still on its way, come first |

The current lesson is the first not done; `unitReview` waits until every other lesson is done («تُفتح بعد إكمال الدروس»). Offline, only lessons kept on the phone open («يمكنك متابعة ما بدأته فقط»). A lesson that can't be read is left out; with none, the unit can't be shown.

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

Asks the server to judge an order in `reviewOrders`, with `{attemptId, lessonVersion, questionId, answer, hinted}`, while the learner waits. `200` with `{ "correct": true }`. On any failure the learner reads "we'll check it later, and it won't count as wrong", and the server judges it when it can (S §16.3). Proposed.

## `POST /api/v1/app/lessons/{lessonId}/words`

The star on a span or a vocabulary card, kept on the phone and sent like an answer. Proposed.

```json
{ "spanId": "turnoff", "saved": true, "base": "turn off", "kind": "phrasalVerb", "ar": "...", "note": "...", "sentence": { "en": "...", "ar": "..." } }
```

Saving sends the span whole, so changing it in the panel later doesn't change what was saved (S §8.2). From a video, `sentence` also has `videoId`, `startMs` and `endMs`, the moment to find it again (S §8.4). Taking it back sends `{spanId, saved: false}`.

A vocabulary card sends `wordId` instead of `spanId`, with `base` its word, `kind` its `pos`, and `sentence` its example; taking it back sends `{wordId, saved: false}`.

## `POST /api/v1/app/lessons/{lessonId}/shadowing`

A sentence's best shadowing, sent once the learner leaves it, kept on the phone and sent like an answer. Proposed.

```json
{ "sentenceId": "s1", "heard": 6, "total": 8 }
```

The server keeps the best for each sentence (S §9), and gives points by its accepted share (default 70%). It is never a mistake. The learner's voice is never sent.

## `POST /api/v1/app/lessons/{lessonId}/content-done`

`{lessonVersion}`, once the end of a text is reached or the last vocabulary card passed, which is what completes them (S §8.3, §8.5). Kept on the phone and sent like an answer, and safe to repeat. Proposed.

## `POST /api/v1/app/lessons/{lessonId}/watch`

How much of the video was really watched, kept on the phone and sent like an answer. Only the latest counts, so a newer one replaces any still waiting. Proposed.

```json
{ "videoId": "vid_1", "lessonVersion": 1, "positionSeconds": 134, "watched": [[0, 120], [200, 214]] }
```

Both a grammar lesson and an interactive video send it. `watched` is `[from, to)` in seconds, counted from what played: moving the bar adds nothing. The server should take the union, and decide completion from it (S §7.6).

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

A lesson of the server's has no such call: the server completes a lesson by its answers and says so in the sync's reply. So its end only waits for its answers to be with the server, then shows the phone's own numbers, which the server's markings have set right as they came; with answers still on the phone it says they are kept, and tries again when the connection returns. Points, the goal and the streak aren't the server's to give yet (STATUS D-123). What follows is proposed, for the mock's lessons.

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

The learner's own words on a `speakAnswer` question, judged by the server's AI while they wait, with `{attemptId, lessonVersion, questionId, answer: {text, typed}, hinted}`. Only the words are sent, never a recording. The app holds no AI key (S §16.3). Proposed.

| `outcome` | With | The app |
|---|---|---|
| `answered` | `note`, `better?`, and `misconceptions[]` for the server's own use | Shows the note and the better form, and moves on |
| `offTopic` | `note` | Neutral: another try or a skip, not counted, and the question stays |
| `quotaOut` | | Says the day's allowance is over, and moves on, uncounted |

On any failure the learner reads "we'll check it later, and it won't count as wrong". The answer isn't kept: the server has no such template yet, and will take it through the sync with a `pending_ai` status when it has (STATUS D-123).

## `POST /api/v1/app/sync` (live)

The answers kept on the phone, together. An answer is marked on the phone at «تحقق», kept in a queue under a new id, and sent when the phone can; the server marks it again on the version the learner saw, and keeps it once however often it comes. Only lesson questions of the six templates go: an answer to any other template is neither kept nor sent, as the server would refuse it. Nothing of the placement test goes here.

```json
{ "sentAt": "2026-11-20T14:00:05.000Z",
  "attempts": [ { "clientAttemptId": "…", "lessonVersionId": "…", "questionVersionId": "…", "runId": "…",
                  "answer": { "optionId": "a" }, "hintsUsed": 0, "clientCreatedAt": "2026-11-20T14:00:00.000Z" } ] }
```

| Field | The app |
|---|---|
| `clientAttemptId` | A UUID made at «تحقق», the same on every send |
| `lessonVersionId`, `questionVersionId` | The lesson's and the question's `versionId`, as the learner saw them. An old version is always taken, so a changed lesson never empties the queue |
| `runId` | A UUID for one go at the lesson: made with its first answer, kept through a stop, and new once the lesson is finished. The server tells a first try by it |
| `answer` | One field: `{optionId}`, `{gaps[]}` (each card's text as it came), `{chips[]}` (as placed) or `{pairs[]}` |
| `hintsUsed` | 0 to 10. The app has one hint a question: 1 when it was opened |
| `clientCreatedAt`, `sentAt` | The phone's clock in UTC, ending in `Z`; the server corrects a wrong clock by `sentAt` |

**A matching.** The app corrects each pair as it is made (S §7.3), so its pairs always end right, while the server marks one whole answer and refuses one where a place is used twice (`question.answer_invalid`, checked on the dev server). So with no mistake the key goes; with one, the word's first wrong try goes as its two pairs changed over, each pair once at most. Question 2.

`200`, with one result for each answer, in their order:

```json
{ "attempts": [ { "clientAttemptId": "…", "status": "accepted", "attemptId": "…", "isCorrect": true, "error": null } ],
  "lessons": [ { "lessonId": "…", "state": "completed", "best": { "firstTryCorrect": 6, "questionCount": 6 } } ],
  "units": [], "levels": [], "serverTime": "…" }
```

| `status` | The app |
|---|---|
| `accepted` | Takes it off the phone. Where `isCorrect` differs from the phone's marking, the lesson's count takes the server's, with no word to the learner |
| `duplicate` | The same: the reply carries its first marking |
| `rejected` | Takes it off the phone and logs `error.code`: `validation.failed`, `lesson.version_unknown`, `enrollment.not_found`, `question.version_unknown` or `question.answer_invalid` |
| Any other | Takes it off the phone, keeps its own marking, and logs it. `pending_ai` will come with the AI's templates |

An answer the reply doesn't mention stays for the next send. `lessons`, `units` and `levels` say what the answers completed and opened; the app doesn't read them, as home and the unit ask the map again when the learner comes back ([home.md](home.md)). Fields it doesn't know are ignored.

When the request fails whole, the server keeps nothing:

| Answer | The app |
|---|---|
| No connection, a timeout, `5xx`, `429`, `409 content.duplicate` | Keeps the answers as they are and tries again by itself after 2, 4, 8, 16… seconds, up to 5 minutes, at a random point in the second half of each wait, or after `Retry-After` when the server gives one |
| `401` | The token is renewed and the request sent again, as everywhere |
| `400 validation.failed` | `details[].field` names what couldn't be read by its place in this request (`attempts[3].clientCreatedAt`): those answers are dropped, logged with the `traceId`, and the rest sent again. When it names anything else (`sentAt`, `attempts`), the request itself is wrong: it is logged, and no answer is sent again until the app restarts; none is thrown away |
| `413 sync.batch_too_large` | The batch is halved |
| `404 user.not_found` | The account was deleted while its token still works: the session ends, and what the phone kept for it goes |

When it is sent: as each answer is checked, when the app opens with a session, when the connection returns, when a lesson ends, and every 3 minutes while the app is open. One send at a time, the oldest answers first, 200 at most in a request.

Each answer is kept under its account's id (`user.id` of the sign-in's `TokenResponse`), apart from the account's other data, so that signing out or in clears neither (the backend's note B-28, 2026-11-23). Only the account in use sends its own: the server keeps an answer for the token's owner, so another learner's waits on the phone until they sign in again. Signing out tries to send first (5 seconds at most), then keeps what is left. A session that ended (`401 auth.refresh_token_invalid`) and a trial account keep theirs too. The phone forgets an account's answers in two cases only: a guest who signs out, as the server deletes its account and answers (B-09), and `404 user.not_found`. An answer kept before answers had an owner goes with whoever is signed in. Nothing goes in the request but `sentAt` and `attempts`.

## Answered by the backend (2026-11-23)

- A matching sent as its two pairs changed over is right: the server marks the whole `pairs`, a valid swap counts as wrong at the first try, and the mistake goes on the question's concepts. A list short of a pair is `400 question.answer_invalid`.
- `forms`: each row has two or three cells, the same number in every row, and none is a heading. The first is what the team writes, usually who (`I / you / we / they`); `[ ]` marks the letters the rule is about.
- A lesson completes when every question of its version is answered in one `runId`. A template newer than the app comes with a higher `minSupportedVersion`, so the app is asked to update (`426`) rather than skipping a question.
- Word orders are marked by saved alternatives only, with no AI, so `reviewOrders` and `answers/review` aren't needed; nor is `complete`, as the sync completes a lesson and says so in `lessons`.
- The questions to the teacher are private, a learner seeing only theirs and the replies (v1.0).

## Questions for the backend team

1. A grade lesson's `video` is `null` until the video's hosting is decided; the share to watch (80%) comes in v0.2 with where a lesson stopped. Its shape is still awaited.
2. Pictures have no text for a screen reader until the team decides (a caption may give the answer away); until then a picture option is read by its place, «الصورة 1 من 4».
3. Kids' lessons use the six templates. The app's kid screens outside them are the word card, the letter card, the story, the song, the written dialogue and «كرّر بعدي» (S §13, designs `Kid Lesson` and `Kid Media`): which of them will a kids' lesson carry, and in what shape?
4. Answered (2026-11-26): a sentence's picture has no text of its own, and a word of no span opens nothing (above).
5. Answered (2026-11-26): in the kids' story (design 13.08) each sentence is a page: its picture, its text and translation, its sound the lesson's from the sentence's `startMs` to its `endMs`, its words lit by their times, its spans the dotted words, and «كرّر بعدي» where `shadowing` is true. A story has 3 to 6 sentences, each with a picture (the server refuses to publish one without). A dotted word's card is the reader's (6.09: the word, its meaning, its kind, the star, its sound cut from the lesson's), with no picture of its own; the page's picture may be used. The big card with a picture for each word is the kids' vocabulary lesson's (13.02), which comes later. The dev server's story is saved (`test/fixtures/api/app_lesson_kids_story.json`); the kids' screens don't read it yet (STATUS D-133).
6. The kids' story's questions are `picture_choice`, `listen_choose`, `matching` and `multiple_choice`. The kids' screens (design `Kid Lesson`) ask by a sound and answer by pictures or by matching; a written gap («The ball is ___ the box.») has no kids' screen. Will kids' lessons keep to the templates those screens show, or is a written question meant for kids too?
7. A `vocabulary` lesson is published on the kids' demo track («Fruits»: `content.items[]` of `{id, word, pos, textAr, imageMediaId, wordAudioMediaId, introAudioMediaId, example}`). The app doesn't read it: no note describes it yet.
