# 5. Theming from visual identity v2

Status: Accepted · Date: 2026-10-11

## Context
"الهوية البصرية v2" defines role colors with separate fill/text/surface uses, a dark mode, reader tokens, a type scale, Readex Pro and Andika, and a kids mode on the same engine. The token JSON (section 8) was missing from the delivered file.

## Decision
- Raw values in `AppPalette` (Tailwind scale); widgets read roles only: `context.colors` (`AppSemanticColors` with a `ToneColors` triple per role), `context.texts` (`AppTextStyles`), `context.scheme`.
- Values stated in the doc are exact; the rest are provisional Tailwind values that pass WCAG AA, tagged `ASSUMPTION(design)`.
- Dark mode button background is `blue400` with dark text (keeps 7:1 contrast); the doc's "#2563EB always" is read as the light-mode rule. To confirm with the designer.
- Arabic running text uses at least 1.7 line height; headings keep the doc's ratios.
- Text sizes use `flutter_screenutil` `.sp` against a 375×812 design.

## Consequences
`theme_test.dart` pins the doc values and checks contrast in both modes. Replacing provisional values is a change in `AppPalette` only.
