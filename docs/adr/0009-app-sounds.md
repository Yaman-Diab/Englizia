# 9. App sounds behind one interface

Status: Accepted · Date: 2026-10-26 · Sounds turned on 2026-11-09

## Context
The requirements ask for short sounds on answer feedback that follow the phone's sound mode, with a light vibration when right and a firmer one when wrong (student doc §7.2), a gentle "try again" and encouragement in kids mode (§13), and sounds around achievements and notifications. The owner wants one app-specific place for sounds, where changing a sound is one line.

## Decision
- `core/audio/`: `AppSound` names every sound by meaning. `soundCatalog` (`sound_catalog.dart`) ties each one to its file in `assets/sounds/`, an optional kids' file in `assets/sounds/kids/`, a volume (the files share a peak, so the volume sets how loud each feels against the others), whether it loads at start, and the shortest gap before it may play again. Changing a sound is its line; adding one is a value and a line. The guide's recorded voice is not an effect and has no line.
- `SoundPlayer` is the only way to play one: `preload`, `play`, `kidsMode`, `holdQuiet`. Cubits take it in their constructor; a widget calls `playSound(sound)`, one line that does nothing where no player is registered, or wraps a card in `SoundOnShow`.
- `AssetSoundPlayer` holds the rules, with the package behind `SoundBackend` so they are tested without a phone:
  - nothing plays when the «المؤثرات الصوتية» setting is off;
  - nothing plays while a `holdQuiet` holds: the microphone while it records (its start sound ends before it records), and a video while it plays. `JustAudioClipPlayer` holds it the same way while a clip plays (STATUS D-050). Ducking under them was the alternative; silence is simpler, and nothing a learner must hear is lost;
  - the same sound again within its gap is dropped (40 ms; a points tick 70 ms), and one still sounding starts over instead of doubling;
  - in kids mode the kids' file plays where there is one; home sets the mode, as it knows the audience;
  - a failure is never seen: a sound that can't play is not heard.
- `JustAudioBackend`: `just_audio` (ryanheise.com, 150/160 points, about 4,150 likes), one player per file, the short ones (right, wrong, tap, the microphone) loaded at start. `audio_session` (the same publisher) sets the session once: `ambient` with `mixWithOthers` on iOS, so the silent switch silences the sounds and the learner's music goes on under them; sonification on Android, asking for no audio focus, so nothing the learner listens to is paused. `audioplayers` was the alternative; its current major needs a newer Flutter than the pin.
- Files are WAV (44.1 kHz, mono, 16-bit), as OGG doesn't play on iOS; silence trimmed, peaks at −3 dBFS. Where each came from is in `assets/sounds/LICENSES.md`. They are bundled, as the app works offline first.

## Consequences
- The sounds now are placeholders synthesized by `tool/sounds/synth.py` (STATUS D-037); a library file replaces one by keeping its name.
- Left silent on purpose: a streak broken (it would feel like a penalty), the back-to-lesson button and the map's move to it, switching track, a finished download, the guest's reminders, and the guide saying a unit's name (a voice, not an effect).
