# 7. Motion tokens adapted from transitions.dev

Status: Accepted · Date: 2026-10-12

## Context
The app will animate answer feedback (shake on a wrong answer in kids mode, success check), XP changes, sheets, tabs and page changes. Without a shared scale every screen picks its own durations and curves. transitions.dev publishes a consistent motion scale (durations, easings, distances, scales) with its web transitions. Its license lets the free transitions and skills be used and modified in commercial products; the only restriction is redistributing the collection as a competing library. Its snippets are CSS and React, which Flutter cannot run, and its skill and CLI generate CSS.

## Decision
- `core/design_system/app_motion.dart` (`AppMotion`) holds the values, read like `AppSpacing`: durations 40–500 ms, curves, distances in logical px, scales.
- CSS easings map one to one: `cubic-bezier(...)` → `Cubic(...)`; `ease-in-out` and `ease-out` → `Curves.easeInOut` / `Curves.easeOut` (the same control points).
- Left out: blur tokens (expensive on the low-end Android phones most users have) and the strong hover bounce (touch screens have no hover).
- The transitions.dev CLI and agent skill are not installed: they produce CSS and would steer agents away from Flutter.
- Reduced motion: `AppMotion.resolve(context, duration)` returns `Duration.zero` when `MediaQuery.disableAnimationsOf(context)` is set; decorative motion checks `AppMotion.reduceMotion(context)` and skips itself.
- Animations themselves are built with the feature that needs them, using these values.

## Consequences
`test/core/design_system/app_motion_test.dart` pins every value and checks the reduced-motion switch. Whether iOS "Reduce Motion" reaches `disableAnimations` must be checked on the first iOS device build.
