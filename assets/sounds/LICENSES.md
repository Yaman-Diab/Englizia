# Sound effects: where each file came from

**Every file here is temporary.** They are synthesized by
`tool/sounds/synth.py` (numpy only, a fixed seed, so the same files come out
every time) and owned by the project: no third-party license, no attribution.

Why they aren't from a sound library yet (2026-11-09): the CC0 libraries
(Kenney.nl, Pixabay) refused automated downloads (HTTP 403), and Kenney ships
OGG, which can't be converted on the build machine (no ffmpeg or sox). Mixkit
served WAV files, but its *Sound Effects Free License* text couldn't be read in
full, and other sources say it forbids redistributing the files without
significant change, which a bundled app file may be. A library file replaces a
temporary one by keeping its name (or by changing its line in
`lib/core/audio/sound_catalog.dart`); its row here then names the source, the
link, the license and the author.

All files: WAV, 44.1 kHz, mono, 16-bit; silence trimmed; peak −3 dBFS (the
kids' «try again» −5.6 dBFS, to sound as loud as the grown-ups' one).

| File | Sounds like | Length | Source | License | Status |
|---|---|---|---|---|---|
| `correct.wav` | Two warm marimba notes up, G5 to C6 | 0.48 s | `tool/sounds/synth.py` | project's own | temporary |
| `incorrect.wav` | Two soft, damped marimba notes down, E5 to B4 | 0.32 s | `tool/sounds/synth.py` | project's own | temporary |
| `tap.wav` | A light woodblock knock | 0.09 s | `tool/sounds/synth.py` | project's own | temporary |
| `lesson_complete.wav` | Marimba C-E-G up to a C major chord, a bell on top | 1.72 s | `tool/sounds/synth.py` | project's own | temporary |
| `achievement.wav` | A marimba arpeggio over two octaves to a full chord, bells and sparkle | 2.55 s | `tool/sounds/synth.py` | project's own | temporary |
| `island_unlock.wav` | A rising airy shimmer with five glass bells | 1.45 s | `tool/sounds/synth.py` | project's own | temporary |
| `daily_goal.wav` | A warm swell catching, then two bell glints | 1.10 s | `tool/sounds/synth.py` | project's own | temporary |
| `mic_on.wav` | A rounded blip gliding up, E5 to B5 | 0.15 s | `tool/sounds/synth.py` | project's own | temporary |
| `mic_off.wav` | A rounded blip gliding down, B5 to E5 | 0.15 s | `tool/sounds/synth.py` | project's own | temporary |
| `save_word.wav` | A soft bubble pop | 0.12 s | `tool/sounds/synth.py` | project's own | temporary |
| `freeze.wav` | A tiny crackle, four cold glass bells, a frosty shimmer | 1.05 s | `tool/sounds/synth.py` | project's own | temporary |
| `notification.wav` | Marimba E5, C6, G5: the app's three-note signature | 1.40 s | `tool/sounds/synth.py` | project's own | temporary |
| `xp_tick.wav` | A very short, high woodblock tick | 0.04 s | `tool/sounds/synth.py` | project's own | temporary |
| `card_flip.wav` | A light paper flick | 0.14 s | `tool/sounds/synth.py` | project's own | temporary |
| `kids/correct.wav` | Xylophone C6-E6-G6, quick and bright | 0.60 s | `tool/sounds/synth.py` | project's own | temporary |
| `kids/incorrect.wav` | A soft spring boing, wobbling down | 0.43 s | `tool/sounds/synth.py` | project's own | temporary |
| `kids/lesson_complete.wav` | A xylophone run, a slide whistle up, a final chord | 1.85 s | `tool/sounds/synth.py` | project's own | temporary |
| `kids/star.wav` | Four quick bell notes up, with a twinkle | 0.70 s | `tool/sounds/synth.py` | project's own | temporary |
| `kids/bulbul.wav` | Two little bird chirps | 0.22 s | `tool/sounds/synth.py` | project's own | temporary |
