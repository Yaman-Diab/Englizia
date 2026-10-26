# 9. App sounds behind one interface, silent for now

Status: Accepted · Date: 2026-10-26

## Context
The requirements ask for short sounds on answer feedback that follow the phone's sound mode (student doc §7.2), a gentle "try again" and encouragement in kids mode (§13), and sounds around achievements and notifications. The owner wants a single, app-specific place for sounds, but no sound in the app for now.

## Decision
- `core/audio/`: `AppSound` lists every sound by meaning (correct, incorrect, lesson complete, goal reached, achievement, notification); `SoundPlayer` is the only way to play one (`preload`, `play`).
- DI registers `SilentSoundPlayer`, which plays nothing. Screens may already call `sl<SoundPlayer>().play(...)` where a sound belongs; turning sounds on changes the registration, not the screens.
- `play` never throws and never waits on the user: a missing file, muted phone or disabled setting simply produces no sound.

## When sounds are turned on
- Files go to `assets/sounds/<value>.mp3` (short, normalized, licensed).
- Implementation candidate: `just_audio` (ryanheise.com, 150/160 points, ~4k likes, Flutter ≥3.27, so compatible with the pin), with an audio session that respects the iOS silent switch and Android's media volume. `audioplayers` is the alternative, but its current major needs Flutter 3.44. Choose by the package criteria in `CLAUDE.md` at that time.
- A user setting to mute sounds, and haptics (light on correct, medium on wrong, §7.2) kept separate from sounds.
