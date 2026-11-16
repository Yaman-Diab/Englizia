# 10. Guest mode as a server-side guest account

Status: Accepted · Date: 2026-10-27

## Context
Requirements v3.0 removed guest mode (student doc §4.3: "no guest mode, no «لاحقًا»"; server doc §26 drops the "guest" account type), although the designs keep it: «لاحقًا» on "save progress", a sheet that warns «تقدّمك سيبقى على هذا الهاتف فقط», and a guest card in «أنا». On 2026-10-27 the owner brought guest mode back and chose a **guest account on the server** over keeping progress on the phone only: grading, points and streaks are computed on the server (student doc §2), so a learner without a server identity could not learn properly.

## Decision
- «لاحقًا» on "save progress" opens the designs' sheet; «متابعة كضيف» creates the phone's guest account (`POST /api/v1/auth/guest`, docs/api/auth.md), then sends it the onboarding answers with its own token (`POST /api/v1/app/me/onboarding`); "preparing" (S §4.4) then starts its session and takes the learner into the app. A retry after the answers failed sends only them, so no second guest is made.
- The guest is tied to the phone by the device id the server gives (`deviceId`, sent back on later requests), as every account is.
- Tokens carry an `AccountKind` (`guest` or `member`), kept through refresh and in secure storage. `AppSessionController` reports `signedOut`, `guest` or `member`.
- Route policies: `signedOutOnly` (welcome, onboarding), `withoutAccount` (sign-in, sign-up: open to a guest about to create an account), `requiresSession` (the app: guests and members), `public`.
- Creating a full account later **upgrades the same server account**, so nothing is lost: a guest who signs up sends `POST /api/v1/auth/guest/upgrade/email` with the guest's session, never register, and goes back to the app as a member, without "preparing". The session carries on: the server answers with the account, not new tokens. A guest who signs in with Google upgrades the same way (`/upgrade/google`), unless that Google account has an account already, which is then signed in to instead.
- Signing out as a guest warns first («ستفقد تقدّمك لأنه غير محفوظ في حساب») and offers the account instead.
- The onboarding answers travel on `OnboardingPath` to "save progress", which shows them in "your plan" and sends them with the account.

## Consequences
The guest has no credentials: signing out, deleting the app or losing the phone loses the account, which is what the sheet tells the learner. The requirements documents (student §4.3 and its design-conflict row, server §26) and the backend need updating to match; until then this ADR and docs/api/auth.md are the reference. The guest card, "create an account" and the sign-out warning are built (`AccountCard`), which stays on the dev page; «أنا» has its own guest card (docs/STATUS.md D-042).
