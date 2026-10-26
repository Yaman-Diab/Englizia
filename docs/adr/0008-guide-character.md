# 8. The guide character is drawn in code from pose data

Status: Accepted · Date: 2026-10-26

## Context
The guide ("بلبل", a temporary name) appears on the welcome, onboarding, empty, offline and kids screens with a fixed expression per situation (requirements v3.0 §22), and more poses will be added over time. The approved drawing (Claude Design `Guide.dc.html`) is not an image: it is a parametric vector made of rounded shapes, with a table of expressions that differ only in arm positions, hand shapes, eyes, brows, mouth, cheeks and the speech tuft, plus props (key, headphones) and a light rim in dark mode. The welcome screen adds an idle loop (wave, float, blink). Older screens in the designs still use a previous drawing; §27 says the current one wins.

## Decision
- `core/design_system/mascot/` holds the character: `Mascot` (the widget every screen uses), `MascotExpression` (an enum whose values carry their `MascotPose`), `MascotPose` (pure data), `MascotPainter` (a `CustomPainter` that draws the 180×180 design space), `MascotPalette` (light/dark art colors) and `MascotFrame` (the idle loop as a pure function of time).
- Adding a pose is one enum value with its pose data; the painter does not change unless a new shape (hand, eye, prop) is introduced.
- No SVG, Lottie or Rive dependency and no image assets: shapes stay sharp at any size, follow the theme, and cost nothing to ship. A Rive file stays out of scope unless the owner orders one (requirements §25).
- Motion timings live in `AppMotion` (`characterWave`, `characterFloat` and its calm/brisk/lively variants, `characterBlink`, `characterPulse`, `characterPose`); all motion stops under the platform's reduce-motion setting.
- Each expression has its own idle (`MascotExpression.idle`, a `MascotIdle`): float height and pace, a sway, a repeated arm gesture, and squash and stretch with the float, after the onboarding designs' moods. The tuft's content and the sparkles loop on a short pulse. The float phase carries over between expressions, so a change of pace never jumps.
- An expression change takes `characterPose` with a small overshoot (`AppMotion.bounce`) and a crouch; the face, hands and effects swap at 40 % of it, while the eyes are shut. This replaces the design's instant swap.
- The art colors are character art, not UI roles, so they live in `MascotPalette` rather than `AppSemanticColors`.

## Consequences
Screens never draw the guide themselves; they pick an expression and a prop. The painter mirrors the design file's coordinates, so a designer's change to a pose maps to one data entry. A head-and-shoulders framing serves avatars. Three props beyond the approved drawing (glasses, a kid's beanie, a graduation cap) dress the "who will learn" avatars; they are proposals awaiting the designer. A silhouette mode draws the shape alone (near-black, a muted blue in dark mode). A `confident` expression was drawn in the sheet's style at the owner's request. Not yet built: the AI variant with its five expressions (v0.5), tracked in `docs/STATUS.md`.
