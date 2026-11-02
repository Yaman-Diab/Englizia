# Practice: the word bank

Status: **proposed**. The app runs on this contract in mock mode (`assets/mock/practice/`); nothing is confirmed by the backend team yet.
Requirements: student doc §10 (the «تدرّب» tab, the bank and its boxes, the review, «كلماتي»), §6 (the tab's badge), §21 (working offline).

One bank per learner across all their tracks (§10.2). Words reach it through the star: `POST /api/v1/app/lessons/{id}/words` ([lessons.md](lessons.md)), from a reader's span or a vocabulary card. The app keeps the last bank on the phone, so the tab opens and a review runs offline; answers and deletions wait there, in order, and go when they can.

## `GET /api/v1/app/word-bank`

### Response `200`

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "sessionSize": 12,
    "conceptsDue": 3,
    "savedSentences": 9,
    "words": [
      {
        "id": "bw_pick_out",
        "base": "pick out",
        "kind": "phrasalVerb",
        "ar": "ينتقي",
        "sentence": { "en": "I'll pick out the best ones for you.", "ar": "سأنتقي لك أفضلها.", "highlight": [1, 2], "audio": "https://…" },
        "audio": "https://…",
        "image": "https://…",
        "source": { "lessonId": "les_iv", "title": "في السوق" },
        "video": { "videoId": "vid_market_v1", "startMs": 30300 },
        "box": 2,
        "dueAt": "2026-11-02T00:00:00.000"
      }
    ]
  }
}
```

| Field | Type | Meaning |
|---|---|---|
| `sessionSize` | int | Cards in a review, from the panel. Default 12 |
| `conceptsDue` | int? | Concepts due today (§11). Absent while the mistakes' bank is off for the track or level, and in kids mode: then there is no row |
| `savedSentences` | int | Sentences saved for shadowing (§10.1) |
| `words[].id` | string | The bank's own id, stable |
| `words[].base` | string | The word or phrase as saved: a copy that later content changes don't touch (§10.2) |
| `words[].kind` | string? | `noun`, `verb`, `adjective`, `adverb`, `phrase` from vocabulary; `phrasalVerb`, `idiom`, `word` from a reader. Another shows no badge |
| `words[].ar` | string | The meaning in its sentence |
| `words[].sentence` | `{en, ar, highlight[], audio?}` | The sentence it was saved from. `highlight`: the places in `en`, split by spaces, that are the word |
| `words[].image`, `audio` | string? | With no image the card shows the word's first letter |
| `words[].source` | `{lessonId, title}`? | «من: يوم في المزرعة» |
| `words[].video` | `{videoId, startMs}`? | When it was saved from a video. Kept for «شاهد المقطع», which the app only shows dimmed with «قريبًا» for now |
| `words[].box` | 1–5 | The waits are 1, 3, 7, 14 and 30 days |
| `words[].dueAt` | ISO date-time | From when it is due: the start of its day, by the track's day start |

A word that can't be read is left out, and the rest show.

## `POST /api/v1/app/word-bank/reviews`

One answer of a review, sent as soon as it can be, in the order given.

```json
{ "reviewId": "3f1c…", "wordId": "bw_pick_out", "known": true, "reviewedAt": "2026-11-02T09:14:00.000Z" }
```

`known: true` moves the word to the next box (the fifth stays the fifth), `false` back to the first; the server sets `dueAt` from `reviewedAt` with the track's day start (§10.2). The app moves it the same way meanwhile, and the next `GET` replaces its guess. `reviewId` makes repeating it harmless.

## `DELETE /api/v1/app/word-bank/words/{wordId}`

«احذف من بنك الكلمات» (§10.4). Saving it again with the star brings it back as new. Safe to repeat.

## Refusals

`400`, `404`, `409`, `410` and `422` to a review or a deletion drop it, so it can't hold back the rest. Any other failure leaves it waiting.
