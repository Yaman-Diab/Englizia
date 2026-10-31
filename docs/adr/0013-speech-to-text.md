# 13. Speech to text on the phone's own engine

Status: Accepted · Date: 2026-10-31

## Context
"Repeat the sentence" (S §7.3, template 7) needs what the learner said as text, and shadowing, conversation and "speak and answer" will need the same microphone (S §7.5). The app must only measure the words caught, never call it pronunciation (S §2), and no recording may be kept.

## Decision
- `speech_to_text`, at 7.4.0: 150/160 points, 1625 likes, about 868k downloads, verified publisher `csdcorp.com`, Android and iOS (numbers from pub.dev, 2026-10-31). 7.5.0 needs Flutter 3.44, past the pin. The alternatives are far weaker: `stts` has 41 likes, and `vosk_flutter` 110/160 points with no publisher. Owner's choice, 2026-10-31.
- Behind `SpeechListener` in `core/audio`, so the package and the engine change in one place; mock mode uses the real one too, as a simulation would say nothing about the experience.
- `MicCubit` holds the microphone's phases, apart from the session (ADR 11). The voice level goes on a stream, never through the state, and only the rings repaint with it.
- Permission goes through `permission_handler`, already in the app, after a sheet that says why.
- Only counts leave the phone: words heard and total words. Neither the sound nor the text is kept or sent.
- The share of words needed is the panel's (`speechPassPercent`): without it the question can't be judged, so it is skipped like any broken question. The silence and time limits are the requirement's own (2 s, 15 s).

## Consequences
The phone's engine decides quality and availability: it may be missing on some Android phones, and may need a connection. A phone with none reads as "we didn't hear you", with "I can't speak now" as the way past. Whether Google's engine works for learners in Syria hasn't been checked (D-063). Cloud recognition (S §16) would be another `SpeechListener`.
