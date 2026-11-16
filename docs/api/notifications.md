# Notifications

Status: **proposed**, mock only. The app receives notifications through Firebase Cloud Messaging (ADR 21): Firebase project `engleazia`, the same Google Cloud project as Google sign-in. Nothing here is in `docs/api/openapi.json` yet.

## `PUT /api/v1/app/me/push-token`

Where this account's notifications go on this phone. Sent with the session's token once an account is on the phone and the phone allows notifications, and again when the token changes or another account signs in. A failure is tried again on the next open, sign-in or allowance.

```json
{ "token": "<FCM registration token>", "platform": "android", "deviceId": "00000000-0000-4000-8000-000000000000" }
```

`platform` is the `DevicePlatform` (`android`, `ios`); `deviceId` the id the server gave this phone, or `null`. Answer: `204`.

- The token is an FCM **registration token**, which FCM's HTTP v1 API sends to (`message.token`). firebase_messaging 17 also offers the Firebase installation ID (`register`/`onRegistered`) for direct sends; the app switches only if the server sends that way.
- One token per device: a newer one for the same `deviceId` replaces the old.
- Signing out ends the device's session (`POST /api/v1/auth/logout`); the server should stop sending to that token with it. Proposed: no separate call.

## What the server sends

An FCM message with a `notification` (title and body, shown by the phone while the app is closed or in the background) and `data`:

| `data.type` | Other `data` | When (S §20) | The app's tap |
|---|---|---|---|
| `teacher_reply` | `questionId`, `lessonId` | A teacher answered the learner's question | The lesson's grammar page with its questions open; without `lessonId`, home |
| `daily_goal` | — | At the learner's reminder time | Home, then the next lesson as its bubble opens it |
| `streak` | — | Hours before the day ends, with a streak and the goal not reached | As `daily_goal` |

- The title and body are the panel's words (S §20) in the learner's language. **They never quote the question or the reply** (design "Notifications" 01): not on the lock screen, not in the app. The app has its own words per kind when a message has none.
- A `type` the app doesn't know is shown by the phone and opens the app, nothing more (a report fixed, until it has a screen).
- Quiet hours (S §20) are the server's: the app shows what arrives.
- Android: a `notification` message is shown by the phone when the app isn't open, with the app's icon. While the app is open, the app shows its own banner instead (iOS too: the app asks the phone not to show it then).

## Questions for the backend team

1. Agree the endpoint above and that logout stops the token.
2. Send by registration token through FCM HTTP v1, with the project's service account (`firebase-adminsdk-fbsvc@engleazia.iam.gserviceaccount.com`, made with the Firebase project; its key is the backend's to create and keep).
3. Confirm the `data` above, `lessonId` with every `teacher_reply` especially: without it the tap can only open home.
4. iOS needs an APNs key uploaded to the Firebase project before anything reaches an iPhone (STATUS D-113).
