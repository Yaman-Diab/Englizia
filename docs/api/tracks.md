# Tracks

Status: **proposed** — the app runs on this contract in mock mode (`assets/mock/tracks/`); nothing is confirmed by the backend team yet.
The mock publishes all three onboarding tracks; delete `trk_emar` from `published_tracks.json` to see the «قريبًا» state, exactly as hiding the track in the panel would.
Requirements: student doc §3.1–3.2 and §4.2, server doc §5.2 and §19.2.

## `GET /api/v1/tracks`

Published tracks only (a track is visible when it and everything above it is published), with their **effective** settings after inheritance. No paging: there are a handful of tracks. Sent with or without a token, because onboarding calls it before the account exists.

Request headers: the common ones (`Accept-Language`, `X-App-Version`, `X-Platform`; `Authorization` when signed in).

### Response `200`

```json
{
  "data": [
    {
      "id": "trk_general",
      "title": { "ar": "الإنجليزية العامة", "en": "General English" },
      "description": { "ar": "من الصفر حتى B2، مع اختبار تحديد المستوى", "en": "From zero to B2, with a placement test" },
      "coverUrl": "https://cdn.example.com/tracks/general/cover.webp",
      "order": 1,
      "onboardingAudience": "self",
      "entryMethod": "placementTest",
      "levelLabel": "level",
      "kidsMode": false
    }
  ],
  "meta": null,
  "error": null
}
```

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `id` | string | Stable track id | yes |
| `title`, `description` | `{ar, en}` | Track name and description (description up to 140 chars) | yes (parsed) |
| `coverUrl` | string, absolute | 16:9 cover, WebP | later (track card) |
| `order` | int | Display order set in the panel | yes (sorting) |
| `onboardingAudience` | `"self"` · `"child"` · `"schoolStudent"` · `null` | "Suggested for" on the "who will learn" step; `null` = not suggested | **yes**: an option with no published track shows «قريبًا» and cannot be chosen |
| `entryMethod` | `"placementTest"` · `"gradeSelection"` · `"directStart"` | How the learner enters (decides the next onboarding steps) | yes (parsed) |
| `levelLabel` | `"level"` · `"grade"` · `"book"` | What a level is called for the student | later |
| `kidsMode` | bool | Kids mode at track level (can be overridden per level) | later |

Unknown enum values are treated as the least privileged: an unknown `onboardingAudience` is "not suggested", an unknown `entryMethod` is a direct start.

### Behavior the app relies on

- Hiding a track removes it from this list, so its onboarding option turns «قريبًا» on the next open; learners already enrolled keep access through their own progress, not this list.
- More than one track may share an `onboardingAudience`; the app then lets the learner choose between them (screen not designed yet).

### Errors

The common envelope errors (`docs/api/README.md`); no endpoint-specific codes.

## `GET /api/v1/tracks/{trackId}/levels`

Published levels of one track, in display order, with their effective settings. Used by the onboarding grade step (tracks whose entry method is `gradeSelection`) and later by the home and "Me" screens. Available without a token, like the track list. Mock: `assets/mock/tracks/levels_<trackId>.json`.

### Response `200`

```json
{
  "data": [
    {
      "id": "lvl_emar_07",
      "order": 7,
      "name": { "ar": "السابع", "en": "Grade 7" },
      "schoolGrade": 7,
      "cefr": null,
      "displayGroup": { "ar": "الحلقة الثانية", "en": "Primary, cycle 2" }
    }
  ],
  "meta": null,
  "error": null
}
```

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `id` | string | Stable level id | yes |
| `order` | int | Display order; the first level is where a direct start begins | yes (sorting) |
| `name` | `{ar, en}` | Display name set in the panel ("السابع", "A2 · ما قبل المتوسط") | yes (grade cell label) |
| `schoolGrade` | int 1–12 · `null` | School grade for curriculum tracks | yes (big number on the grade cell; falls back to `order`) |
| `cefr` | `"preA1"` … `"c1"` · `null` | CEFR link, required when the entry method is the placement test | later (placement) |
| `displayGroup` | `{ar, en}` · `null` | Group heading on the grade screen ("الحلقة الأولى"); levels without one go under no heading | yes |

Not in this list on purpose: kids mode and feature overrides per level, and the three "you will be able to…" sentences; they arrive with the level detail when a screen needs them.

## Questions for the backend team

1. Confirm the path, the field names and the enum spellings above.
2. Confirm the list is available without a token (onboarding runs before sign-up).
3. Confirm "effective settings" means the track-level values here and the level-level values in the levels list.
4. Confirm the levels list is available without a token (the grade step runs before sign-up).
