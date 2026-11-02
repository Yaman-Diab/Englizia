# Talk (conversations with a character)

Status: **proposed**. The app runs on this contract in mock mode (`assets/mock/talk/`); nothing is confirmed by the backend team yet.
Requirements: student doc §8.6 (the tab, the intro, the conversation and its states), §16.3 (daily limits, what is never sent to the AI).

The AI is called by the server only. The app sends what the learner said as text (speech is turned into text on the phone and never kept) and shows the character's reply. Nothing is corrected during a conversation: the server keeps the mistakes, with their concepts, for the summary and the mistakes' bank. The tab shows only where the track or level shows conversations: on in the general track, from grade 7 in Emar, off for kids.

## `GET /api/v1/app/talk`

The tab: the scenarios of the units the learner has reached, by unit, and the AI conversations left today.

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "quota": { "left": 2, "total": 3 },
    "units": [
      {
        "title": "الوحدة 3: البيت الجديد",
        "scenarios": [
          {
            "id": "sc_fragile_box",
            "title": "الصندوق القابل للكسر",
            "character": { "name": "Jake", "avatarUrl": null },
            "tasks": 3,
            "kind": "ai",
            "bestDone": null,
            "unlockUnit": null
          }
        ]
      }
    ]
  }
}
```

| Field | Type | Meaning |
|---|---|---|
| `quota.left`, `quota.total` | int | «محادثات ذكية متبقية اليوم: 2 من 3». The panel sets the total (default 3); a conversation counts when it starts, and one that fails to start doesn't |
| `units[].title` | string | The unit's heading, as it should show |
| `scenarios[].kind` | `ai` \| `written` | «✦ محادثة ذكية» or «محادثة مكتوبة». A written one never counts against the day's limit. While the assistant is off, an AI scenario comes as `written` if it has a fallback dialogue, or not at all |
| `scenarios[].tasks` | int | How many tasks it has (2 to 4) |
| `scenarios[].bestDone` | int? | The most tasks done in one conversation: «2 من 3», or ✓ «3 من 3». Null when never tried («جديد») |
| `scenarios[].unlockUnit` | int? | Set while the learner hasn't reached it: locked, «تُفتح في الوحدة 5» |
| `scenarios[].character.avatarUrl` | string? | The character's picture; its initial shows while there is none |

A scenario that can't be read is left out, and the rest show. The app keeps the last response, so the tab shows offline (starting needs a connection).

## `GET /api/v1/app/talk/scenarios/{scenarioId}`

What a conversation starts from.

```json
{
  "id": "sc_fragile_box",
  "title": "الصندوق القابل للكسر",
  "kind": "ai",
  "character": { "name": "Jake", "descriptionAr": "عامل نقل مستعجل", "avatarUrl": null },
  "intro": { "en": "Jake is carrying your boxes upstairs. He's in a hurry.", "ar": "جيك يحمل صناديقك إلى الأعلى، وهو مستعجل.", "audioUrl": "https://cdn.example.com/talk/jake_intro.mp3" },
  "roleAr": "انتقلت للتو إلى شقة جديدة.",
  "tasks": [{ "id": "t_fragile", "ar": "نبّه جيك إلى أن الصندوق قابل للكسر" }],
  "maxTurns": 7,
  "opening": { "en": "Hey! Where do you want these boxes?", "ar": "مرحبًا! أين تريد هذه الصناديق؟", "audioUrl": "https://cdn.example.com/talk/jake_0.mp3" },
  "suggestions": [{ "en": "Careful, please!", "audioUrl": "https://cdn.example.com/talk/sug_0b.mp3" }]
}
```

| Field | Meaning |
|---|---|
| `character.descriptionAr`, `roleAr`, `tasks[].ar` | Shown to the learner only, never sent to the AI (§16.3) |
| `intro` | Played by itself when the intro opens, with its translation |
| `maxTurns` | The learner's turns before it ends (the panel allows 4 to 20; 10 when absent) |
| `opening` | The character's fixed first line, with its voice, so every conversation starts the same way at once |
| `suggestions[]` | «جرّب أن تقول» for the first turn: 1 to 3, each with its voice. Pressing one only plays it |
| any `audioUrl` | The character's voice, in its scenario's voice. Absent or failing, the text shows alone |

## `POST /api/v1/app/talk/conversations`

«ابدأ المحادثة». `{ "conversationId": "…", "scenarioId": "sc_fragile_box" }`, the id made by the app. It counts against the day's limit; with none left it is refused (`429`, or the app shows the server's message), and the intro stays.

## `POST /api/v1/app/talk/conversations/{conversationId}/turns`

```json
{ "turnId": "…", "text": "Jake, this box is very fragile.", "via": "mic" }
```

`via` is `mic` or `keyboard`. `turnId` stays the same when a failed turn is sent again («إعادة المحاولة»), so the server counts it once.

```json
{
  "statusCode": 200,
  "data": {
    "reply": { "en": "Oh! Okay, I'll be careful. Where should it go?", "ar": "أوه! حسنًا، سأنتبه. أين أضعه؟", "audioUrl": "https://cdn.example.com/talk/jake_1.mp3" },
    "tasksDone": ["t_fragile"],
    "suggestions": [{ "en": "In the kitchen, please.", "audioUrl": "https://cdn.example.com/talk/sug_1b.mp3" }],
    "turnsLeft": 6
  }
}
```

| Field | Meaning |
|---|---|
| `reply` | The character's answer, its translation and its voice. The server checks the AI's output before sending it |
| `tasksDone` | Every task done so far (not only this turn's), so a repeated turn changes nothing |
| `turnsLeft` | The conversation ends when it reaches 0, or when every task is done |

A failure leaves the conversation going: «تعذّر الرد» with «إعادة المحاولة», and the turn doesn't count.

## `POST /api/v1/app/talk/conversations/{conversationId}/end`

The learner ended it («أنهِ الآن»), or it ended and they went on to the summary. The summary's contract comes with its design.
