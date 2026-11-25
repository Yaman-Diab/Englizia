# Home: the «تعلّم» tab

Status: **live in part.** The server has no call for home. In its place the app reads three live ones (docs/api/openapi.json) and puts them in the shape below, which the mock still serves whole (`assets/mock/home/`: the general track, Emar, and a child's with `env/mock_kids.json`, with the design's frames as scenarios on the dev page): the account (`GET /api/v1/app/me`), the joined tracks (`GET /api/v1/app/enrollments`) and the active track's map (`GET /api/v1/app/enrollments/{trackId}/map`). Real answers: `test/fixtures/api/app_map_*.json`, `app_enrollments_one.json` and `app_me_guest.json`. The week, the streak, the review, the one-time notices and the level after this one aren't on the server yet, so against it home draws its v0.1 frame (STATUS D-092).
Requirements: student doc §6.1 (home), §6.2 (units), §3.1–§3.2 (tracks), §5.3 (email reminder), §12.3 (level check), §13.5 (kids), §14 (Emar), §15 (streak, freezes), §21 (offline). Design `Home Archipelago`.

## What the server has (live)

### `GET /api/v1/app/enrollments/{trackId}/map`

The track's level as the learner has it: its units, their lessons, and what is open. Needs a session; a track not joined is `404 enrollment.not_found`. It carries an `ETag`, which the app doesn't use yet.

```json
{ "trackId": "…", "levelLabel": "level", "unlockMode": "sequential", "kidsMode": false,
  "features": { "aiConversation": false, "comments": false, "leaderboard": false, "errorBankUi": false },
  "level": { "id": "…", "nameAr": "A1 المبتدئ", "nameEn": "A1 Beginner", "cefrCode": "a1", "gradeNumber": null, "taglineAr": null },
  "nextLessonId": "…", "unitCount": 2,
  "units": [ { "id": "…", "titleAr": "التعريف بالنفس", "titleEn": "About me", "coverUrl": "https://…webp",
      "objectives": [{ "ar": "…", "en": "…" }], "concepts": [{ "nameAr": "…", "nameEn": "…" }], "bookPages": null,
      "lessonCount": 2, "minutes": 15, "state": "unlocked", "test": null,
      "lessons": [ { "id": "…", "versionId": "…", "versionNo": 1, "type": "grammar_video", "titleAr": "…", "titleEn": "…",
          "minutes": 8, "bookPages": null, "state": "completed", "best": { "firstTryCorrect": 6, "questionCount": 6 } } ] } ] }
```

`unlockMode` is `sequential` or `all_open`; a unit's `state` is `locked`, `unlocked` or `completed`; a lesson's is `locked`, `available`, `in_progress` or `completed`.

### How home is put together

One read of the tracks, then the account and the active track's map together (`server_home.dart`):

| From | In the app's shape |
|---|---|
| `GET /app/me`: `displayName`, `emailVerified`, `accountType`, `authMethods` | `learner.name`, `emailVerified`, `signIn`: `guest` for a guest account (its `authMethods` is empty), else `email` with `password` among `authMethods`, then `google`, then `apple` |
| The map's completed lessons | `learner.lessonsDone`: those of this level only, as the server has no count of all (question 2) |
| `GET /app/enrollments` `items[]` | `enrollments[]`: the track's id stands for the enrollment's too, as the server names an enrollment by its track; `track.nameAr`, the level's names, `unitNo`, `unitCount`, `isActive`. The active one's cover is its unit's, the others' their track's |
| An enrollment's `track.onboardingAudience` | `audience`: `adult`, `child` or `school_student`. An enrollment without it is read from its `child`, its track's `kidsMode` and `levelLabel` |
| `unlockMode` | `enrollment.ordered`: false for `all_open` |
| `level`, `nextLevel` | `level.id`; `label` is its CEFR code (`A1`, `Pre-A1`), or its name when it has none; `name` is `nameAr` without that code in front; `cefr`. `level.completed` once every unit is `completed`. `level.next` is `nextLevel`, the first level published after this one, named the same way; none after the last |
| `units[].state` | `completed` is `done`; `unlocked` is `current` for the unit that holds `nextLessonId` (else the first unlocked one) and `open` for any other; `locked` is `locked`, named after the unit before it in a track that opens in order |
| `units[].lessons[]` | The current unit's `lessons[]`, and a locked unit's `preview`: `type` as the app's `kind`, `titleAr`, `minutes`, `bookPages.from` as `page`, `done` for `state: completed`. Where a lesson stopped is the phone's own |
| `units[].test` | The unit's last stone, a `unitReview` done once `passed`, which opens the test; home's counts and preview leave it out ([unit-tests.md](unit-tests.md)) |
| `levelCheck` | `cards.levelSuggestion`, as the server sends it: «انتقل / ابقَ» ([unit-tests.md](unit-tests.md)) |
| `GET /app/placement?trackId=`, asked only while the enrollment's `placementPending` | `cards.placement.estimatedMinutes`, from `test.estimatedSeconds` without and with the deciding stage; home shows without the card if that call fails |

With no track joined there is no home to draw, and home says it failed.

Not used yet: `features`, `lessons[].best` and `versionId`, `taglineAr`, and the English names of the level and the lessons (STATUS D-124).

### A unit's screen

The server has no call for one unit either: its screen is read from the same map (`unitFromMap`), in the shape of `GET /units/{id}` in [lessons.md](lessons.md). Its number is its place in the level; `objectives` are «ستتعلّم أن…» and `concepts` «قواعد الوحدة», in Arabic; the unit that locks it and the next one are its neighbours. The app remembers which track held the last unit, and asks for the active one again when a unit isn't there.

