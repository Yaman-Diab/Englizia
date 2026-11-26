# Accounts and sessions

Status: **live** on the dev server (docs/api/openapi.json): register, login, refresh, logout, Google and Apple sign-in, the guest account and its upgrades, onboarding's answers, password recovery, the password change and the email's confirmation; the app uses all but Apple's. The real answers the app was checked against are in `test/fixtures/api/auth_*.json` and `app_*.json`.
Decision: guest mode is back by the owner's decision (2026-10-27, ADR 10), as a **server-side guest account** (`accountType: "guest"`). This reverses student doc §4.3 ("no guest mode") and server doc §26's table row ("no guest accounts"); both documents need updating.

Every session's `user.accountType` (`standard`, `guest`) says whose it is; the app keeps it with the tokens.

## `POST /api/v1/auth/guest`

Creates the anonymous guest account of this phone when the learner chooses «متابعة كضيف» on "save progress". Sent without a token. `CreateGuestRequest { deviceId, platform, displayName }`: the app sends the id the server gave this phone (null the first time), its `DevicePlatform`, and no name (the server names it «متعلّم»). Answer `201` with a `TokenResponse` whose user is `accountType: "guest"` (`test/fixtures/api/auth_guest_created.json`). The onboarding answers follow at once (below). The guest can learn like any learner, but has no credentials until it is upgraded.

## `POST /api/v1/app/me/onboarding`

Onboarding's answers for a new account, sent right after it is made, whichever way: a guest, an email account from "save progress", or a Google account the sign-in made (`isNewUser: true`) from "save progress". Sent with the **new account's own token**, as its session hasn't started on the phone yet. `OnboardingRequest`:

| Field | From the app |
|---|---|
| `uiLanguage` | The app's language, `ar` or `en` |
| `timeZone` | The phone's zone by its IANA name (`Asia/Damascus`), read through `flutter_timezone`. When the phone names none the server would take (`GMT+03:00`), its offset as an `Etc/GMT` zone (`Etc/GMT-3` for UTC+3; `UTC` when the offset has minutes). STATUS D-043 |
| `learnerKind` | `adult`, `child` or `school_student`, from "who will learn" |
| `trackId` | The track the audience leads to |
| `start`, `levelId` | By the track's `entryMode`, as the server refuses any other (`422 enrollment.start_invalid`, `details[].code` `not_allowed` or `required`; the backend's answers of 2026-11-23, §2.1). `placement`: `start` is `placement` for the test or `beginner` for «ابدأ من البداية دون اختبار», and no `levelId`: the server starts at the first published level. `grade_choice`: no `start`, and the grade's `levelId`. `direct`: neither. Fields a track doesn't take are left out, not sent as `null`; so is `child` without a child. The same rules hold for `POST /api/v1/app/enrollments` |
| `child` | `{name, age}` on the child path, else null |
| `learningReasons` | The reasons chosen, as the server names them |
| `dailyGoalMinutes`, `streakGoalDays` | The goal and the streak challenge |
| `reminderTime` | `"HH:mm:ss"`, phone time, or null for none |

Answers `200 OnboardingResultDto { user, enrollment }`; the app doesn't read it yet. If the answers fail, a retry of the same way sends only them and makes no second account; a `409 onboarding.already_done` is taken as answered already, as the backend confirms.

## Upgrading a guest

The guest account becomes a member's **in place**: same account, progress, points and streak. Both are sent with the guest's own session, which carries on as the member's (the answer is the account, `UserDto`, not new tokens).

- `POST /api/v1/auth/guest/upgrade/email` `{ email, password, displayName }`, from "create an account" on «أنا»'s guest card. `409 auth.email_taken` says the email has an account (the app says so and offers sign-in).
- `POST /api/v1/auth/guest/upgrade/google` `{ idToken }`, when a guest signs in with Google. `409 auth.external_login_conflict` means that Google account has an account already: the app then signs in to it with the same token (`POST /api/v1/auth/google`), leaving the guest behind.
- `409 auth.not_guest` (a login is there already) is taken as upgraded: a retry after a lost answer.
- `POST /api/v1/auth/guest/upgrade/apple` exists too; Apple's sign-in isn't built.

## `POST /api/v1/auth/password/forgot`

Step 1 of password recovery (S §5.2): `ForgotPasswordRequest { "email": "user@example.com" }`, sent without a token. The server mails a link to set a new password (valid one hour, once) **if** the email has an account, and answers the same way either way (`202`, empty `data`), so no screen can tell which emails are registered. An address that isn't one is a `400 validation.failed` on `email`. It limits requests per email and per device; the app treats `429` as sent too. Other errors (connection, server) show a retry.

