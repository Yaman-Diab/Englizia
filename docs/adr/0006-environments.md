# 6. Environments through define files

Status: Accepted · Date: 2026-10-11

## Context
Switching backends by editing source leads to shipping the wrong URL.

## Decision
`--dart-define-from-file=env/<env>.json` with `APP_ENV` and `BASE_URL`. `env/{dev,staging,prod,mock}.json` are committed; `env/local.json` is gitignored. `AppConfig.validate()` fails fast at startup. Non-prod builds show a banner. No secrets in define files — they are compiled into the binary. Flavors are added only if side-by-side installs are needed.

## Consequences
IDE run configurations (`.run/`, `.vscode/launch.json`) pass the right file. `mock` lets features be built against fixtures before the backend is ready.
