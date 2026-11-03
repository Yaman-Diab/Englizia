# Explanations («اشرح لي»)

Status: **proposed**. The app runs on this contract in mock mode (`assets/mock/lessons/explanations.json`); nothing is confirmed by the backend team yet.
Requirements: student doc §7.2 (the feedback after a wrong answer), §16.3 (daily limits, the AI called by the server only).

«✦ اشرح لي» shows under a wrong answer when the question says so (`explainEnabled`, in [lessons.md](lessons.md) and [concepts.md](concepts.md)): adults only, never in kids mode, and only while the AI is on for the track and level. It explains this learner's mistake, in under 20 seconds of reading.

## `POST /api/v1/app/explanations`

```json
{ "questionId": "Q1", "lessonId": "les_1", "answer": { "optionId": "o1" } }
```

`lessonId` for a lesson's question, `conceptId` for a concept's (only one comes). `answer` is the learner's wrong answer, as an attempt sends it ([lessons.md](lessons.md)). The server gives the AI the question, its options, the learner's answer, the right one, the concept, the lesson and the level, never anything personal.

### Response `200`

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "status": "ready",
    "explanation": {
      "id": "ex_Q1",
      "yours": [{ "text": "She" }, { "text": "go", "wrong": true }, { "text": "to" }, { "text": "school" }, { "text": "every" }, { "text": "day." }],
      "right": [{ "text": "She" }, { "text": "goes", "fixed": true }, { "text": "to" }, { "text": "school" }, { "text": "every" }, { "text": "day." }],
      "whyAr": "الفاعل She مفرد غائب، ومعه نضيف s إلى الفعل في المضارع البسيط.",
      "example": { "en": "My brother plays football on Fridays.", "ar": "يلعب أخي كرة القدم أيام الجمعة.", "audioUrl": "https://cdn.example.com/explain/ex_Q1.mp3" }
    },
    "left": 4
  }
}
```

| Field | Meaning |
|---|---|
| `status` | `ready`, or `quotaOut` when today's explanations are used up: «استخدمت شروحات اليوم. تتجدد غدًا.», with the lesson's own explanation, and the AI isn't called |
| `explanation.yours[]`, `right[]` | «إجابتك» and «الصحيح», word by word. `wrong` words are struck through, `fixed` ones strong in green. Both empty where the template has no sentence to show; then only «السبب» and «مثال آخر» show |
| `explanation.whyAr` | «السبب», in Arabic, three sentences at most |
| `explanation.example` | «مثال آخر», its translation, and its voice (text to speech, kept; absent when it costs too much, and the button goes) |
| `left` | «شروحات متبقية اليوم: 4». The panel sets the day's limit (default 10, S §16.3) |

The server checks the AI's output before sending it: its length, its language, and that `right` matches the answer key. It keeps each explanation by question and wrong answer, so the next learner who makes the same mistake gets it at once, and it doesn't count against their limit. The app keeps the ones it was given while it runs: opened again, the same one shows at once and counts nothing.

A failure («تعذّر الشرح الآن» with «إعادة المحاولة», and the lesson's own explanation under it) doesn't count against the limit.

## `POST /api/v1/app/explanations/{explanationId}/rating`

«هل ساعدك الشرح؟»: `{ "helpful": true }`, once; it can't be changed. Kept to improve what the AI is told. A failure is only logged.
