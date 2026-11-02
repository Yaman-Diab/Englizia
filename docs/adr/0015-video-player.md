# 15. The video player

## Context
The grammar video needs HLS, a speed, a position and buffering on Android and iOS, in a player whose controls follow the design, and the screen must stay on while it plays (S §8.1). The video hosting service is still an open decision (D-021).

## Decision
- `video_player` from flutter.dev, behind `VideoEngine` in `core/video`, as the design draws its own controls and `chewie` would only add its own. `media_kit` scores lower and brings native libraries; `better_player_plus` has no pub score.
- A quality is another source: the contract sends one URL per quality, and changing it reopens the video at the same place. So it doesn't depend on the player's track selection or on the hosting service.
- The screen stays on through a small native channel, `englizia/screen_awake`. `wakelock_plus` can't be added: its versions conflict with `connectivity_plus` through `dbus`, or need a newer Flutter than the pin, and existing dependencies aren't replaced.

## Consequences
`GrammarLessonCubit` gives commands and follows snapshots, and tests use a fake engine. Moving the Flutter pin allows reconsidering `wakelock_plus` and deleting the channel.