"Check your email" sends the same request again after a growing wait the app keeps (1, 2, then 5 minutes, S §5.2), so the server's own limit should allow at least that. The link must open the app directly (App Links and Universal Links, not Firebase Dynamic Links, which are shut down).

Status: **live**, used (the mock always sends).

## The link in the recovery email

`https://engleazia.com/reset-password?token=<token>&email=<email>` opens the app's "set a new password" screen (S §5.2), which shows the email while the token is checked, and hands it to "forgot your password" when the link has expired. A link without a token counts as expired; without an email the screen only leaves that line out. Host and path are **proposed** (`android/app/src/main/AndroidManifest.xml`, STATUS D-024): the server needs `/.well-known/assetlinks.json` on that host for Android and an apple-app-site-association file for iOS. A browser that opens the link without the app needs a page of its own, the backend's to decide.

## `POST /api/v1/auth/password/reset/check`

`CheckResetTokenRequest { "token": "..." }`, sent without a session token, when the screen opens and before the field shows. `200` with `ResetTokenInfo { email }` for a good link; the app shows the link's own email and doesn't read this one. A link expired, used already or unknown is one answer for all three: `400` with `auth.reset_token_invalid` (`test/fixtures/api/auth_link_invalid.json`), which the app reads as an expired link wherever it comes, not as a form error (`FailureMapper`).

Status: **live**, used (the mock: any token but `expired` is good, and `expired` answers as the server does).

## `POST /api/v1/auth/password/reset`

`ResetPasswordRequest { "token", "newPassword", "deviceId", "platform" }`, sent without a session token. The token works once. Success ends the account's other sessions and answers with a `TokenResponse`, the session that signs the learner in on this phone; a `200` with no tokens means the password changed but no session started, and the learner signs in by hand. `400 auth.reset_token_invalid` as above, `400 validation.failed` naming `newPassword` for a password the server refuses (`test/fixtures/api/auth_password_reset_validation_failed.json`).

Status: **live**, used (the mock answers like register; the token `offline` fails with no connection, and `no-session` answers with no tokens).

## Confirming the email

The first link goes out by itself when an account is made with an email (S §5.3). The app reads the state from `GET /api/v1/app/me` (live: `email`, `emailVerified`), when home opens and on coming back to the app, so confirming on another device is noticed. It shows nothing with no `email` or with `emailVerified: true`, so **accounts from Google and Apple must arrive with `emailVerified: true`**. `UserDto.authMethods` now says how an account signs in; the app doesn't read it yet.

The link is `https://engleazia.com/verify-email?token=<token>`, valid and opening the app like the recovery link (STATUS D-024). All three below are **live**, used:

- `POST /api/v1/auth/email/verify`: `VerifyEmailRequest { "token": "..." }`, sent without a session, as the phone may be signed out. `200`, or `400 auth.email_link_invalid` for a link expired, used, replaced or unknown, read as the recovery's `auth.reset_token_invalid` is (`test/fixtures/api/auth_email_verify_link_invalid.json`).
- `POST /api/v1/auth/email/resend`: with the session, no body. Sends the link again (`202`). The app waits 1, 2, then 5 minutes between tries, so the server's limit should allow that; `429` counts as sent. `409` is likely an email confirmed already, which the next read of `/app/me` shows.
- `PUT /api/v1/auth/email`: `ChangeEmailRequest { "newEmail": "..." }`, with the session. Corrects the address and sends a link there (`202`). `409` when it has an account, `400` (`validation.failed`) when refused.

