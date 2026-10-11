# 3. Manual DI with GetIt

Status: Accepted · Date: 2026-10-11

## Context
Code generation (injectable) adds build steps and hides wiring. The app has a small number of registrations per feature.

## Decision
`get_it` with explicit registrations: `setupCoreDependencies()` in `core/di`, one `register<Feature>Dependencies(GetIt sl)` per feature, all wired from `app/di.dart` → `configureDependencies()`. Interfaces are registered, not implementations. Cubits are factories; everything else is a lazy singleton. `sl<>()` appears only in DI files, `app/`, and `BlocProvider.create`.

## Consequences
`test/di/di_test.dart` calls the same `configureDependencies()` and resolves every registration, so a missing one fails in CI.
