# 5. Theming from visual identity v2

Status: Accepted · Date: 2026-10-11 · Revised: 2026-10-12

## Context
"الهوية البصرية v2" (`docs/product/visual-identity-v2.md`) defines role colors with separate fill/text/surface uses, a dark mode, reader tokens, a type scale, Readex Pro and Andika, and a kids mode on the same engine. It keeps proposal 1.0 (`docs/product/visual-identity-v1.md`) for everything it does not change, including the neutrals. v2's token JSON (section 8) was empty in the delivered file, so text tokens and most dark values have no source value.

## Decision
- Raw values in `AppPalette` (Tailwind scale); widgets read roles only: `context.colors` (`AppSemanticColors` with a `ToneColors` triple per role), `context.texts` (`AppTextStyles`), `context.scheme`.
- Light role colors are exactly the 1.0 token list (primary, status fills, success/error surfaces, neutrals) plus the values v2 states (reader, captions, reward dark).
- The 1.0 fills for success, streak, reward and info stay although they are below 3:1 on white, because the docs keep them; every state also shows an icon and text, so color is never the only signal.
- The button background is `#2563EB` with white text in both modes ("always", v2); the selected reader word in dark mode uses `#60A5FA` (v2 reader table).
- Text tokens, the streak/reward/AI/info surfaces and the dark values the docs do not list are provisional Tailwind values that pass WCAG AA, tagged `ASSUMPTION(design)`.
- Arabic running text uses at least 1.7 line height; headings keep the doc's ratios.
- Fonts through `google_fonts` with the files bundled and runtime fetching disabled (offline, no dependency on Google servers from Syria).
- Text sizes use `flutter_screenutil` `.sp` against a 375×812 design.

## Consequences
`theme_test.dart` pins every 1.0 and v2 value and checks contrast in both modes. Replacing provisional values is a change in `AppPalette` and `AppSemanticColors` only.