## The app's own shape: `GET /api/v1/app/home` (mock mode)

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
| `enrollment.id`, `trackId`, `title` | The active track: the capsule, the switch strip. Before a first home has come, the capsule reads the profile's active track ([me.md](me.md)) |
| `enrollment.audience` | `self`, `child`, `schoolStudent`: the sea's family |
| `enrollment.kidsMode` | The kids' layout |
| `enrollment.ordered` | `false`: nothing locked, «الدرس المقترح», open islands (Emar) |
| `enrollment.levelLabel` | `level`, `grade` or `book`: «المستوى التالي: B1» or «الصف التالي: الصف 8»; unknown reads as `level` |
| `enrollments[]` | Every joined track, exactly as `tracks[]` in [me.md](me.md) |
| `level.id`, `label`, `name` | «A2، ما قبل المتوسط»; a grade shows its `name` |
| `level.cefr` | `preA1` … `c1` or null: the level's sea; unknown reads as null (the general sea) |
| `level.completed` | The horizon opens and «أكملت مستوى A2» shows on every open until the next level starts |
| `level.next` | `{id, label, name, cefr}` or null at the track's last level (no horizon flag). «ابدأ B1» sends `PUT /api/v1/app/enrollments/{trackId}/level {levelId}` ([me.md](me.md)) |
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
| `week` | As in [me.md](me.md): the Saturday-to-Friday week, today's minutes (`days[today].minutes`), the goal, the day start. Once the learner's day passes `today`'s date, the phone moves «today» to the day of that date when it is in the week, or to none (no minutes) when it isn't, until the next answer |
| `streak` | As in [me.md](me.md), plus `freezesPerWeek` (0–3, from the panel): «يُضاف واحد كل أسبوع»; 0 hides the line, and a missing one reads as 1 (docs/STATUS.md D-096) |
| `review.wordsDue`, `conceptsDue`, `minutes` | «راجع اليوم: 12 كلمة و3 مفاهيم، نحو 5 دقائق» and «تدرّب»'s badge on home; `conceptsDue` absent while the mistakes' bank is off. ASSUMPTION(api): the same counts as the word bank's due words, which give the badge on «تدرّب» itself; the two mocks disagree (docs/STATUS.md D-103) |
| `cards.levelCheck` | `{lessonId}` while the level check is available and not taken: «ابدأ الفحص» opens that lesson |
| `cards.placement` | `{estimatedMinutes {min, max}}` while the placement test is put off: «اختبر مستواك» |
| `events[]` | `{id, kind, on, streak, freezesLeft?}`, `kind` `freezeUsed` or `streakBroken`; unknown kinds are skipped. Shown once, then remembered on the phone (the last 20 ids) |

Not in the payload on purpose: the lesson's content (`GET /lessons/{id}`, preloaded for «تابع»), the full unit (`GET /units/{id}` when an island opens), the word bank, the effective settings (`GET /settings`).

### What the app decides itself

The greeting's hours («صباح الخير» until 12:00) and the streak at risk from 18:00 until midnight are app rules (docs/STATUS.md D-096). The learner's day starts at midnight on their clock, for the streak, the days learned and the opening's once-a-day: the server has no setting for it (the backend's answers of 2026-11-23, §3); a `week.dayStart` the mock sends is still read. The one-card-at-a-time priority (a one-time notice, the level done, the email, the level check, the deferred test) is the design's, applied by `HomeRules.notices`.

### The next level

On a track that isn't chosen by grade the server moves the learner to the next published level by itself once the last unit is done, says so in the sync's reply (`levels: [{trackId, fromLevelId, toLevelId}]`), and refuses the change (`PUT …/level` answers `422 enrollment.grade_change_not_allowed`); with the next level not published yet, the learner stays at the one completed and moves on the first `GET /app/enrollments` after it is. On a grade track (Emar) the learner doesn't move alone: «الصف الثامن» sends `PUT /api/v1/app/enrollments/{trackId}/level` with `nextLevel.id`. So «ابدأ B1» sends the change, and when the server refuses it that way only asks for home again. Home doesn't celebrate a level the server moved past by itself: it shows the new level as it comes (STATUS D-126).

Back from a lesson, the app waits 2 s for this endpoint before celebrating what the phone knows (a completion still on its way counts); an answer that comes later is shown without a celebration.

### Errors

The common errors (`README.md`). Offline, the phone shows what it kept with «لا يوجد اتصال. الدروس المحمّلة تعمل.».

## Switching track

`PUT /api/v1/app/enrollments/{trackId}/active` ([me.md](me.md)), then home again: the tracks, and the new active one's map.

## Questions for the backend team

1. Home is put together from the account, the tracks and the map. Where will the rest come from: the week (minutes a day against the goal, and the day's start), the streak and its freezes, what is due for review, and the one-time notices (a freeze used, the streak broken)?
2. The lessons a learner has finished in all, for the first day and the email reminder: the map only has this level's.
3. A lesson `in_progress`: is where it stopped kept, for another phone?
4. Answered (B-33b, 2026-11-24): a unit's `test` is its unit test's state ([unit-tests.md](unit-tests.md)).
5. `welcomeBack` (three days without activity, by the learner's day), the AI's conversation among a unit's lessons, a kid's stars and recorded titles: will the map carry them?
