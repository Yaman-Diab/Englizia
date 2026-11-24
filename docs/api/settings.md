# Effective settings

Status: **proposed**, and not on the server until v0.5: where the effective settings will live isn't decided (the backend's answers of 2026-11-23, settings.md 1). Until then the server answers `GET /api/v1/app/settings` with `404 route.not_found`, and the app reads the bundled ones in its place (`assets/mock/settings/effective.json`), the goals limited to the minutes `system/config` offers (`dailyGoalOptions`): onboarding's goal, challenge and reminder, the settings' goal and reminder, and the downloads' limits run on them, as the backend asks. Mock mode serves the same file. `system/config` below is live.
Requirements: server doc §17.1 (inheritance and reading), §17.7 (motivation), §17.8 (notifications), §19.2 ("the app reads the effective settings on open and caches them"; the app versions); student doc §4.2 (reminder step) and §20.

## `GET /api/v1/app/settings`

The global settings after inheritance, as the app needs them before any track is chosen. Available without a token, since onboarding runs before sign-up. Grouped by the panel's sections; each app version reads the groups it knows and ignores the rest, so the response grows with each version (§19.2). Track, level and lesson values arrive with those resources (`docs/api/tracks.md`).

### Response `200`

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "motivation": {
      "dailyGoalOptions": [
        { "minutes": 5, "label": { "ar": "مريح", "en": "Easy" } },
        { "minutes": 10, "label": { "ar": "قياسي", "en": "Standard" } },
        { "minutes": 15, "label": { "ar": "جاد", "en": "Serious" } },
        { "minutes": 20, "label": { "ar": "مكثّف", "en": "Intensive" } }
      ],
      "defaultDailyGoal": 10,
      "averageLessonMinutes": 10,
      "challengeOptions": [
        { "days": 7, "label": { "ar": "جيد", "en": "Good" } },
        { "days": 14, "label": { "ar": "رائع", "en": "Great" } },
        { "days": 30, "label": { "ar": "مذهل", "en": "Amazing" } },
        { "days": 40, "label": { "ar": "مثالي", "en": "Perfect" } }
      ],
      "defaultChallenge": 7,
      "challengeQuestion": { "ar": "من يحدد هدفًا يستمر أكثر. كم يومًا تتحدى نفسك؟", "en": "People who set a goal stick with it longer. How many days will you challenge yourself?" }
    },
    "notifications": {
      "reminderTimes": [
        { "slot": "morning", "time": "08:00" },
        { "slot": "noon", "time": "13:00" },
        { "slot": "evening", "time": "20:00" }
      ],
      "defaultReminderSlot": "evening",
      "dailyReminder": {
        "enabled": true,
        "title": { "ar": "حان وقت درسك اليومي", "en": "Time for your daily lesson" },
        "body": { "ar": "{minutes} دقائق فقط وتحافظ على أيامك المتتالية", "en": "Just {minutes} minutes keeps your streak going" }
      }
    }
  },
  "error": null,
  "traceId": "0HN7…"
}
```

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `motivation.dailyGoalOptions[]` | `{minutes, label}`, four of them | The goal choices and the panel's word for each (§17.7: «مريح», «قياسي», «جاد», «مكثّف»); the app sorts them by minutes | yes (the goal step) |
| `motivation.defaultDailyGoal` | int (minutes) | The preselected goal; when it is not among the options the first one is used | yes |
| `motivation.averageLessonMinutes` | int (minutes), optional | How long an average lesson takes, so the goal step can say "≈ درس ونصف يوميًا" (10 minutes → one lesson). **Our proposal**: §17.7 names no such setting. Without it the preview shows the weekly total only | yes |
| `motivation.challengeOptions[]` | `{days, label}`, four of them | The streak challenge lengths and the panel's word for each (§17.7); the app sorts them by days | yes (the challenge step) |
| `motivation.defaultChallenge` | int (days) | The preselected length; when it is not among the options the first one is used | yes |
| `motivation.challengeQuestion` | bilingual text | The guide's question on the challenge step, as edited in the panel (§17.7) | yes |
| `notifications.reminderTimes[].slot` | `morning` \| `noon` \| `evening` | Which preset this is; the app names and draws it | yes |
| `notifications.reminderTimes[].time` | `"HH:mm"`, 24-hour, phone time | The preset's time (§17.8) | yes |
| `notifications.defaultReminderSlot` | slot | The preselected time (§17.8: evening) | yes |
| `notifications.dailyReminder.enabled` | bool | Whether the daily reminder is on | not yet |
| `notifications.dailyReminder.title` / `.body` | bilingual text | The reminder's text as edited in the panel; `{minutes}` is the learner's daily goal | yes (the preview) |
The app's versions are not here: they come from `GET /api/v1/app/system/config` (below).

An unknown slot, a malformed time, or a goal or challenge option without its number or label is skipped. A response without any usable time, the reminder text, any goal or challenge option, their defaults or the challenge question is rejected.

The `downloads` group (the limits for downloaded lessons) is in [downloads.md](downloads.md).

### Errors

The common errors (`docs/api/README.md`).

## `GET /api/v1/app/system/config`

Live (docs/api/openapi.json `SystemConfigDto`), answered **without a session** and for the platform the `X-Platform` header names. Real answer: `test/fixtures/api/app_system_config.json`; mock: `assets/mock/settings/system_config.json`.

| Field | Meaning | Used by the app today |
|---|---|---|
| `minSupportedVersion` | An older installed version stops at the update screen, with no way past it (student doc §4.1) | yes (the splash) |
| `latestVersion` | An older one gets a reminder on home, once a day | yes |
| `storeUrl` | The app's store page. Android opens Google Play's app first and this page after it; iOS opens this page only. «شارك التطبيق» shares it too | yes |
| `onboarding` | The tracks each audience of "who will learn" leads to, with their levels ([tracks.md](tracks.md)) | yes |
| `dailyGoalOptions` | The goals' minutes, each with its points (`{minutes, xp}`) | not yet: the goal step needs each choice's name ("مريح"), the default and a lesson's length, which only `GET /api/v1/app/settings` has (question 6) |
| `supportWhatsapp` | Support's WhatsApp number; «أنا» and the settings open it, before the profile's own | yes |
| `privacyUrl`, `termsUrl` | The legal pages, opened outside the app; an `https` one only, else the app's placeholder page | yes |
| `aiEnabled` | The AI features' switches | not yet |

A version that isn't a release number (a build `+12` or a tag `-beta` is ignored) or a link that isn't `https` is left out alone, so it decides nothing. The phone keeps the three, so an open without a connection still stops a version too old to run (ADR 19).

**The server enforces the minimum itself**: every `/api/v1/app/` call carrying an `X-App-Version` below `minSupportedVersion` answers `426 app.update_required` (`test/fixtures/api/app_update_required.json`; the auth calls don't). The app shows the update screen on it, whenever it comes.

## Questions for the backend team

1. Confirm the path, the grouping and that it is available without a token.
2. Confirm the placeholder name in the reminder body (`{minutes}`; the panel shows it as `{الدقائق}`).
3. Is `averageLessonMinutes` acceptable as a setting (or should the app count lessons another way)? The weekly total is minutes × 7.
4. Times are phone-local "HH:mm" (the learner's time zone), not UTC instants. Confirm, and how the chosen time is sent back with the account (§4.3).
5. `system/config`'s `dailyGoalOptions` has the minutes and points only. Will the effective settings above (each goal's name, the default, a lesson's length, the streak challenge and the reminder times) come, or should they join `system/config`? Until then the goal, challenge and reminder steps run on the mock settings only.
6. «شارك التطبيق» shares `storeUrl`, which is this platform's store only. Could `system/config` carry one link for both stores (a web page that sends each phone to its own)?
