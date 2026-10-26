# Effective settings

Status: **proposed** — the app runs on this contract in mock mode (`assets/mock/settings/`); nothing is confirmed by the backend team yet.
Requirements: server doc §17.1 (inheritance and reading), §17.7 (motivation), §17.8 (notifications), §19.2 ("the app reads the effective settings on open and caches them"); student doc §4.2 (reminder step) and §20.

## `GET /api/v1/settings`

The global settings after inheritance, as the app needs them before any track is chosen. Available without a token, since onboarding runs before sign-up. Grouped by the panel's sections; each app version reads the groups it knows and ignores the rest, so the response grows with each version (§19.2). Track, level and lesson values arrive with those resources (`docs/api/tracks.md`).

### Response `200`

```json
{
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
  "meta": null,
  "error": null
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

An unknown slot, a malformed time, or a goal or challenge option without its number or label is skipped. A response without any usable time, the reminder text, any goal or challenge option, their defaults or the challenge question is rejected.

### Errors

The common envelope errors (`docs/api/README.md`).

## Questions for the backend team

1. Confirm the path, the grouping and that it is available without a token.
2. Confirm the placeholder name in the reminder body (`{minutes}`; the panel shows it as `{الدقائق}`).
3. Is `averageLessonMinutes` acceptable as a setting (or should the app count lessons another way)? The weekly total is minutes × 7.
4. Times are phone-local "HH:mm" (the learner's time zone), not UTC instants. Confirm, and how the chosen time is sent back with the account (§4.3).
