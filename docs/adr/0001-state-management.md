# 1. Cubit for state management

Status: Accepted · Date: 2026-10-11

## Context
Screens load sections in parallel, submit forms and react to session changes. The team needs one predictable, testable pattern.

## Decision
`flutter_bloc` Cubits. One Cubit per screen (and a small factory Cubit per interactive sheet). State is a `final class` extending `Equatable` with `copyWith`; status is an enum; the state keeps the `Failure`, not a message. Bloc is used only when event semantics are needed (debounce, streams). Cubits never hold Flutter controllers.

## Consequences
State sequences are tested with `bloc_test`. Cubits are registered as factories and created in `BlocProvider.create`.
