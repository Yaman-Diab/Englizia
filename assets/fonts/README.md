# Fonts

Bundled so `google_fonts` loads them from assets: no download on first launch,
works offline and where Google servers are unreachable
(`GoogleFonts.config.allowRuntimeFetching = false` in `main.dart` and in tests).

| Family | Use | Files | Source |
|---|---|---|---|
| Readex Pro | Whole UI + content, Arabic and Latin | `ReadexPro-Regular.ttf` (400), `ReadexPro-SemiBold.ttf` (600) | static instances from the upstream repo Google Fonts builds from (github.com/ThomasJockin/readexpro) |
| Andika | Letters and words in kids mode | `Andika-Regular.ttf` (400), `Andika-Bold.ttf` (700) | github.com/google/fonts |

- File names must match google_fonts' naming (`<Family>-<Weight>.ttf`) or loading fails;
  `theme_test.dart` checks every weight in use.
- A new weight = add its file here, list it in `pubspec.yaml`, and add a text role for it.
- Both are SIL Open Font License 1.1; the `OFL-*.txt` files are bundled and shown on the licenses screen.
- Use fonts only through `AppFonts` / `context.texts`. Never change `fontWeight` with `copyWith`:
  google_fonts registers each weight as its own family, so the file would not switch.
