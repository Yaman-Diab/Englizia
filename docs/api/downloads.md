# Downloads

Status: **proposed** — the app runs on this contract in mock mode (`assets/mock/downloads/manifest.json`, with made-up files); nothing is confirmed by the backend team yet.
Decision: ADR 22 (the owner, 2026-11-18), which overrides student doc §21.

A learner downloads a lesson, or a unit's lessons, to open with no connection. The app keeps the files sealed in its own folder and plays them itself; the server says what a lesson's files are and for how long, through the panel's limits.

## `GET /api/v1/app/lessons/{lessonId}/download`

Everything a lesson needs to open offline. Sent with a session. Asked once before a download (to say its size), once to do it, and again when a download has run out.

```json
{
  "statusCode": 200,
  "message": "Data retrieved successfully",
  "data": {
    "lessonId": "…",
    "lessonVersion": 3,
    "lesson": { "id": "…", "version": 3, "exercises": [] },
    "files": [
      { "url": "https://cdn.example.com/lessons/farm.webp", "kind": "picture", "bytes": 40000, "contentType": "image/webp" },
      { "url": "https://cdn.example.com/lessons/farm.mp3", "kind": "clip", "bytes": 60000, "contentType": "audio/mpeg" },
      { "url": "https://cdn.example.com/lessons/farm/index.m3u8", "kind": "video", "bytes": 800000 }
    ]
  },
  "error": null,
  "traceId": "…"
}
```

| Field | Type | Meaning |
|---|---|---|
| `lessonVersion` | int | A different one later means the download is fetched again |
| `lesson` | object | The lesson exactly as `GET /api/v1/app/lessons/{id}` gives it ([lessons.md](lessons.md)); it is what opens offline |
| `files[].url` | string, absolute | The address the lesson itself names for the file, and where it is fetched. It may be signed: the app tells files apart by the address without its query |
| `files[].kind` | `picture` · `clip` · `video` | A kind the app doesn't know is left out, and the lesson opens without that file |
| `files[].bytes` | int | The file's size; a video's is the size of its lightest rendition, near enough to tell the learner |
| `files[].contentType` | string, optional | Given to the player with a clip |

**Video.** `url` is the lesson's HLS address, a master playlist or one rendition's. The app keeps the lightest rendition, so:
- at least one rendition must have its sound inside its own files (not a separate audio group);
- the stream must be finished (`#EXT-X-ENDLIST`), of whole files (no `BYTERANGE`), MPEG-TS or fMP4;
- it may be plain, or sealed with `AES-128` whose key the app can fetch from the playlist's own address; `SAMPLE-AES` and DRM can't be kept;
- its parts must be fetchable from the addresses the playlist writes (a signature on the playlist's own query isn't carried over to them).

A video that can't be kept fails that lesson's download, and the lesson stays a stream.

**Files are fetched without the account's token**: the file's host gets the address alone, so a link that needs authorisation must carry it itself, for long enough to fetch a lesson.

### Errors

`403` or `404` when the lesson isn't offered for download (not published, not the learner's, or downloads are off for it): the app says «هذا الدرس غير متاح للتنزيل», and removes a download that had run out. The common errors otherwise.

## The panel's limits: `downloads` in `GET /api/v1/app/settings`

Read with the rest of the effective settings ([settings.md](settings.md)). Every number is the panel's; with `enabled` false, or any required one missing, the app shows nothing about downloads.

```json
"downloads": {
  "enabled": true,
  "maxMegabytes": 1024,
  "maxLessons": 40,
  "validDays": 30,
  "minFreeMegabytes": 300,
  "keepDoneDays": 14
}
```

| Field | Meaning |
|---|---|
| `maxMegabytes` | The room all of a phone's downloads may take |
| `maxLessons` | How many lessons a phone may keep |
| `validDays` | How long a download opens with no connection before the server is asked again |
| `minFreeMegabytes` | The room a download must leave on the phone |
| `keepDoneDays` | Optional: a completed lesson's download is removed after this many days; without it they are kept |

## Questions for the backend team

1. Agree the endpoint and its fields, and whether one request for a whole unit's lessons is wanted (the app asks per lesson today).
2. Which lessons may be downloaded: every published one of the learner's level, locked ones too?
3. Can the streaming service give a rendition with its sound inside, as plain or AES-128 HLS, and links that last long enough to fetch a lesson? (STATUS D-021.)
4. Should the server know what a phone has downloaded (to count, or to revoke)? The app tells it nothing today; a download runs out by itself after `validDays`.
5. Agree the `downloads` group and its defaults.
