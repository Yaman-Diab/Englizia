# Tracks

Status: **live** on the dev server for the tracks and their levels; the units are **proposed**. The dev server has one track, General English (demo), whose `levels` come empty from `GET /api/v1/app/tracks` (docs/api/home.md, question 4); the fixtures `app_system_config.json` and `app_tracks_empty.json` were saved before it existed. Mock mode serves the same shapes with the three onboarding tracks (`assets/mock/settings/system_config.json`, `assets/mock/tracks/catalog.json`); delete `trk_emar` from both to see the «قريبًا» state, exactly as hiding the track in the panel would.
Requirements: student doc §3.1–3.2 and §4.2, server doc §5.2 and §19.2.

A track brings its levels with it: there is no levels endpoint. The app keeps them by track for the session, from whichever list it fetched.

## Onboarding: `GET /api/v1/app/system/config`

`SystemConfigDto.onboarding` ([settings.md](settings.md)) lists, for each audience of "who will learn", the published tracks it leads to (`OnboardingAudienceDto {audience, tracks}`). Sent **without a session**: onboarding runs before the account exists. Used by "who will learn", the grade step, "how much English" (where a beginner starts) and "preparing" (the first level of a track without a level step).

| `audience` | The app's choice |
|---|---|
| `adult` | «أنا» (self) |
| `child` | «طفلي» |
| `school_student` | «طالب مدرسة» |

An audience with no track shows «قريبًا» and can't be chosen; an audience the app doesn't know suggests nothing. Several tracks may share an audience; the grade step then takes the one entered by grade.

`OnboardingTrackDto`:

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `id` | uuid | Stable track id | yes |
| `nameAr`, `nameEn` | string, `nameEn` nullable | The track's name; English falls back to Arabic | yes |
| `entryMode` | `placement` · `grade_choice` · `direct` | How the learner enters, which decides the next onboarding steps; an unknown one is a direct start | yes |
| `kidsMode` | bool | Kids mode; the app gives it to each level too | yes (levels) |
| `levelLabel` | `level` · `grade` · `book` | What a level is called for the student | not yet |
| `coverUrl` | string, nullable | The track's cover | not yet |
| `levels` | `GradeLevelDto[]` | The published levels, in display order | yes |

`GradeLevelDto`:

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `id` | uuid | Stable level id | yes |
| `nameAr` | string | The level's name ("السابع", "A2 · ما قبل المتوسط"); shown in both languages | yes |
| `gradeNumber` | int · null | School grade (1–12) for curriculum tracks, the big number on the grade cell | yes |
| `stageLabelAr` | string · null | Group heading on the grade screen ("الحلقة الأولى") | yes |

The first level is where a direct start begins; its place in the list is its order.

## The catalog: `GET /api/v1/app/tracks`

Every published track, for a learner with a session: «أنا»'s «أضف مسارًا» and its «تغيير الصف». Answers `ListDataOfTrackCatalogItemDto` (`{items: [...]}`). `TrackCatalogItemDto` is the onboarding track above plus `descriptionAr`, `descriptionEn` (shown under the name in «أضف مسارًا»), `onboardingAudience` (`null` for a track no audience leads to) and `enrolled` (not read yet). A track's levels are looked for in onboarding's list first, as it needs no session, then here, for a track no audience leads to.

## `GET /api/v1/app/levels/{levelId}/units`

Published units of one level, in display order. "Preparing" (S §4.4) reads the first one right after the account is created, to name it ("جهّزنا وحدتك الأولى" with its title and topic); home gets every unit of the level inside `GET /api/v1/app/home` instead ([home.md](home.md)). Sent with a token. Mock: `assets/mock/tracks/units_<levelId>.json` for `lvl_gen_prea1` and `lvl_emar_07`, `units_default.json` for any other level.

### Response `200`

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": [
    {
      "id": "unit_gen_prea1_01",
      "order": 1,
      "title": "Hello!",
      "topic": { "ar": "التحيات والتعارف", "en": "Greetings and introductions" }
    }
  ],
  "error": null,
  "traceId": "0HN7…"
}
```

| Field | Type | Meaning | Used by the app today |
|---|---|---|---|
| `id` | string | Stable unit id | yes |
| `order` | int | Display order within the level; the first unit is where the level starts | yes (the first unit) |
| `title` | string | The unit's title as the course writes it, usually English ("Hello!", "Unit 1: Back to School"); shown left to right inside Arabic | yes |
| `topic` | `{ar, en}` · `null` | What the unit is about, in the learner's language; books often have none | yes |

A level with no published unit returns an empty list; "preparing" then says the first unit is ready without naming it.

## Questions for the backend team

1. A level has no `nameEn`, `stageLabelEn` or `cefrCode` in `GradeLevelDto` (`EnrollmentLevelDto` has the last two): the English app shows the Arabic names. Add them?
2. A level has no kids mode of its own; the panel sets it by level (server doc §6.6), and «تغيير الصف» marks such a grade «وضع الأطفال». The app takes the track's for now. Add `kidsMode` to `GradeLevelDto`?
3. "Preparing" names the first unit of the level, from the proposed `GET /api/v1/app/levels/{levelId}/units` above. Once the learner has joined, the track's map has the units (docs/api/home.md): is the map the way to read them, so this call isn't needed?
