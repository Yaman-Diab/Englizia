# 4. Localization and RTL

Status: Accepted · Date: 2026-10-11

## Context
Arabic is the primary audience; English is the second UI language. Content mixes English sentences with Arabic translations.

## Decision
- `easy_localization` with flat snake_case keys in `assets/translations/{ar,en}.json`, literal keys before `.tr()`.
- No `startLocale` override: the device decides at first launch, Arabic is the fallback; onboarding step 1 sets it explicitly.
- Latin digits everywhere so scores, XP and CEFR codes read the same in both languages.
- Directional widgets only (`EdgeInsetsDirectional`, `AlignmentDirectional`).
- `Accept-Language` mirrors the UI language.

## Consequences
`test/localization/localization_test.dart` enforces parity, placeholders, used/unused keys and no hardcoded text.
