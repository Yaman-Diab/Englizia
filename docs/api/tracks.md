# Tracks

Status: **live** on the dev server for the tracks and their levels; a level's units are the track's map's. The dev server has one track, General English (demo), whose `levels` come empty from `GET /api/v1/app/tracks`, as only a grade track lists its levels there (the backend's answers of 2026-11-23); the fixtures `app_system_config.json` and `app_tracks_empty.json` were saved before it existed. Mock mode serves the same shapes with the three onboarding tracks (`assets/mock/settings/system_config.json`, `assets/mock/tracks/catalog.json`); delete `trk_emar` from both to see the «قريبًا» state, exactly as hiding the track in the panel would.
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

## A level's units: the track's map

The server has no call for a level's units, and won't: the track's map has them (`GET /api/v1/app/enrollments/{trackId}/map`, [home.md](home.md); the backend's answers of 2026-11-23, tracks.md 3). "Preparing" (S §4.4) names the first unit right after the account is made («جهّزنا وحدتك الأولى»): onboarding has joined the track by then, so the app reads the active track's map and takes its units in their order, each by `titleAr`, with `titleEn` beside it. With the level named (a grade, or a level the catalog lists), the map must be at it, or no unit is named. A track with no published unit, or none joined, names none; "preparing" then says the first unit is ready without naming it.

Mock mode keeps its own example in the shape it had (`assets/mock/tracks/units_*.json`: `{id, order, title, topic {ar, en}}`).

## Questions for the backend team

1. Answered: `GradeLevelDto` carries `nameEn`, `stageLabelEn`, `cefrCode` and `kidsMode` (the grade's own, else the track's), in `GET /app/tracks` and in `system/config`'s onboarding tracks. The app doesn't read them yet: the English app shows the Arabic names, and a grade takes its track's kids mode (STATUS D-124).