Questions for the backend team: whether correcting the email will ask for the password again after some time (it would need a step the design doesn't draw, STATUS D-052), and whether the 3 days a hidden reminder stays hidden should be a setting of the panel.

## `POST /api/v1/auth/google` and `POST /api/v1/auth/apple`

Both are live; the app uses Google's (ADR 20), Apple's isn't built. Both answer with a `TokenResponse` whose `isNewUser` says the sign-in made the account.

**Google.** `GoogleSignInRequest { idToken, deviceId, platform }`, sent without the session's token. The `idToken` comes from Google's sheet on the phone and is made for the server's own OAuth client (a "Web application" client, `GOOGLE_SERVER_CLIENT_ID` in the env files): the token's `aud` is that client, so **the server must check tokens against the same client ID**, from the same Google Cloud project as the Android and iOS clients. `deviceId` and `platform` are as for sign-in.

| Answer | Meaning | The app |
|---|---|---|
| `200 TokenResponse` | Signed in; `isNewUser: true` when this made the account | From "save progress": a new account goes on to "preparing", one that existed goes home. From sign-in: home |
| `400 validation.failed` | No `idToken` (`details`: `idToken`, `not_empty`). Real answer: `test/fixtures/api/auth_google_validation_failed.json` | A general message; the app never sends an empty one |
| `401 auth.google_token_invalid` | The token failed Google's checks, or was made for another client. Real answer: `test/fixtures/api/auth_google_token_invalid.json` | «تعذّر الدخول بهذه الطريقة», with a retry |
| `403 auth.account_disabled` | The account was disabled from the dashboard | «هذا الحساب موقوف», no retry |
| `409 auth.email_taken` | The email has an account and Google did not verify the email, so the two are not joined | «لهذا البريد حساب», no retry |
| `409 auth.external_login_conflict` | The email's account is linked to another Google account | Says so, no retry |
| `429 rate_limit.exceeded` | Too many requests | The general wait message, with a retry |

The `403` and `409` answers are from the document, not yet seen on the dev server. No real Google token has reached the dev server from the app yet (STATUS D-110).

**Apple.** `AppleSignInRequest { identityToken, authorizationCode, nonce, givenName, familyName, deviceId, platform }`, with `POST /api/v1/auth/apple/callback` for the web flow Android needs. A refused token is `401 auth.apple_token_invalid`.

## `POST /api/v1/auth/logout`

Live (docs/api/openapi.json): `{refreshToken}`, sent without the access token. The app calls it on sign-out and never waits on it: signing out works offline, and a failure only means the server forgets the session later. Signing out as a guest loses the account; the app warns first («ستفقد تقدّمك لأنه غير محفوظ في حساب»).

## A trial account: `POST /api/v1/auth/trial` (not used yet)

From the backend's answers of 2026-11-26; its full note (N-4a, 2026-11-23) hasn't reached the app's side, and the screen has no design yet (STATUS D-130).

- **What for:** trying the placement test before it is opened to everyone. An admin prints codes such as `PT-UYRK`, a teacher hands them to learners they know, then compares each result with the level they expected, in the panel. It isn't a school's account.
- **In the app:** a link under «ليس لديك حساب؟ أنشئ حسابًا» on sign-in (4.01), and a new screen «رمز التجربة» (the designer's changes, batch 3, rows 8 and 9).
- **What it sees:** what any learner sees: onboarding, the placement test, then the whole track, until the code ends.
- **After 14 days:** the refresh answers `401 auth.refresh_token_invalid`, and the app is to open «رمز التجربة», not sign-in; signing in with the code answers `422 auth.trial_code_expired`. Its answers and progress stay on the server for the report, but the learner doesn't come back to them, and they don't move to another account.
- **No upgrade:** the guest's upgrade requests answer `409 auth.not_guest`. With `accountType: "trial"` the app is to hide «أنشئ حسابًا» and every offer to upgrade; whoever wants a full account makes a new one.
- **One phone:** the code is bound to the phone, so `deviceId` is kept and always sent. Signing out doesn't delete a trial account, unlike a guest: the same code on the same phone returns to it.

## Answered by the backend (2026-11-26)

1. **An unused guest is kept 90 days.** A daily job deletes a guest made 90 days ago whose phone wasn't seen in those days; a phone is seen at each sign-in and refresh, so a guest who opens the app is never deleted. A guest's session lasts 60 days, as any other. Deleting takes its progress and enrollments.
2. **No merge** (decision of 2026-11-16): a guest's progress isn't merged into an account that exists, and upgrading to an email or a Google account that has one answers `409`. The app's way stands: the guest is left, and sign-in offered. Suggested, not built (STATUS D-131): tell the learner the guest's progress won't move, and once they sign in, send `POST /api/v1/auth/logout` with the guest's session first, so it is deleted at once and not after 90 days.
3. **`Etc/GMT-3` is accepted:** any IANA name .NET knows, else `400 validation.failed` with the code `time_zone` (`UTC+3` and `GMT+03:00` are refused). The phone's own zone (`Asia/Damascus`) is better, with `Etc/GMT±N` only as a fallback: a fixed offset starts the day, and the streak, an hour wrong for half the year where clocks change. The app sends it so (above).
4. **Deleting an account that signs in with Google:** `DELETE /api/v1/app/me` isn't built yet (B-38). A fresh `idToken` in the request (`identityToken` for Apple), checked to be the same account's and recent, is what the backend leans to; the screen is built on it, and B-38 settles it.

## Questions for the backend team

None open. The backend asks the app's side for: the signing certificate's SHA-256 of each Android app, the Apple Team ID, and whether the beta is a separate app (`com.engleazia.app.beta`) or the same one, for the `engleazia.com/open/…` links (its note N-8, §6). The owner's to answer (RELEASE.md).
