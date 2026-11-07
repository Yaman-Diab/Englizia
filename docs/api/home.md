# Home: the «تعلّم» tab

Status: **proposed**, every field. Nothing here is confirmed by the backend team. The app runs on this contract in mock mode (`assets/mock/home/`: the general track, Emar, and a child's with `env/mock_kids.json`), with the design's frames as scenarios on the dev page.
Requirements: student doc §6.1 (home), §6.2 (units), §3.1–§3.2 (tracks), §5.3 (email reminder), §12.3 (level check), §13.5 (kids), §14 (Emar), §15 (streak, freezes), §21 (offline). Design `Home Archipelago`.

## `GET /api/v1/app/home`

One call draws the tab for the **active** enrollment: the learner, the level's units in order, the current unit's lessons, today against the goal, what is due for review, and the cards and one-time notices to show. Needs a session (guest or member). The phone keeps the last response and shows it at once, then refreshes (S §6.1, §21).

A part the server leaves out isn't shown, as in [me.md](me.md): no `week` or `streak` gives the v0.1 frame (no ring, flame, review box, tab badge or page search); no `review` gives no box and no badge.

### Response `200`

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "learner": {
      "name": "Learner",
      "lessonsDone": 14,
      "welcomeBack": false,
      "emailVerified": false,
      "signIn": "email",
      "stars": null,
      "greetingAudio": null
    },
    "enrollment": {
      "id": "enr_general",
      "trackId": "trk_general",
      "title": "الإنجليزية العامة",
      "audience": "self",
      "kidsMode": false,
      "ordered": true,
      "levelLabel": "level"
    },
    "enrollments": [
      { "enrollmentId": "enr_general", "trackId": "trk_general", "title": "الإنجليزية العامة", "audience": "self", "levelId": "lvl_gen_a2", "levelLabel": "A2", "levelName": "ما قبل المتوسط", "unit": 3, "units": 8, "unitCover": "https://…/farm.webp", "active": true }
    ],
    "level": {
      "id": "lvl_gen_a2",
      "label": "A2",
      "name": "ما قبل المتوسط",
      "cefr": "a2",
      "completed": false,
      "next": { "id": "lvl_gen_b1", "label": "B1", "name": "المتوسط", "cefr": "b1" }
    },
    "units": [
      { "id": "unit_gen_a2_02", "number": 2, "title": { "ar": "عائلتي", "en": "My family" }, "cover": "https://…/home.webp", "status": "done" },
      {
        "id": "unit_gen_a2_03", "number": 3, "title": { "ar": "يوم في المزرعة", "en": "A day on the farm" }, "cover": "https://…/farm.webp", "status": "current",
        "lessons": [
          { "id": "les_voc", "kind": "vocabulary", "title": "كلمات المزرعة", "minutes": 5, "done": true },
          { "id": "les_it", "kind": "interactiveText", "title": "يوم في حياة سارة", "minutes": 7, "done": false, "resume": { "question": 3, "questions": 6, "share": 0.5 } },
          { "id": "les_chat_box", "kind": "conversation", "title": "الصندوق القابل للكسر", "minutes": 5, "done": false, "ai": true, "scenarioId": "sc_fragile_box" },
          { "id": "les_mock", "kind": "unitReview", "title": "مراجعة الوحدة", "minutes": 10, "done": false, "levelCheck": false }
        ]
      },
      {
        "id": "unit_gen_a2_04", "number": 4, "title": { "ar": "في السوق", "en": "At the market" }, "cover": "https://…/market.webp", "status": "locked",
        "lockedBy": { "id": "unit_gen_a2_03", "number": 3 },
        "preview": {
          "goal": "تسأل عن الأسعار وتشتري ما تحتاجه",
          "lessons": [{ "kind": "vocabulary", "title": "كلمات السوق", "minutes": 5 }]
        }
      }
    ],
    "week": {
      "goalMinutes": 10,
      "dayStart": "04:00",
      "today": 3,
      "days": [{ "date": "2026-10-31", "minutes": 14 }, { "date": "2026-11-01", "frozen": true }, { "date": "2026-11-03", "minutes": 7 }, { "date": "2026-11-04" }]
    },
    "streak": { "current": 7, "longest": 12, "freezes": 2, "maxFreezes": 3, "freezesPerWeek": 1, "nextFreezeWeekday": 6 },
    "review": { "wordsDue": 12, "conceptsDue": 3, "minutes": 5 },
    "cards": { "levelCheck": null, "placement": null },
    "events": []
  },
  "error": null,
  "traceId": "…"
}
```

Other frames, as deltas:
- **First day:** `learner.lessonsDone: 0`; unit 1 `current` with every lesson `done: false`, its last lesson `"levelCheck": true` («فحص المستوى»); today's minutes 0; `streak.current` 0; no `review`.
- **Back after a while:** `learner.welcomeBack: true`; `streak.current: 0`; `review` present (the review becomes the path's first station).
- **Level completed:** every unit `done`, none `current`; `level.completed: true`.
- **Cards:** `cards.levelCheck: { "lessonId": "les_mock" }`; `cards.placement: { "estimatedMinutes": { "min": 12, "max": 15 } }`.
- **One-time notices:** `events: [{ "id": "ev_frz_20261102", "kind": "freezeUsed", "on": "2026-11-02", "streak": 7, "freezesLeft": 1 }]` or `[{ "id": "ev_brk_20261103", "kind": "streakBroken", "on": "2026-11-03", "streak": 7 }]`.
- **Emar:** `enrollment { "audience": "schoolStudent", "ordered": false, "levelLabel": "grade" }`, `level { "label": "الصف 7", "name": "الصف السابع", "cefr": null, "next": { "label": "الصف 8", "name": "الصف الثامن" } }`; units after the current one `open` (no `lockedBy`/`preview`), each with `"bookPages": { "from": 30, "to": 41 }`; lessons with `page`.
- **Kids:** `enrollment { "audience": "child", "kidsMode": true }`, `level { "label": "Starter 2", "name": "المواضيع" }`, `learner.stars: 14`; units with both titles, `stars` (0–5) and `titleAudio`; lessons with an English `title`, `image`, `audio`, `stars`; no `review`, `cards` or `events`.

### Fields

| Field | Meaning |
|---|---|
| `learner.name` | The greeting uses its first word: «مساء الخير، أحمد» |
| `learner.lessonsDone` | `0` is the first day; from `1` the email reminder may show |
| `learner.welcomeBack` | No activity for three days or more, by the learner's day (the server decides) |
| `learner.emailVerified`, `signIn` | `email`, `google`, `apple` or `guest` (new here). The reminder itself comes from the account's state on the phone |
| `learner.stars` | Kids: the stars earned in all |
| `learner.greetingAudio` | Kids: what «استمع» in the header plays; null plays nothing |
| `enrollment.id`, `trackId`, `title` | The active track: the capsule, the switch strip |
| `enrollment.audience` | `self`, `child`, `schoolStudent`: the sea's family |
| `enrollment.kidsMode` | The kids' layout |
| `enrollment.ordered` | `false`: nothing locked, «الدرس المقترح», open islands (Emar) |
| `enrollment.levelLabel` | `level`, `grade` or `book`: «المستوى التالي: B1» or «الصف التالي: الصف 8»; unknown reads as `level` |
| `enrollments[]` | Every joined track, exactly as `tracks[]` in [me.md](me.md) |
| `level.id`, `label`, `name` | «A2، ما قبل المتوسط»; a grade shows its `name` |
| `level.cefr` | `preA1` … `c1` or null: the level's sea; unknown reads as null (the general sea) |
| `level.completed` | The horizon opens and «أكملت مستوى A2» shows on every open until the next level starts |
| `level.next` | `{id, label, name, cefr}` or null at the track's last level (no horizon flag). «ابدأ B1» sends `PATCH /api/v1/app/enrollments/{id} {levelId}` ([me.md](me.md)) |
| `units[]` | Every unit of the level, in order |
| `units[].title` | `{ar, en}`; `en` shows beside `ar` for kids only. A plain string is read as the Arabic title |
| `units[].cover` | The island's medal (a circle cut from the cover) |
| `units[].status` | `done`, `current`, `open` or `locked`; unknown reads as `locked`. A `current` unit whose lessons can't be read shows as `open` |
| `units[].bookPages` | `{from, to}`: Emar's sub-line, banner and page search |
| `units[].stars` | Kids: the unit's stars, 0–5 |
| `units[].titleAudio` | Kids: the guide says the unit's name |
| `units[].lockedBy` | `{id, number}`: «تُفتح بعد الوحدة 3» |
| `units[].preview` | Locked units only: `{goal, lessons[{kind, title, minutes}]}` for the preview sheet, without fetching the unit |
| `units[].lessons[]` | The **current** unit's lessons only, as in [lessons.md](lessons.md) `GET /units/{id}`; ignored on other units |
| `…lessons[].ai` | An AI conversation: ✦ and «محادثة ذكية» |
| `…lessons[].levelCheck` | The unit review is the level check (S §12.3): a gate instead of the lighthouse |
| `…lessons[].resume` | `{question, questions, share}`: «تابع من حيث توقفت», «السؤال 3 من 6»; `questions` is new to the lesson's `resume` |
| `week` | As in [me.md](me.md): today's minutes (`days[today].minutes`), the goal, the day start. Once the learner's day passes `today`'s date, the phone moves «today» to the next date (none past the last day, with no minutes) until the next answer |
| `streak` | As in [me.md](me.md), plus `freezesPerWeek` (0–3, from the panel): «يُضاف واحد كل أسبوع»; 0 hides the line |
| `review.wordsDue`, `conceptsDue`, `minutes` | «راجع اليوم: 12 كلمة و3 مفاهيم، نحو 5 دقائق» and «تدرّب»'s badge; `conceptsDue` absent while the mistakes' bank is off |
| `cards.levelCheck` | `{lessonId}` while the level check is available and not taken: «ابدأ الفحص» opens that lesson |
| `cards.placement` | `{estimatedMinutes {min, max}}` while the placement test is put off: «اختبر مستواك» |
| `events[]` | `{id, kind, on, streak, freezesLeft?}`, `kind` `freezeUsed` or `streakBroken`; unknown kinds are skipped. Shown once, then remembered on the phone (the last 20 ids) |

Not in the payload on purpose: the lesson's content (`GET /lessons/{id}`, preloaded for «تابع»), the full unit (`GET /units/{id}` when an island opens), the word bank, the effective settings (`GET /settings`).

### What the app decides itself

The greeting's hours («صباح الخير» until 12:00), the streak at risk from 18:00, and the one-card-at-a-time priority (a one-time notice, the level done, the email, the level check, the deferred test) are app rules (docs/STATUS.md). The opening's once-a-day uses `week.dayStart` (04:00 by default), read on the phone's wall clock.

Back from a lesson, the app waits 2 s for this endpoint before celebrating what the phone knows (a completion still on its way counts); an answer that comes later is shown without a celebration.

### Errors

The common errors (`README.md`). Offline, the phone shows what it kept with «لا يوجد اتصال. الدروس المحمّلة تعمل.».

## Switching track

`PUT /api/v1/app/me/active-enrollment` ([me.md](me.md)), then `GET /api/v1/app/home` again.

## Questions for the backend team

1. Is one home endpoint acceptable, or should the app combine the profile, the level's units and the current unit?
2. Confirm `units[].title {ar, en}`: tracks.md has `title` + `topic`, lessons.md a single `title`.
3. Confirm `welcomeBack` (three days without activity, by the learner's day) and that the server computes it.
4. `review.minutes`: is there an estimate on the server?
5. `events[]`: may the app tell the server a notice was seen (`POST /api/v1/app/home/events/{id}/seen`, safe to repeat), so it doesn't show again on another phone? Not called yet.
6. `resume.questions`, `ai`, `levelCheck`, `preview`, `freezesPerWeek`, `greetingAudio`, `cards`: confirm each, or say where it comes from.
