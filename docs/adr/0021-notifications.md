# 21. Notifications

Status: Accepted · Date: 2026-11-12

## Context
Requirements §20 (v1.0) and the design "Notifications": the server sends a teacher's reply, the daily goal's reminder and a streak at risk; the phone shows them when the app is away, a banner shows them when it is open; a tap opens what they are about. The permission is asked once, after the first lesson, behind a prompt of the app's own, not on the first open. The owner chose Firebase Cloud Messaging and moved the permission out of onboarding (2026-11-12).

## Decision
- **FCM, without config files.** `firebase_core` and `firebase_messaging` (Google's own plugins). Firebase is set up in code from the env file's `FIREBASE_*` values, as `BASE_URL` is, so no `google-services.json` or `GoogleService-Info.plist` per environment is checked in or needs a Gradle plugin. An empty value leaves the app without notifications rather than failing. Mock mode has no Firebase: `MockPushChannel`, driven from the dev page.
- **One seam.** `PushChannel` (`core/notifications`) is the only code that knows Firebase: messages that arrived while open, ones tapped, the one that opened the app, and the token. `PushMessage` reads the `data`'s `type`; a kind the app doesn't know is ignored.
- **The token** is an FCM registration token, sent with `PUT /api/v1/app/me/push-token` by `PushTokenSync` once an account and the permission are there, and again when it changes or another account signs in (docs/api/notifications.md). firebase_messaging 17 deprecates it for the installation ID; the app moves when the server sends that way.
- **The banner is the app's** (`InAppNotificationsCubit`, `NotificationBannerHost` in `MaterialApp`'s builder, over every route and sheet): one at a time, a newer one in its place; four seconds, longer under a screen reader; a drag up closes it. While the learner is learning (a lesson, a test, the microphone, onboarding, the prompt; `isLearningPath`), there is none: a reply leaves a dot on «أنا», kept until «أنا» opens; a reminder is dropped.
- **A tap waits for what stands before it** (design 11): the opening, an update to make, a sign-in. Then a reply opens its lesson's questions and a reminder opens home asking for the next lesson, which home opens as its bubble does. What can't be opened ends on home.
- **The permission** is asked by «نذكّرك بدرسك؟», once, on leaving the first lesson's end (an adult's and a child's), after saving the time with notifications on. Onboarding's reminder step only picks the time. «ليس الآن» twice, or the phone saying no, puts a card on «أنا» (not a child's).

## Consequences
- The server must send through FCM with the project's service account, and iOS gets nothing until an APNs key is in the Firebase project (STATUS D-113).
- The teacher's questions have no screen of their own («أسئلتي» in the design): a reply opens its grammar lesson's questions (STATUS D-114).
- A notification of a kind added later shows as the phone shows it and opens the app; it needs a `PushKind` and a destination to do more.
