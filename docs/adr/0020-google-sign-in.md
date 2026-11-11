# 20. Google sign-in

Status: Accepted · Date: 2026-11-12

## Context
Google is a way in from v0.1 (student doc §4.3, §5.1): one press on "save progress" and on sign-in, equal to the email. The server has `POST /api/v1/auth/google`, which takes Google's ID token and answers with the app's own session, making the account on its first time (docs/api/auth.md). The designs (`Login v2`, `Save Progress`) draw the button waiting, the rest dimmed, and a failed connection with a retry.

## Decision
- **Google's SDK, no Firebase.** `google_sign_in` (flutter.dev's own plugin) shows Google's account sheet and gives an ID token. The app has no other use for Firebase, and the server already checks the token itself. Alternatives looked at: `firebase_auth` (a second account system beside the server's), `credential_manager` and other community wrappers (smaller, one maintainer), and a web flow in a browser tab (worse on a phone, and it needs a redirect page).
- **The token is made for the server's client.** The app asks for a token whose audience is the server's "Web application" OAuth client (`GOOGLE_SERVER_CLIENT_ID`), and the server accepts only that. Android needs no client ID in the app: Google finds the Android client by the application ID and the signing key, so each signing key needs its own client. iOS has its own (`GOOGLE_IOS_CLIENT_ID`) and its reversed ID as a URL scheme. The IDs are public values and travel in the env files like `BASE_URL`; there is no secret in the app.
- **One place knows the SDK.** `GoogleIdentitySource` (account data) gives the token, null when the learner closed the sheet, and throws `ProviderException` for anything else: Google missing, a client not set up, no client ID in the build. `AccountRepository.signInWithGoogle` sends the token and returns a `SocialSession`: the session and whether the account is new.
- **A provider failing is its own failure.** `ProviderFailure` covers Google failing on the phone and the server refusing its token (`auth.google_token_invalid`, a 401 that would otherwise read as a session that ended). The server's `auth.email_taken`, `auth.external_login_conflict` and `auth.account_disabled` keep their codes, and `FailureL10n` words them; they offer no retry, as trying again changes nothing.
- **Sign-in and sign-up are one step.** On "save progress" a new account goes on to "preparing" with the answers, as an email account does; an account that existed signs in and goes home with its own plan. On sign-in every Google session goes home. The last way used is kept on the phone for the badge; an email sign-in clears it.
- **Signing out forgets Google's account**, best effort, so the next sign-in asks which one.

## Consequences
- Nothing works outside mock mode until the console's clients exist and the server checks the same Web client (STATUS D-110); a build without the client ID says «تعذّر الدخول بهذه الطريقة» instead of opening the sheet.
- Android reports a signing key Google doesn't know as the sheet being closed, so a setup mistake looks like nothing happened; the reason goes to the log (STATUS D-111).
- A guest who signs in with Google leaves the guest account behind, and a first-time Google account from the sign-in screen has no onboarding answers: both wait for the server (docs/api/README.md, requests 2 and 3; STATUS D-042, D-112).
- Signing in again before deleting an account still has no contract for Google (docs/api/auth.md, question 7).
- Apple's sign-in can follow the same shape: its own source, `ProviderFailure`, a `SocialSession`.
