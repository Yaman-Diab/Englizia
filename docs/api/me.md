# Me: the learner's profile

Status: **live in part.** `GET /api/v1/app/me/profile` is on the dev server with the names below (the backend's answers of 2026-11-23, §1.2), and so are the name (`PUT /api/v1/app/me`), the track's switch and the grade's change. Real answer: `test/fixtures/api/app_me_profile_guest.json`. It sends the name, the email and whether it is confirmed, `learningSince`, `accountNumber`, `whatsapp` (support's number), `signIn` (`email`, `google`, `apple`, `guest` or `trial`), the tracks, `lessonsDone` (every lesson finished, in every track), `learningDays` (the days with at least one lesson answer) and the last `placement`; a field with no value is left out, in this response alone. The week, the streak, points, stars (v1.0) and the words (v0.4) aren't built, so «أنا» draws its v0.1 frame against the server. A track's `audience` is `adult`, `child` or `school_student`; its `enrollmentId` is its `trackId`. The mock (`assets/mock/me/`, a child's with `env/mock_kids.json`) still serves the whole proposed shape.

From the backend (2026-11-23): a learner keeps up to 3 freezes, one more each Saturday, each used by itself on a day missed; the week runs Saturday to Friday, seven days in order; changing the level keeps every lesson's progress, and coming back to a level shows its lessons done.
Requirements: student doc §19.1 («أنا»), §13.5 (kids), §15 (streak and freezes), §12 (the placement test's result and its wait), §14 (Emar's grades). Design `Me v2`.

## `GET /api/v1/app/me/profile`

Everything «أنا» shows, in one response. Needs a session. The phone keeps the last one, so the tab opens at once and offline. A part the server leaves out isn't shown: a v0.1 server can send only the name, the tracks and the two counts.

### Response `200`

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "name": "Learner",
    "email": "user@example.com",
    "emailVerified": true,
    "learningSince": "2026-10-01",
    "accountNumber": "EZ-0000",
    "whatsapp": "+000000000000",
    "tracks": [
      {
        "enrollmentId": "enr_general",
        "trackId": "trk_general",
        "title": "الإنجليزية العامة",
        "audience": "self",
        "levelId": "lvl_gen_a2",
        "levelLabel": "A2",
        "levelName": "ما قبل المتوسط",
        "unit": 3,
        "units": 8,
        "unitCover": "https://…/farm.webp",
        "active": true
      }
    ],
    "lessonsDone": 18,
    "learningDays": 23,
    "wordsSaved": 64,
    "stars": null,
    "streak": { "current": 7, "longest": 12, "freezes": 2, "maxFreezes": 3, "nextFreezeWeekday": 6 },
    "points": { "total": 1240, "week": 86 },
    "week": {
      "goalMinutes": 10,
      "dayStart": "04:00",
      "today": 4,
      "days": [{ "date": "2026-11-01", "minutes": 14 }, { "date": "2026-11-03", "frozen": true }, { "date": "2026-11-06" }]
    },
    "placement": { "level": "A2", "takenAt": "2026-09-25", "retestAt": "2026-11-17", "waitDays": 30 },
    "wordBank": { "words": 48, "due": 12 }
  },
  "error": null,
  "traceId": "0HN7…"
}
```

| Field | Meaning |
|---|---|
| `name`, `email`, `emailVerified` | As `GET /api/v1/app/me`; a guest has no email and shows «ضيف» |
| `learningSince` | «يتعلّم منذ أكتوبر 2026» |
| `accountNumber` | Shown under the WhatsApp row with a copy button, so support can find the account |
| `whatsapp` | Support's number, from the panel; the row opens a chat with it. Absent: no support rows (v0.1) |
| `tracks[]` | Every track joined, each with its own progress; one is `active` |
| `tracks[].audience` | `self`, `child` or `schoolStudent`, as the tracks' `onboardingAudience`: it picks the track's sea and, for `child`, the kids' «أنا» |
| `tracks[].levelLabel` | Short, on the picture's badge: «A2», «ص7»; empty for a track with no levels |
| `tracks[].levelName` | «ما قبل المتوسط», «الصف السابع»: the toast after a change says it |
| `tracks[].unit`, `units` | The unit reached (from 1) of how many, for the chain of islands |
| `tracks[].unitCover` | The current unit's cover, in the band's medal |
| `lessonsDone`, `learningDays` | «دروس مكتملة», «أيام تعلّم» (a day counts by the track's day start and the learner's time zone) |
| `wordsSaved` | «كلمات محفوظة» (v0.4); kids: «24 كلمة» |
| `stars` | Kids only: the stars earned in all |
| `streak` | Days in a row the daily goal was reached; `freezes` of `maxFreezes` left, and the weekday (`1` Monday … `7` Sunday) the next one is added. Absent before v1.0 |
| `points` | XP in all and this week. Absent before v1.0 |
| `week.days[]` | The week from Saturday to Friday that holds today (seven days, the first Saturday): `minutes`, or `frozen`, or neither for a day still to come. `today` is its index, Saturday being 0. Decided by the owner, 2026-11-08; the freezes are also added on Saturday morning (SV §17.7) |
| `week.goalMinutes`, `dayStart` | The daily goal and when a day starts (`HH:mm`), both from the effective settings |
| `placement` | The last placement test: the level, when, when it can be taken again, and the whole wait (`waitDays`) for the ring |
| `wordBank` | The bank's words and those due today, for its row |

### Errors

The common errors (`README.md`).

## `PUT /api/v1/app/me`

«تعديل الاسم». Confirmed by the OpenAPI: it takes `{displayName, timeZone, uiLanguage}`, all required, so the app reads `GET /api/v1/app/me` first and sends the other two back unchanged.

## `PUT /api/v1/app/enrollments/{trackId}/active`

«مساراتك»: makes another joined track the active one, with no body; an enrollment is its track's. Each keeps its own progress. Answers the enrollments (`ListDataOfEnrollmentDto`), which the app doesn't read: it fetches the profile again. Live.

## `PUT /api/v1/app/enrollments/{trackId}/level`

«تغيير الصف» and home's «ابدأ B1»: `ChangeLevelRequest { "levelId": "…" }` moves the learner to another level of the track, which keeps its own progress. Answers the enrollment (`EnrollmentDto`), not read. The grades are the track's levels in `GET /api/v1/app/tracks` ([tracks.md](tracks.md)); a grade is marked «وضع الأطفال» by its track's kids mode until the server gives one per level. Live.

## The goal and the reminder: `GET /api/v1/app/me`, `PUT /api/v1/app/me/learning`

The settings that follow the account (S §19.2, design `Settings`). Read from the account (`UserDto.dailyGoalMinutes`, `UserDto.reminderTime` as `"HH:mm:ss"` or null); each change sends `UpdateLearningRequest`:

```json
{ "dailyGoalMinutes": 10, "reminderTime": "20:00:00" }
```

| Field | Meaning |
|---|---|
| `dailyGoalMinutes` | One of the panel's daily goals (`dailyGoal.options` in the effective settings) |
| `reminderTime` | `HH:mm:ss` in the learner's time zone, or `null` for none |

Live; seen on the dev server: `test/fixtures/api/app_me_guest.json`.

«الإشعارات» (every kind or none, ADR 16: the goal's reminder, the warning before the streak breaks, a teacher's reply) has no field on the server, so the phone keeps it (STATUS D-117).

The appearance, sound effects, vibration and video quality stay on the phone. The profile also says how the learner signs in, `signIn`: `email` (a password to change), `google` or `apple`.

## `POST /api/v1/auth/password/change`

«تغيير كلمة المرور». Live (docs/api/openapi.json): `ChangePasswordRequest { currentPassword, newPassword, deviceId, platform }`, the new one by the sign-up rule. It answers with a `TokenResponse`, the session this phone carries on with, which the app keeps in place of its own (the old one may be over with the account's others). An answer with no tokens keeps the session as it is.

A wrong current password is `400 auth.current_password_invalid` (a 400, as the session still stands), said under its field; an account that signs in with Google or Apple only is `409 auth.password_not_set`, and five wrong tries `429 auth.locked_out` with `Retry-After`, both shown in the band. These are from the document, not yet seen on the dev server. A `401` makes the app refresh the session once and try again before it shows the failure.

## `DELETE /api/v1/app/me`

«حذف الحساب», which Google Play requires inside the app (and on a web page). A password account sends `{ "password": "…" }`, a wrong one being a `400` on `password`; a Google or Apple account signs in again first; how it proves that to the server isn't agreed (docs/api/auth.md, question 4), so the app's button for it opens a placeholder. Everything goes: progress in every track, saved words, test results. `204`, then the app ends the session. Proposed.

## Questions for the backend team

1. The notifications' switch: where does the server keep it, so it follows the account to another phone? Confirm the deletion above and its error code for a wrong password.
2. Joining another track from «أنا» (`«انضم»`): `POST /api/v1/app/enrollments` (`JoinTrackRequest {trackId, start, levelId, child}`) enrols; the flow per entry method (the placement test, the grade step) still has no design.
