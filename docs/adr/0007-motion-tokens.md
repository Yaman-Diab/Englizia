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

## Addendum: page transitions (2026-10-12)

### Decision
- Page transitions come from the theme (`AppTheme.pageTransitionsTheme`), never from individual routes.
- Android: `AppPageTransitionsBuilder`. The incoming page fades in and slides `AppMotion.distanceLarge` (30px) in from the end side (right in LTR, left in RTL) over `AppMotion.fast` (250ms) both ways, with `smoothOut` (flipped on pop so leaving also starts fast). The page underneath stays still: one animated layer, no window background showing through. No blur. With reduce motion on, the page appears in place.
- iOS and macOS: `CupertinoPageTransitionsBuilder`, which keeps the native slide and the interactive edge-swipe back. macOS is listed because, left out of the map, Flutter 3.41 gives macOS a Zoom transition with the Cupertino duration.
- Not covered here: tab switches and session entry (lesson, placement test, conversation). They get their own transitions with those features.

### Trade-off: Android predictive back
- Only Flutter's predictive-back builders (`PredictiveBackPageTransitionsBuilder`, the Android default, and `PredictiveBackFullscreenPageTransitionsBuilder`) move the page with the back gesture on Android 14+ (a peek at the previous page while the finger moves). With `AppPageTransitionsBuilder`, the gesture completes first and the page then pops with the reverse transition.
- Today the manifest does not set `android:enableOnBackInvokedCallback`. Flutter 3.41 builds with `targetSdk` 36, and Android 16 turns predictive back on by default for apps that target it: system back animations (such as back to home) still play there, but in-app pages do not peek. To confirm on an Android 16 device.
- Switching back is one line in `AppTheme`: map Android to `PredictiveBackPageTransitionsBuilder` (it falls back to `FadeForwardsPageTransitionsBuilder`, 450ms) and set the manifest flag.

### Verification
Checked against the pinned Flutter 3.41.6 (`.fvmrc`, CI): `MaterialPageRoute` reads `transitionDuration` and `reverseTransitionDuration` from the builder, so one value covers every route. `test/core/design_system/app_page_transitions_test.dart` covers duration, LTR/RTL direction on push and pop, the 30px cap, reduce motion, iOS edge-swipe back and the theme wiring; re-run it after upgrading Flutter.
