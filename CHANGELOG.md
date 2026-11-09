# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Sound effects: a right and a wrong answer, a piece picked, a lesson finished, a unit and a placement test done, a concept mastered, the next island out of its fog, the daily goal, the microphone, a word saved, a freeze kept, the points counting and a card turned; the kids hear their own toy sounds and stars. One family of warm marimba and soft bells, quiet under the phone's silent switch and the learner's own music, off with «المؤثرات الصوتية», and never over the microphone or a video. The sounds are placeholders for now.
- Home, the «تعلّم» tab: your level as an archipelago, one island per unit joined by bridges, today's island with its lessons as stones on a trail and the next one in a bubble to start or continue; a header with the greeting, today's minutes in the goal ring with the guide, the streak and its sheet, your tracks, the review due, and cards for a freeze used, a streak broken, the level check, a test put off and a level done. The header folds as the map scrolls, a button brings you back to your lesson, a pull refreshes, and coming back from a lesson celebrates what it changed: the stone fills, the trail draws, a unit's island closes and the next opens, the level's horizon opens. Locked units show when they open and what they hold; Emar's book can be searched by page; kids get their own home with stars and picture stones. Works offline with what was kept, and runs on mock data for now.
- The dev page (`/dev`, a long press on home's top bar in mock mode) with home's scenarios.
- Settings: your account, daily goal and reminder, notifications on or off, language and appearance, sound effects, vibration and video quality, support, changing the password, and deleting the account.
- «أنا»: who you are with the name to edit and the email to confirm, your active track as a chain of islands with switching tracks and changing grade, the streak with its freezes, points, lessons, words and days, this week against the goal, the placement test's result and its wait, support on WhatsApp with your account number, and signing out; for kids, their stars and words with the parent's part behind a number to type.
- The unit screen: what the unit teaches, its grammar and how far you are, its lessons as a timeline with the current one to start or continue, the chain moving on after a lesson, the unit's review last, the next unit once it is done, a locked unit as a preview, Emar's book pages, a picture grid with stars for kids, and what still opens offline.
- Kids' media: a picture story told word by word with cards for its marked words, a song lit line by line over its video, a written dialogue answered by picking a picture then saying the sentence, and «كرّر بعدي», each for a star. The kids' «كلماتي» tab: the words learned by unit, a picture each that says itself, and «العب بكلماتي».
- Kids' lessons: a word or a letter with its pictures, voice and video, then listening for a letter or a picture and matching pictures with words, answered by pressing. A right answer sends a star to the bar, and the lesson ends with the guide dancing and five stars.
- «اشرح لي»: after a wrong answer, an explanation of your own mistake: your answer with the wrong words struck, the right one, why, and another example with its voice. Within a daily limit, with the lesson's own explanation when it can't be made.
- «تحدّث»: conversations with a character in real situations, by unit. Speak or type, read what was heard before sending, hear and translate each reply, and see each task done as it happens, with no correction on the way.
- A conversation's summary: the tasks done, up to three better ways to say what you said (added to the concepts to strengthen), and the whole conversation to read. Written conversations: repeat a sentence or choose a reply.
- Concepts to strengthen: the concepts a learner got wrong, each brought back at five spaced stations with a new question, until it is mastered, with nothing red and no count of mistakes.
- The «تدرّب» tab: the word bank with how firmly each word is kept, a review that turns each card and moves it between five boxes, offline too, and «كلماتي» to search, filter and remove words; and the tabs' bar.
- Shadowing: a lesson's chosen sentences said after the model, with it, or with the text hidden, the words heard and doing better each try, and the try and the model drawn side by side.
- Vocabulary lesson: stacked cards with each word said as it shows, its kind, meaning and an example marked as it is said, the translation on request, a star to save it, dragging between cards, and the lesson's words together before the exercises.
- Interactive video: the video with a reader under it instead of captions, who speaks, five ways of showing the text, going to any sentence, cards that stop the picture, words saved with their moment, a side panel when the phone is turned, and how much was really watched.
- Interactive text: a reader that follows the sound word by word, five ways of showing the text, cards for marked words and phrases with their sound and a star to save them, and display settings kept on the phone.
- Grammar lessons: a video player with captions, speed, quality and full screen, a watched share counted from what really played that opens the exercises, the rule in short with its examples, and private questions to the teacher, whose replies only the learner who asked can see.
- The end of a lesson: the guide's quiet celebration, points counting up, the first-try count and time, words saved, what to review, the unit's chain with the lesson filling in, and the day's goal and streak, with its moment when the goal is reached. Works offline with what the phone knows.
- Advanced exercises: translating, correcting a mistake with the correction flying to its word, completing a conversation, reading a text pinned over its questions with a whole-screen view, and speaking an answer, typed if you prefer, judged by the server's AI with a note and a better form.
- Exercises to produce the language: repeating a sentence with a real microphone, writing what you hear, typing into a blank with spelling rules, ordering sentences and spelling a word.
- Feedback after checking: a sheet that rises in place of the button, with the verdict drawing itself, the right answer with its sound and why, another accepted form, what the answer earned, and a way to report a problem.
- Lesson exercises: one container for multiple choice, picture choice, listening, filling blanks, ordering words and matching, where word cards fly to their place, with progress, hints, a book reference, slower audio, each learner's own steady order of options, leaving and carrying on, lessons that open again offline, and answers that wait on the phone and go out when the connection returns. Runs on mock data, and silently, for now.
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
- Set a new password from the link in the email: the link is checked first, one field with its rule in sight and an eye to check what you typed. An expired link says so without blame and offers a new one. Once saved, you're signed in and carry on, or sign in by hand with your email already there.
- Sign in with email: Google and Apple (iPhone) first, the guide covering its eyes while you type your password, one clear message for a wrong email or password, and a countdown after too many tries.
- Create your account with email: name, email and password with the guide alongside, clear errors after each field, one-tap email domains, and "sign in instead" when the email already has an account.
- "Preparing" after creating an account: the guide gets your level or grade, your first unit (or the placement test) and your daily goal ready step by step, says what it found, and retries a step that fails. Then «ابدأ أول درس» or «ابدأ الاختبار».
- The kids' welcome: the parent hands the phone over, then the guide greets the child by name and says "Hello!" to tap and hear, before «هيا نلعب». A silent phone is noticed, and the welcome starts over when the volume comes up. Runs without sound until sounds are turned on.
- Guest mode: a guest account on the server, tied to this phone, so you can learn now and create an account later.
- Create an account as a guest and keep everything: the guest account becomes your account. Signing out as a guest warns that the progress would be lost.
- Onboarding streak challenge: 7, 14, 30 or 40 days, shown on a calendar in the streak color with a flame that beats when you change your mind.
- Onboarding reminder time: morning, noon, evening or a time of your own, with a preview of the reminder. Notifications are asked for only after you choose; if you refuse, you can open the phone settings or go on without a reminder.
- Onboarding "how much English do you know?": start from the first level, or take the placement test now or later. Shows the test's duration and stages from the server, and waits for a connection before the test.
- The placement test's intro: what the test takes, and whether it's your first, one left unfinished, or a retake that's open or not yet. Offline it shows your last known state, with the button coming back by itself. Starting over and starting with no test tell the server first. The sound check doesn't play a sound yet.
- The placement test's questions: vocabulary, grammar, reading and listening, one at a time, with no feedback and no score. Answers are kept on the phone, so a stage that ends offline only waits. Stop whenever you like and carry on from the same question. Listening doesn't play a sound yet.
- The placement test's result: the guide climbs a ladder up to your estimated level, then what you can do and how your skills compare, with no numbers. You can start one level lower. Offline, your answers are safe and the result waits.
- Confirm your email: a quiet reminder that never stops you learning, a sheet to open your mail app, send the link again or correct the address, and a badge with your email. The link confirms it, or says it ran out and offers a new one.
- The guide character «بلبل», drawn in code with 16 expressions (including «واثق»), light and dark versions, a silhouette, and an idle wave, float and blink.

### Fixed
- The line of a unit's chain on the lesson's end was never drawn: it had no height.

### Changed
- "I know some English" no longer starts the placement test at once: onboarding goes on, and the test starts after your account is ready. Offline it can't be chosen, and the screen says why.
- Every button and screen waits the same way: one spinner, and a busy button keeps its size and color instead of fading.
- If the phone can't save your sign-in after creating an account, "preparing" says so and tries again, instead of signing you out the next time you open the app.
- Signing in again on the same phone no longer counts as a new device: the app keeps the id the server gave it.
- The app talks to the dev server (`api-dev.engleazia.com`): it reads the server's response and error format, and renews the sign-in shortly before it expires instead of waiting for a request to fail.
- Password recovery, confirming the email, correcting it and changing the password work with the dev server: an expired link says so instead of showing a form error, and changing the password keeps you signed in on this phone. An iPhone tells the server it is one.
- The guide moves with more life: each expression idles its own way, and changing expression overshoots slightly and swaps the face behind a blink.
- The level step's guide gives a confident thumbs-up when you know some English.
- The app is named Engleazia (Arabic name unchanged).
- Dark mode uses the colors of the approved designs, including the soft blue and green bands.
- Arabic plurals use their real forms (e.g. «مراحل» for 3–10, «مرحلة» from 11).
- Home needs a session, a guest's or a member's; anyone without one lands on the welcome screen.
