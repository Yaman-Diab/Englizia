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
- Onboarding daily goal: choose 5, 10, 15 or 20 minutes (as set in the control panel), with what it amounts to in lessons and minutes a week; the guide gets more excited with each step up.
- Onboarding "save your progress": your plan from the answers, then Google, Apple (iPhone) or email, or «لاحقًا» to carry on as a guest of this phone after a clear warning.
- Forgot your password: type your email (already there if you typed it to sign in) and get a link to set a new one. Then open your mail app from the app, or send the link again after a short wait.
- Sign in with email: Google and Apple (iPhone) first, the guide covering its eyes while you type your password, one clear message for a wrong email or password, and a countdown after too many tries.
- Create your account with email: name, email and password with the guide alongside, clear errors after each field, one-tap email domains, and "sign in instead" when the email already has an account.
- "Preparing" after creating an account: the guide gets your level or grade, your first unit (or the placement test) and your daily goal ready step by step, says what it found, and retries a step that fails. Then «ابدأ أول درس» or «ابدأ الاختبار».
- The kids' welcome: the parent hands the phone over, then the guide greets the child by name and says "Hello!" to tap and hear, before «هيا نلعب». A silent phone is noticed, and the welcome starts over when the volume comes up. Runs without sound until sounds are turned on.
- Guest mode: a guest account on the server, tied to this phone, so you can learn now and create an account later.
- Create an account as a guest and keep everything: the guest account becomes your account. Signing out as a guest warns that the progress would be lost.
- Onboarding streak challenge: 7, 14, 30 or 40 days, shown on a calendar in the streak color with a flame that beats when you change your mind.
- Onboarding reminder time: morning, noon, evening or a time of your own, with a preview of the reminder. Notifications are asked for only after you choose; if you refuse, you can open the phone settings or go on without a reminder.
- Onboarding "how much English do you know?": start from the first level, or take the placement test now or later. Shows the test's duration and stages from the server, and waits for a connection before the test.
- The guide character «بلبل», drawn in code with 16 expressions (including «واثق»), light and dark versions, a silhouette, and an idle wave, float and blink.

### Changed
- "I know some English" no longer starts the placement test at once: onboarding goes on, and the test starts after your account is ready. Offline it can't be chosen, and the screen says why.
- Every button and screen waits the same way: one spinner, and a busy button keeps its size and color instead of fading.
- If the phone can't save your sign-in after creating an account, "preparing" says so and tries again, instead of signing you out the next time you open the app.
- The app talks to the dev server (`api-dev.engleazia.com`): it reads the server's response and error format, and renews the sign-in shortly before it expires instead of waiting for a request to fail.
- The guide moves with more life: each expression idles its own way, and changing expression overshoots slightly and swaps the face behind a blink.
- The level step's guide gives a confident thumbs-up when you know some English.
- The app is named Engleazia (Arabic name unchanged).
- Dark mode uses the colors of the approved designs, including the soft blue and green bands.
- Arabic plurals use their real forms (e.g. «مراحل» for 3–10, «مرحلة» from 11).
- Signing in is required to reach home; guests land on the welcome screen.
