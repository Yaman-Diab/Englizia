# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Project foundation: Clean Architecture skeleton, DI, router with route policies, session bootstrap.
- Networking for the .NET backend: `ApiClient`, ProblemDetails parsing, typed failures, auth interceptor with a shared token refresh.
- Design system from visual identity v2: semantic color tokens (light + dark), type scale, component themes.
- Readex Pro and Andika fonts via google_fonts, bundled for offline use, with their licenses on the licenses screen.
- Arabic (default) and English localization with automated parity checks.
- Temporary foundation screen to check theme, language and direction on a device.
- CI (analyze, format, test), Dependabot, PR template, environment files.
- Motion tokens (`AppMotion`) with reduced-motion support.
- Android page transition (fade + short slide, mirrored in Arabic); iOS keeps its native transition and edge-swipe back.
- Welcome screen: the first screen for anyone without an account, with a staggered entrance.
- Onboarding language step: choosing Arabic or English switches the app at once; the progress bar follows the learner's actual path.
- Onboarding "who will learn" step: the choices come from the published tracks; one with no track shows «قريبًا». Runs on mock data until the backend is ready.
- Onboarding grade step for school students: the grades and their groups come from the curriculum track's levels.
- Onboarding child profile: the child's name with a live greeting, and the age (5–9).
- Onboarding "why are you learning English?": pick any of six reasons; the guide replies to the latest one.
- Onboarding "how much English do you know?": start from the first level, or take the placement test now or later. Shows the test's duration and stages from the server, and waits for a connection before the test.
- The guide character «بلبل», drawn in code with 13 expressions (including «واثق»), light and dark versions, a silhouette, and an idle wave, float and blink.

### Changed
- The guide moves with more life: each expression idles its own way, and changing expression overshoots slightly and swaps the face behind a blink.
- The level step's guide gives a confident thumbs-up when you know some English.
- The app is named Engleazia (Arabic name unchanged).
- Dark mode uses the colors of the approved designs, including the soft blue and green bands.
- Arabic plurals use their real forms (e.g. «مراحل» for 3–10, «مرحلة» from 11).
- Signing in is required to reach home; guests land on the welcome screen.
