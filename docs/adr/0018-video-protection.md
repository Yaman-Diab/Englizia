# 18. A lesson's video kept from being captured

Status: Accepted · Date: 2026-11-10

## Context
The owner asked that lessons' videos not be copied: no screenshots or screen recordings on Android, and the video hidden from a screen recording on iOS. The two systems allow different things. Android lets an app mark its window secure (`FLAG_SECURE`): screenshots and recordings of it come out black, and the recent apps show no preview. iOS lets no app stop a screenshot, and tells it only after one was taken; it does say while the screen is recorded or mirrored (`UIScreen.isCaptured`).

## Decision
- Only while a video shows. `ProtectedVideo` (`core/security/`) wraps a lesson's player (the grammar and interactive videos' `LessonPlayer`, the kids' song) and holds `ScreenProtection` while it is on screen. The rest of the app stays capturable: a learner can still screenshot a question to ask about it, or a bug to report it.
- Android: holding it sets `FLAG_SECURE` on the window; the last view to let go clears it, so two players never undo each other.
- iOS: while the screen is recorded or mirrored, the player gives way to a cover («الفيديو مخفي أثناء تسجيل الشاشة», with an icon) and pauses, as a recording takes the sound too. Once it stops the video comes back paused, and the learner plays on. Screenshots aren't blocked, as iOS doesn't allow it.
- A little native code, as for the screen kept awake: a method channel on Android (`englizia/screen_secure`) and an event channel on iOS (`englizia/screen_capture`), watched only while a protected view listens. The packages that do this (`no_screenshot`, `screen_protector`) add the same few lines behind a dependency, and some reach for undocumented iOS tricks to blank screenshots, which break between iOS versions.
- It never fails its caller: a platform that refuses leaves the video unprotected, never broken.

## Consequences
- Mirroring a phone to a TV over AirPlay also hides the video on iOS, as the system reports it the same way.
- Android's own screenshots taken for support come out black on a video's screen.
- Real protection of the stream itself (DRM, signed URLs) is the server's and the streaming service's, not decided yet (STATUS D-021).
