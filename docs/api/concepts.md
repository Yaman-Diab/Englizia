# Concepts to strengthen (the mistakes' bank)

Status: **proposed**. The app runs on this contract in mock mode (`assets/mock/practice/concepts.json`); nothing is confirmed by the backend team yet.
Requirements: student doc §11 (rules and screens), §10.1 (the row in «تدرّب» and its count in the tab's badge).

A wrong answer records the **concept**, never the question: the wrong option's concept when it has one, else the question's (§11.1). The server keeps each concept's stations, makes a new question for each station ahead of time, and sends today's with the list, so a session runs offline. The interface shows only while the track's or level's "mistakes' bank interface" is on, and never in kids mode; then `conceptsDue` is absent from `GET /api/v1/app/word-bank` ([practice.md](practice.md)) and «تدرّب» has no row.

## `GET /api/v1/app/concepts`

### Response `200`

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "due": [
      {
        "id": "c_present_s",
        "ar": "إضافة s للفعل مع he/she/it",
        "en": "Present simple: third person -s",
        "why": "مع he وshe وit نضيف s إلى الفعل في المضارع البسيط.",
        "example": [{ "text": "She " }, { "text": "goes", "strong": true }, { "text": " to school." }],
        "wrong": { "answer": "She go to school every day.", "lessonTitle": "يوم في المزرعة" },
        "stations": 0,
        "repeats": 3,
        "lastRightAt": null,
        "explainEnabled": true,
        "question": { "id": "cq_plays", "template": "fillTyped", "instructionAr": "اكتب الفعل بالشكل الصحيح", "prompt": { "en": "My brother ___ football on Fridays.", "baseWord": "play" }, "accepted": ["plays"] }
      }
    ],
    "later": [{ "id": "c_plural_s", "ar": "الجمع بإضافة s", "dueAt": "2026-11-05T00:00:00" }],
    "mastered": [{ "id": "c_articles", "ar": "أداة التعريف the", "en": "The article" }]
  }
}
```

| Field | Type | Meaning |
|---|---|---|
| `due[]` | | Today's, by priority (a repeated mistake raises it), at most the panel's daily limit (default 10); the rest wait in `later` |
| `due[].ar`, `en`, `why` | string | Its names and a short explanation |
| `due[].example[]` | `{text, strong?}` | A right example, the part that matters strong |
| `due[].wrong` | `{answer, lessonTitle}`? | «أين أخطأت»: the learner's first answer that recorded it, from their attempts |
| `due[].stations` | 0–4 | Stations passed. The waits are 1, 3, 7, 14 and 30 days |
| `due[].repeats` | int | «تكرر 3 مرات» from 2 |
| `due[].lastRightAt` | ISO date-time? | «أجبت صحيحًا قبل 30 يومًا» |
| `due[].question` | a lesson question | A **new** one, of another template where it can be (§11.1), in the same format as a lesson's ([lessons.md](lessons.md)). Only templates that mark themselves: multiple choice, filling blanks by choosing or typing, ordering words, correcting an error. Made by the AI ahead of time and checked, or written by the content team, or else the last question with its options shuffled. A concept with none isn't offered |
| `due[].explainEnabled` | bool | «اشرح لي» under a wrong answer, by the track's settings |
| `later[]`, `mastered[]` | `{id, ar, en?, dueAt?}` | Names only |

A concept that can't be read is left out, and the rest show.

## `POST /api/v1/app/concepts/answers`

```json
{ "answerId": "8b2e…", "conceptId": "c_present_s", "questionId": "cq_plays", "correct": true, "answeredAt": "2026-11-02T09:14:00.000Z" }
```

Right moves the concept a station on; at the fifth it is mastered (about 55 days in all). Wrong at the first or second station starts the cycle again tomorrow; at the third to fifth it goes back two stations and keeps what came before (§11.1). The app shows the same while it waits; the next `GET` is the server's word. `answerId` makes repeating it harmless. It never counts as a mistake anywhere else.

## `POST /api/v1/app/concepts/reports`

«أبلغ عن مشكلة» on a concept's question: `{reportId, conceptId, questionId, reason}`, `reason` as in a lesson's report. A made question goes straight to the panel's review list (§11.2).

## Refusals

`400`, `404`, `409`, `410` and `422` drop an answer or a report, so it can't hold back the rest. Any other failure leaves it waiting.
