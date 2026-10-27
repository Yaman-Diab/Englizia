# 10. Guest mode as a server-side guest account

Status: Accepted · Date: 2026-10-27

## Context
Requirements v3.0 removed guest mode (student doc §4.3: "no guest mode, no «لاحقًا»"; server doc §26 drops the "guest" account type), although the designs keep it: «لاحقًا» on "save progress", a sheet that warns «تقدّمك سيبقى على هذا الهاتف فقط», and a guest card in «أنا». On 2026-10-27 the owner brought guest mode back and chose a **guest account on the server** over keeping progress on the phone only: grading, points and streaks are computed on the server (student doc §2), so a learner without a server identity could not learn properly.

## Decision
- «لاحقًا» on "save progress" opens the designs' sheet; «متابعة كضيف» creates the phone's guest account (`POST /api/v1/auth/guest`, docs/api/auth.md) with the onboarding answers and starts its session, which takes the learner into the app.
- A random UUID made on first use and kept in local preferences (`SettingsStorageService.installationId`) ties the guest to the install and makes the request safe to retry.
- Tokens carry an `AccountKind` (`guest` or `member`), kept through refresh and in secure storage. `AppSessionController` reports `signedOut`, `guest` or `member`.
- Route policies: `signedOutOnly` (welcome, onboarding), `withoutAccount` (sign-in, sign-up: open to a guest about to create an account), `requiresSession` (the app: guests and members), `public`.
- Creating a full account later must **upgrade the same server account**, so nothing is lost; that endpoint belongs to the account feature and the backend team (docs/api/auth.md, question 2).
- The onboarding answers travel on `OnboardingPath` to "save progress", which shows them in "your plan" and sends them with the account.

## Consequences
The guest has no credentials: signing out, deleting the app or losing the phone loses the account, which is what the sheet tells the learner. The requirements documents (student §4.3 and its design-conflict row, server §26) and the backend need updating to match; until then this ADR and docs/api/auth.md are the reference. «أنا»'s guest card, "create an account" from the profile and the guest's sign-out warning come with the «أنا» screen (docs/STATUS.md).
