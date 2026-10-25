# Engleazia — إنجليزيا

Student app for learning English, built Arabic-first. One engine serves every track: kids (letters and topics), general English (Pre-A1 to B2, with a placement test), and the Emar school curriculum (grades 1–12). Tracks and content are created in the control panel; the app shows them, grades on the server and keeps progress safe offline.

> Status: project foundation only — no feature yet. See `CHANGELOG.md`.

## Product documents
Arabic requirement documents are the source of truth: `docs/product/`
(student app, control panel, visual identity v2).

## Tech stack
Flutter · Cubit (flutter_bloc) · GetIt · go_router · Dio · easy_localization · flutter_screenutil · flutter_secure_storage.
Backend: .NET REST API (separate repository).

## Architecture
Clean Architecture, feature-first. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and the decisions in [`docs/adr/`](docs/adr/).

## Getting started
1. Flutter version from `.fvmrc` (`fvm install` if you use FVM).
2. `flutter pub get`
3. Run against an environment:
   - `flutter run --dart-define-from-file=env/dev.json`
   - personal backend/tunnel: copy `env/example.json` to `env/local.json` (gitignored) and run with it.
4. In Android Studio / IntelliJ pick the `dev`, `mock` or `staging` run configuration (`.run/`); in VS Code use `.vscode/launch.json`.

## Tests
```
flutter analyze --fatal-infos
flutter test
```
Includes architecture rules, localization parity, WCAG contrast of the color tokens, and the auth/refresh flow.

## Contributing
Branching, commit format and versioning: [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Release
[`RELEASE.md`](RELEASE.md).

## Ownership
Private project. All rights reserved.
